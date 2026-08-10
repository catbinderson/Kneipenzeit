import SwiftUI

@main
struct KneipenzeitApp: App {
    @StateObject private var store: VisitStore
    @StateObject private var locationService: LocationService

    init() {
        let visitStore = VisitStore()
        _store = StateObject(wrappedValue: visitStore)
        _locationService = StateObject(wrappedValue: LocationService(store: visitStore))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(locationService)
                .task {
                    locationService.activateIfPermitted()
                }
        }
    }
}
