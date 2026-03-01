import Foundation
import CoreData
import Combine

// MARK: - Filter Enums

enum DateRangeFilter: String, CaseIterable {
    case allTime = "All Time"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisYear = "This Year"
    case custom = "Custom"
}

enum SessionTypeOption: String, CaseIterable, Hashable {
    case live = "Live"
    case online = "Online"
}

enum ResultFilter: String, CaseIterable {
    case all = "All"
    case winning = "Winning"
    case losing = "Losing"
    case breakEven = "Break Even"
}

enum VerificationFilter: String, CaseIterable {
    case all = "All"
    case verified = "Verified Only"
    case unverified = "Unverified Only"
}

// MARK: - FilterState

class FilterState: ObservableObject {
    @Published var dateRange: DateRangeFilter = .allTime
    @Published var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var customEndDate: Date = Date()
    @Published var sessionTypes: Set<SessionTypeOption> = []
    @Published var selectedLocationIDs: Set<UUID> = []
    @Published var selectedPlatformIDs: Set<UUID> = []
    @Published var selectedGameTypes: Set<String> = []
    @Published var selectedBlindLevels: Set<String> = []
    @Published var resultFilter: ResultFilter = .all
    @Published var verificationFilter: VerificationFilter = .all

    var activeFilterCount: Int {
        var count = 0
        if dateRange != .allTime { count += 1 }
        if !sessionTypes.isEmpty { count += 1 }
        if !selectedLocationIDs.isEmpty { count += 1 }
        if !selectedPlatformIDs.isEmpty { count += 1 }
        if !selectedGameTypes.isEmpty { count += 1 }
        if !selectedBlindLevels.isEmpty { count += 1 }
        if resultFilter != .all { count += 1 }
        if verificationFilter != .all { count += 1 }
        return count
    }

    func reset() {
        dateRange = .allTime
        customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        customEndDate = Date()
        sessionTypes = []
        selectedLocationIDs = []
        selectedPlatformIDs = []
        selectedGameTypes = []
        selectedBlindLevels = []
        resultFilter = .all
        verificationFilter = .all
    }

    // MARK: - Date Inclusion

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
        case .custom:
            let start = cal.startOfDay(for: customStartDate)
            let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: customEndDate)) ?? customEndDate
            return date >= start && date < end
        }
    }

    // MARK: - Session Inclusion (Sessions Screen — includes result + verification)

    func shouldIncludeOnlineForSessions(_ session: OnlineCash) -> Bool {
        guard shouldIncludeOnlineBase(session) else { return false }
        // Result filter
        switch resultFilter {
        case .all: break
        case .winning: if session.netProfitLoss <= 0 { return false }
        case .losing: if session.netProfitLoss >= 0 { return false }
        case .breakEven: if session.netProfitLoss != 0 { return false }
        }
        // Verification filter
        switch verificationFilter {
        case .all: break
        case .verified: if !session.isVerified { return false }
        case .unverified: if session.isVerified { return false }
        }
        return true
    }

    func shouldIncludeLiveForSessions(_ session: LiveCash) -> Bool {
        guard shouldIncludeLiveBase(session) else { return false }
        // Result filter
        switch resultFilter {
        case .all: break
        case .winning: if session.netProfitLoss <= 0 { return false }
        case .losing: if session.netProfitLoss >= 0 { return false }
        case .breakEven: if session.netProfitLoss != 0 { return false }
        }
        // Verification filter
        switch verificationFilter {
        case .all: break
        case .verified: if !session.isVerified { return false }
        case .unverified: if session.isVerified { return false }
        }
        return true
    }

    // MARK: - Session Inclusion (Statistics Screen — excludes result + verification)

    func shouldIncludeOnlineForStats(_ session: OnlineCash) -> Bool {
        shouldIncludeOnlineBase(session)
    }

    func shouldIncludeLiveForStats(_ session: LiveCash) -> Bool {
        shouldIncludeLiveBase(session)
    }

    // MARK: - Base Inclusion Logic

    private func shouldIncludeOnlineBase(_ session: OnlineCash) -> Bool {
        if !sessionTypes.isEmpty && !sessionTypes.contains(.online) { return false }
        if !isDateIncluded(session.sessionDate) { return false }
        if !selectedPlatformIDs.isEmpty {
            guard let pid = session.platform?.id, selectedPlatformIDs.contains(pid) else { return false }
        }
        if !selectedGameTypes.isEmpty {
            guard let gt = session.gameType, selectedGameTypes.contains(gt) else { return false }
        }
        if !selectedBlindLevels.isEmpty {
            let blindStr = blindLevelString(sb: session.smallBlind, bb: session.bigBlind)
            guard selectedBlindLevels.contains(blindStr) else { return false }
        }
        return true
    }

    private func shouldIncludeLiveBase(_ session: LiveCash) -> Bool {
        if !sessionTypes.isEmpty && !sessionTypes.contains(.live) { return false }
        if !isDateIncluded(session.sessionDate) { return false }
        if !selectedLocationIDs.isEmpty {
            guard let locID = session.locationEntity?.id, selectedLocationIDs.contains(locID) else { return false }
        }
        if !selectedGameTypes.isEmpty {
            guard let gt = session.gameType, selectedGameTypes.contains(gt) else { return false }
        }
        if !selectedBlindLevels.isEmpty {
            let blindStr = blindLevelString(sb: session.smallBlind, bb: session.bigBlind)
            guard selectedBlindLevels.contains(blindStr) else { return false }
        }
        return true
    }

    private func blindLevelString(sb: Double, bb: Double) -> String {
        guard sb > 0 && bb > 0 else { return "" }
        return "\(AppFormatter.blindValue(sb))/\(AppFormatter.blindValue(bb))"
    }

    // MARK: - Section Active Indicators

    var isDateSectionActive: Bool { dateRange != .allTime }
    var isTypeSectionActive: Bool { !sessionTypes.isEmpty }
    var isLocationSectionActive: Bool { !selectedLocationIDs.isEmpty }
    var isPlatformSectionActive: Bool { !selectedPlatformIDs.isEmpty }
    var isGameTypeSectionActive: Bool { !selectedGameTypes.isEmpty }
    var isBlindLevelSectionActive: Bool { !selectedBlindLevels.isEmpty }
    var isResultSectionActive: Bool { resultFilter != .all }
    var isVerificationSectionActive: Bool { verificationFilter != .all }
}
