import Foundation
import Combine

/// Chart-specific filters. Persisted to UserDefaults under "chartFilter_*". Independent of Statistics filters.
enum ChartSessionType: String, CaseIterable {
    case all = "All"
    case live = "Live"
    case online = "Online"
}

enum ChartDateRange: String, CaseIterable {
    case allTime = "All Time"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisYear = "This Year"
    case last3Months = "Last 3 Months"
    case last6Months = "Last 6 Months"
}

final class ChartFilterState: ObservableObject {
    private let defaults = UserDefaults.standard
    private let sessionTypeKey = "chartFilter_sessionType"
    private let dateRangeKey = "chartFilter_dateRange"
    private let stakesKey = "chartFilter_stakes"
    private let locationIDKey = "chartFilter_locationID"
    private let platformIDKey = "chartFilter_platformID"

    @Published var sessionType: ChartSessionType {
        didSet { defaults.set(sessionType.rawValue, forKey: sessionTypeKey) }
    }
    @Published var dateRange: ChartDateRange {
        didSet { defaults.set(dateRange.rawValue, forKey: dateRangeKey) }
    }
    /// Comma-separated blind levels e.g. "1/2,2/5". Empty = All Stakes.
    @Published var selectedStakes: Set<String> {
        didSet {
            let str = selectedStakes.isEmpty ? "" : selectedStakes.sorted().joined(separator: ",")
            defaults.set(str, forKey: stakesKey)
        }
    }
    @Published var selectedLocationID: UUID? {
        didSet {
            defaults.set(selectedLocationID?.uuidString, forKey: locationIDKey)
        }
    }
    @Published var selectedPlatformID: UUID? {
        didSet {
            defaults.set(selectedPlatformID?.uuidString, forKey: platformIDKey)
        }
    }

    init() {
        self.sessionType = ChartSessionType(rawValue: defaults.string(forKey: sessionTypeKey) ?? ChartSessionType.all.rawValue) ?? .all
        self.dateRange = ChartDateRange(rawValue: defaults.string(forKey: dateRangeKey) ?? ChartDateRange.allTime.rawValue) ?? .allTime
        let stakesStr = defaults.string(forKey: stakesKey) ?? ""
        self.selectedStakes = stakesStr.isEmpty ? [] : Set(stakesStr.split(separator: ",").map { String($0) })
        if let idStr = defaults.string(forKey: locationIDKey), let id = UUID(uuidString: idStr) {
            self.selectedLocationID = id
        } else {
            self.selectedLocationID = nil
        }
        if let idStr = defaults.string(forKey: platformIDKey), let id = UUID(uuidString: idStr) {
            self.selectedPlatformID = id
        } else {
            self.selectedPlatformID = nil
        }
    }

    var activeFilterCount: Int {
        var c = 0
        if sessionType != .all { c += 1 }
        if dateRange != .allTime { c += 1 }
        if !selectedStakes.isEmpty { c += 1 }
        if selectedLocationID != nil { c += 1 }
        if selectedPlatformID != nil { c += 1 }
        return c
    }

    func isDateIncluded(_ date: Date) -> Bool {
        let cal = Calendar.current
        let now = Date()
        switch dateRange {
        case .allTime:
            return true
        case .thisWeek:
            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            let weekEnd = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? now
            return date >= weekStart && date < weekEnd
        case .thisMonth:
            return cal.isDate(date, equalTo: now, toGranularity: .month)
        case .thisYear:
            return cal.isDate(date, equalTo: now, toGranularity: .year)
        case .last3Months:
            guard let start = cal.date(byAdding: .month, value: -3, to: now) else { return true }
            return date >= start && date <= now
        case .last6Months:
            guard let start = cal.date(byAdding: .month, value: -6, to: now) else { return true }
            return date >= start && date <= now
        }
    }
}
