import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: VisitStore
    @EnvironmentObject private var locationService: LocationService

    var body: some View {
        VStack(spacing: 0) {
            AppHeader()
            TabView {
                OverviewView()
                    .tabItem { Label("Übersicht", systemImage: "house.fill") }
                HistoryView()
                    .tabItem { Label("Besuche", systemImage: "clock.arrow.circlepath") }
                StatisticsView()
                    .tabItem { Label("Statistik", systemImage: "chart.bar.fill") }
                GPSSettingsView()
                    .tabItem { Label("Kneipe & GPS", systemImage: "location.fill") }
            }
            .tint(.pubAmber)
        }
        .background(Color.pubBackground)
    }
}

private struct AppHeader: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.1"
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [.pubGold, .pubAmber], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("K")
                        .font(.system(size: 26, weight: .black, design: .serif))
                        .foregroundStyle(Color.pubDark)
                }
                .frame(width: 43, height: 43)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Kneipenzeit")
                        .font(.headline.weight(.bold))
                    Text("Designed & Developed by Andreas Binder")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.pubGold)
                    Text("Version \(version)")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(AppFormatters.clock.string(from: context.date))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(AppFormatters.headerDate.string(from: context.date))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.68))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(Color.pubDark)
        }
    }
}

private struct OverviewView: View {
    @EnvironmentObject private var store: VisitStore
    @EnvironmentObject private var locationService: LocationService

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero
                LazyVGrid(columns: columns, spacing: 12) {
                    summaryCard("Heute", component: .day, icon: "sun.max.fill", color: .orange)
                    summaryCard("Woche bis heute", component: .weekOfYear, icon: "calendar", color: .green)
                    summaryCard("Monat bis heute", component: .month, icon: "calendar.badge.clock", color: .blue)
                    summaryCard("Jahr bis heute", component: .year, icon: "chart.line.uptrend.xyaxis", color: .purple)
                }
                recentVisits
            }
            .padding(16)
        }
        .background(Color.pubBackground)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.activeVisit == nil ? "DEINE STAMMKNEIPE" : "JETZT EINGECHECKT")
                        .eyebrowStyle()
                    Text(PubLocation.name)
                        .font(.title2.bold())
                    Text(PubLocation.address)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
                Spacer()
                Image(systemName: store.activeVisit == nil ? "mappin.and.ellipse" : "mug.fill")
                    .font(.title2)
                    .foregroundStyle(Color.pubGold)
            }

            if let active = store.activeVisit {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(DurationText.format(active.duration(at: context.date)))
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            } else {
                Text(locationService.proximityText ?? locationService.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
            }

            Button {
                if store.activeVisit == nil {
                    store.startVisit(source: .manual)
                } else {
                    store.endActiveVisit()
                }
            } label: {
                Label(store.activeVisit == nil ? "Manuell einchecken" : "Besuch beenden", systemImage: store.activeVisit == nil ? "play.fill" : "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PubPrimaryButtonStyle())
        }
        .padding(20)
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: store.activeVisit == nil ? [Color.pubDark, Color.pubBrown] : [Color.pubGreen, Color.pubDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 23)
        )
        .shadow(color: .black.opacity(0.12), radius: 15, y: 8)
    }

    private func summaryCard(_ title: String, component: Calendar.Component, icon: String, color: Color) -> some View {
        let interval = store.interval(for: component)
        return VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 10))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(DurationText.format(store.duration(in: interval)))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text("\(store.visitCount(in: interval)) Besuche")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .pubCard()
    }

    private var recentVisits: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Letzte Besuche")
                .font(.title3.bold())
            if store.visits.isEmpty {
                ContentUnavailableView("Noch keine Besuche", systemImage: "clock", description: Text("Der erste Besuch erscheint automatisch hier."))
                    .frame(minHeight: 150)
                    .pubCard()
            } else {
                ForEach(store.visits.prefix(3)) { visit in
                    VisitRow(visit: visit)
                }
            }
        }
    }
}

private struct HistoryView: View {
    @EnvironmentObject private var store: VisitStore

    var body: some View {
        NavigationStack {
            Group {
                if store.visits.isEmpty {
                    ContentUnavailableView("Noch keine Besuche", systemImage: "clock.badge.questionmark", description: Text("Aktiviere GPS oder checke dich manuell ein."))
                } else {
                    List {
                        ForEach(store.visits) { visit in
                            VisitRow(visit: visit)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .padding(.vertical, 3)
                        }
                        .onDelete(perform: store.delete)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.pubBackground)
            .navigationTitle("Besuche")
        }
    }
}

private struct VisitRow: View {
    let visit: Visit

    var body: some View {
        HStack(spacing: 13) {
            VStack(spacing: 0) {
                Text(visit.start.formatted(.dateTime.day()))
                    .font(.title3.bold())
                Text(visit.start.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption2.bold())
                    .textCase(.uppercase)
                    .foregroundStyle(Color.pubAmber)
            }
            .frame(width: 48, height: 50)
            .background(Color.pubAmber.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 4) {
                Text(AppFormatters.visitDate.string(from: visit.start).capitalized)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text("\(AppFormatters.time.string(from: visit.start)) – \(visit.end.map { AppFormatters.time.string(from: $0) } ?? "läuft") · \(visit.source.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(DurationText.format(visit.duration()))
                .font(.caption.bold())
                .multilineTextAlignment(.trailing)
        }
        .padding(12)
        .pubCard()
    }
}

private struct StatisticsView: View {
    @EnvironmentObject private var store: VisitStore
    @State private var selectedKind: SummaryKind = .week

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Picker("Zeitraum", selection: $selectedKind) {
                    ForEach(SummaryKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                List(store.summaries(kind: selectedKind, count: selectedKind == .day ? 14 : 12)) { summary in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary.title)
                                .font(.subheadline.bold())
                            Text("\(summary.visitCount) Besuche")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(DurationText.format(summary.duration))
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.pubAmber)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .padding(.top, 10)
            .background(Color.pubBackground)
            .navigationTitle("Statistik")
        }
    }
}

private struct GPSSettingsView: View {
    @EnvironmentObject private var locationService: LocationService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 15) {
                    settingsCard(title: "Stammkneipe", icon: "mappin.and.ellipse") {
                        LabeledContent("Name", value: PubLocation.name)
                        LabeledContent("Adresse", value: PubLocation.address)
                        LabeledContent("Breitengrad", value: String(format: "%.7f", PubLocation.coordinate.latitude))
                        LabeledContent("Längengrad", value: String(format: "%.7f", PubLocation.coordinate.longitude))
                    }

                    settingsCard(title: "GPS-Erkennung", icon: "location.circle.fill") {
                        LabeledContent("Berechtigung", value: locationService.permissionLabel)
                        LabeledContent("Status", value: locationService.isMonitoring ? "Aktiv" : "Nicht aktiv")
                        if let distance = locationService.distanceToPub {
                            LabeledContent("Entfernung", value: "\(Int(distance)) m")
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text("Erkennungsradius")
                                Spacer()
                                Text("\(Int(locationService.radius)) m").bold()
                            }
                            Slider(value: $locationService.radius, in: 50...200, step: 10)
                                .tint(.pubAmber)
                        }
                        Button("GPS und Hintergrund-Erkennung aktivieren") {
                            locationService.requestPermissionAndStart()
                        }
                        .buttonStyle(PubPrimaryButtonStyle())
                        Button("Aktuelle Entfernung prüfen") {
                            locationService.refreshLocation()
                        }
                        .buttonStyle(.bordered)
                        Text(locationService.statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Label("Standort- und Besuchsdaten bleiben ausschließlich auf diesem iPhone.", systemImage: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                }
                .padding(16)
            }
            .background(Color.pubBackground)
            .navigationTitle("Kneipe & GPS")
        }
    }

    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.title3.bold())
                .foregroundStyle(Color.pubAmber)
            Divider()
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .pubCard()
    }
}

private struct PubPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(Color.pubDark)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [.pubGold, .pubAmber], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

private extension View {
    func pubCard() -> some View {
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.white.opacity(0.45), lineWidth: 0.6))
    }

    func eyebrowStyle() -> some View {
        font(.system(size: 10, weight: .black))
            .tracking(1.5)
            .foregroundStyle(Color.pubGold)
    }
}

private extension Color {
    static let pubDark = Color(red: 0.09, green: 0.075, blue: 0.055)
    static let pubBrown = Color(red: 0.29, green: 0.18, blue: 0.08)
    static let pubGreen = Color(red: 0.08, green: 0.27, blue: 0.19)
    static let pubAmber = Color(red: 0.91, green: 0.55, blue: 0.12)
    static let pubGold = Color(red: 1.0, green: 0.75, blue: 0.28)
    static let pubBackground = Color(uiColor: .systemGroupedBackground)
}
