import Combine
import Foundation

final class VisitStore: ObservableObject {
    @Published private(set) var visits: [Visit] = []

    private let storageKey = "kneipenzeit.native.visits.v1"
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "de_DE")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()

    init() {
        load()
    }

    var activeVisit: Visit? {
        visits.first(where: { $0.end == nil })
    }

    @discardableResult
    func startVisit(source: VisitSource, at date: Date = Date()) -> Bool {
        guard activeVisit == nil else { return false }
        visits.insert(Visit(start: date, source: source), at: 0)
        save()
        return true
    }

    @discardableResult
    func endActiveVisit(at date: Date = Date(), automaticOnly: Bool = false) -> Bool {
        guard let index = visits.firstIndex(where: { $0.end == nil }) else { return false }
        if automaticOnly && visits[index].source != .automatic { return false }
        visits[index].end = max(date, visits[index].start)
        save()
        return true
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            visits.remove(at: index)
        }
        save()
    }

    func duration(in interval: DateInterval, now: Date = Date()) -> TimeInterval {
        visits.reduce(0) { result, visit in
            let end = visit.end ?? now
            let overlapStart = max(visit.start, interval.start)
            let overlapEnd = min(end, interval.end)
            return result + max(0, overlapEnd.timeIntervalSince(overlapStart))
        }
    }

    func visitCount(in interval: DateInterval) -> Int {
        visits.filter { interval.contains($0.start) }.count
    }

    func interval(for component: Calendar.Component, containing date: Date = Date()) -> DateInterval {
        calendar.dateInterval(of: component, for: date) ?? DateInterval(start: date, duration: 0)
    }

    func summaries(kind: SummaryKind, count: Int, now: Date = Date()) -> [PeriodSummary] {
        (0..<count).compactMap { offset in
            let component: Calendar.Component
            let value: Int
            switch kind {
            case .day:
                component = .day
                value = -offset
            case .week:
                component = .weekOfYear
                value = -offset
            case .month:
                component = .month
                value = -offset
            }
            guard let shifted = calendar.date(byAdding: component, value: value, to: now),
                  let interval = calendar.dateInterval(of: component, for: shifted) else { return nil }
            return PeriodSummary(
                interval: interval,
                title: kind.title(for: interval.start, calendar: calendar),
                duration: duration(in: interval, now: now),
                visitCount: visitCount(in: interval)
            )
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        visits = (try? decoder.decode([Visit].self, from: data)) ?? []
        visits.sort { $0.start > $1.start }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(visits) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

enum SummaryKind: String, CaseIterable, Identifiable {
    case day = "Tage"
    case week = "Wochen"
    case month = "Monate"

    var id: String { rawValue }

    func title(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        switch self {
        case .day:
            formatter.dateFormat = "EEE, dd.MM.yyyy"
            return formatter.string(from: date)
        case .week:
            let week = calendar.component(.weekOfYear, from: date)
            let year = calendar.component(.yearForWeekOfYear, from: date)
            return "KW \(week) · \(year)"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date).capitalized
        }
    }
}
