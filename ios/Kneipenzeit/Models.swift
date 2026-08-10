import Foundation
import CoreLocation

enum VisitSource: String, Codable {
    case automatic
    case manual

    var label: String {
        switch self {
        case .automatic: return "GPS"
        case .manual: return "Manuell"
        }
    }
}

struct Visit: Identifiable, Codable, Equatable {
    let id: UUID
    let start: Date
    var end: Date?
    let source: VisitSource

    init(id: UUID = UUID(), start: Date = Date(), end: Date? = nil, source: VisitSource) {
        self.id = id
        self.start = start
        self.end = end
        self.source = source
    }

    func duration(at now: Date = Date()) -> TimeInterval {
        max(0, (end ?? now).timeIntervalSince(start))
    }
}

struct PubLocation {
    static let name = "Gaststätte Heuchelberg"
    static let address = "Kelterstraße 6, 74211 Leingarten"
    static let coordinate = CLLocationCoordinate2D(latitude: 49.1427734, longitude: 9.1220517)
    static let regionIdentifier = "de.andreasbinder.kneipenzeit.heuchelberg"
}

struct PeriodSummary: Identifiable {
    let interval: DateInterval
    let title: String
    let duration: TimeInterval
    let visitCount: Int

    var id: Date { interval.start }
}

enum DurationText {
    static func format(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval) / 60)
        return "\(minutes / 60) Std. \(String(format: "%02d", minutes % 60)) Min."
    }
}

enum AppFormatters {
    static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm:ss 'Uhr'"
        return formatter
    }()

    static let headerDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEE, dd.MM.yyyy"
        return formatter
    }()

    static let visitDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .full
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
