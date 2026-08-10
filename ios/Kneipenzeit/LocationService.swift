import CoreLocation
import Combine
import Foundation
import UserNotifications

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isMonitoring = false
    @Published private(set) var distanceToPub: CLLocationDistance?
    @Published private(set) var statusText = "GPS-Erkennung ist noch nicht eingerichtet"
    @Published var radius: CLLocationDistance {
        didSet {
            UserDefaults.standard.set(radius, forKey: radiusKey)
            if isMonitoring { restartRegionMonitoring() }
            if let proximityText { statusText = proximityText }
        }
    }

    private let manager = CLLocationManager()
    private let store: VisitStore
    private let radiusKey = "kneipenzeit.native.radius"

    init(store: VisitStore) {
        self.store = store
        let savedRadius = UserDefaults.standard.double(forKey: radiusKey)
        radius = savedRadius > 0 ? savedRadius : 60
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 20
        manager.pausesLocationUpdatesAutomatically = true
    }

    var permissionLabel: String {
        switch authorizationStatus {
        case .authorizedAlways: return "Immer erlaubt"
        case .authorizedWhenInUse: return "Beim Verwenden erlaubt"
        case .denied: return "Abgelehnt"
        case .restricted: return "Eingeschränkt"
        case .notDetermined: return "Noch nicht gefragt"
        @unknown default: return "Unbekannt"
        }
    }

    var proximityText: String? {
        guard let distance = distanceToPub else { return nil }
        let roundedDistance = Int(distance.rounded())
        let formattedDistance = Self.distanceFormatter.string(from: NSNumber(value: roundedDistance)) ?? "\(roundedDistance)"
        return distance <= radius
            ? "In der Kneipe · \(formattedDistance) m entfernt"
            : "\(formattedDistance) m von der Kneipe entfernt"
    }

    func requestPermissionAndStart() {
        requestNotifications()
        switch manager.authorizationStatus {
        case .notDetermined:
            statusText = "Bitte Standortzugriff erlauben"
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
            startMonitoring()
        case .authorizedAlways:
            startMonitoring()
        case .denied, .restricted:
            statusText = "Standortzugriff ist in den Einstellungen deaktiviert"
        @unknown default:
            statusText = "Standortstatus konnte nicht gelesen werden"
        }
    }

    func activateIfPermitted() {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            startMonitoring()
        }
    }

    func refreshLocation() {
        guard manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse else {
            requestPermissionAndStart()
            return
        }
        manager.requestLocation()
    }

    private func startMonitoring() {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            statusText = "Bereichserkennung wird auf diesem Gerät nicht unterstützt"
            return
        }
        restartRegionMonitoring()
        manager.startMonitoringSignificantLocationChanges()
        manager.requestLocation()
        isMonitoring = true
        statusText = authorizationStatus == .authorizedAlways
            ? "Hintergrund-Erkennung ist aktiv"
            : "Erkennung aktiv · Für Hintergrundbetrieb bitte ‚Immer‘ erlauben"
    }

    private func restartRegionMonitoring() {
        manager.monitoredRegions
            .filter { $0.identifier == PubLocation.regionIdentifier }
            .forEach { manager.stopMonitoring(for: $0) }

        let maximumRadius = min(radius, manager.maximumRegionMonitoringDistance)
        let region = CLCircularRegion(
            center: PubLocation.coordinate,
            radius: maximumRadius,
            identifier: PubLocation.regionIdentifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
        manager.requestState(for: region)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
            startMonitoring()
        case .authorizedAlways:
            startMonitoring()
        case .denied, .restricted:
            isMonitoring = false
            statusText = "Standortzugriff ist deaktiviert"
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let pub = CLLocation(latitude: PubLocation.coordinate.latitude, longitude: PubLocation.coordinate.longitude)
        distanceToPub = location.distance(from: pub)
        if let proximityText { statusText = proximityText }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let locationError = error as? CLError, locationError.code == .locationUnknown { return }
        statusText = "Standort konnte nicht aktualisiert werden"
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == PubLocation.regionIdentifier else { return }
        if store.startVisit(source: .automatic) {
            statusText = "Automatisch eingecheckt"
            notify(title: "Kneipenzeit gestartet", body: "Du bist in der Gaststätte Heuchelberg angekommen.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == PubLocation.regionIdentifier else { return }
        if store.endActiveVisit(automaticOnly: true) {
            statusText = "Besuch automatisch beendet"
            notify(title: "Kneipenzeit gespeichert", body: "Dein Besuch wurde beim Verlassen automatisch beendet.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard region.identifier == PubLocation.regionIdentifier else { return }
        switch state {
        case .inside:
            if store.startVisit(source: .automatic) { statusText = "In der Kneipe · automatisch eingecheckt" }
        case .outside:
            if store.endActiveVisit(automaticOnly: true) { statusText = "Außerhalb · Besuch beendet" }
        case .unknown:
            if distanceToPub == nil { statusText = "Position zur Kneipe wird ermittelt" }
        }
    }

    private static let distanceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
