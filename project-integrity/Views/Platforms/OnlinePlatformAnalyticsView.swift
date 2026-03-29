// 📖 Refer to UI_MASTER.md, ARCHITECTURE.md, and BUSINESS_RULES.md before making UI or logic changes.
// 📝 Update relevant .md docs after making changes (except CHANGELOG.md which updates per build). See README.md Documentation Maintenance section.
import SwiftUI
import CoreData
import Combine

// MARK: - Analytics Source

enum AnalyticsSource: Equatable {
    case live
    case platform(Platform)

    static func == (lhs: AnalyticsSource, rhs: AnalyticsSource) -> Bool {
        switch (lhs, rhs) {
        case (.live, .live): return true
        case (.platform(let a), .platform(let b)): return a.objectID == b.objectID
        default: return false
        }
    }

    var persistenceKey: String {
        switch self {
        case .live: return "live"
        case .platform(let p): return p.id?.uuidString ?? "live"
        }
    }
}

// MARK: - Breakdown Axis

enum AnalyticsAxis: String, CaseIterable {
    case stakes = "Stakes"
    case location = "Location"
    case timeOfDay = "Time of Day"
    case dayOfWeek = "Day of Week"
    case sessionDuration = "Session Duration"
    case tablesPlayed = "Tables Played"

    var columnLabel: String {
        switch self {
        case .stakes: return "Stake"
        case .location: return "Location"
        case .timeOfDay: return "Time"
        case .dayOfWeek: return "Day"
        case .sessionDuration: return "Duration"
        case .tablesPlayed: return "Tables"
        }
    }

    static var liveAxes: [AnalyticsAxis] {
        [.stakes, .location, .timeOfDay, .dayOfWeek, .sessionDuration]
    }

    static var onlineAxes: [AnalyticsAxis] {
        [.stakes, .timeOfDay, .dayOfWeek, .sessionDuration, .tablesPlayed]
    }
}

// MARK: - Metric Mode

enum MetricMode: String, CaseIterable {
    case bb = "BB"
    case dollar = "$"
}

// MARK: - Date Range Filter

enum AnalyticsDateRange: String, CaseIterable {
    case allTime = "All Time"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisYear = "This Year"
    case last3Months = "Last 3 Months"
    case last6Months = "Last 6 Months"

    func startDate() -> Date? {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .allTime: return nil
        case .thisWeek: return cal.dateInterval(of: .weekOfYear, for: now)?.start
        case .thisMonth: return cal.dateInterval(of: .month, for: now)?.start
        case .thisYear: return cal.dateInterval(of: .year, for: now)?.start
        case .last3Months: return cal.date(byAdding: .month, value: -3, to: now)
        case .last6Months: return cal.date(byAdding: .month, value: -6, to: now)
        }
    }
}

// MARK: - Session Duration Bucket

enum DurationBucket: String, CaseIterable {
    case under30m = "<30m"
    case m30to1h = "30m-1h"
    case h1to2h = "1h-2h"
    case h2to3h = "2h-3h"
    case over3h = "3h+"

    static func bucket(for hours: Double) -> DurationBucket {
        let mins = hours * 60
        if mins < 30 { return .under30m }
        if mins < 60 { return .m30to1h }
        if mins < 120 { return .h1to2h }
        if mins < 180 { return .h2to3h }
        return .over3h
    }
}

// MARK: - Analytics Row Data

struct AnalyticsRowData: Identifiable {
    let id = UUID()
    let label: String
    let sessionCount: Int
    let totalBBWon: Double
    let totalHands: Int
    let totalHours: Double
    let totalProfitBase: Double

    var bb100: Double? {
        guard totalHands > 0 else { return nil }
        return (totalBBWon / Double(totalHands)) * 100
    }
    var dollarPer100: Double? {
        guard totalHands > 0 else { return nil }
        return (totalProfitBase / Double(totalHands)) * 100
    }
    var bbPerHour: Double? {
        guard totalHours > 0 else { return nil }
        return totalBBWon / totalHours
    }
    var dollarPerHour: Double? {
        guard totalHours > 0 else { return nil }
        return totalProfitBase / totalHours
    }
}

// MARK: - Analytics Filter State

/// Shared filter state for `AnalyticsView` (one instance for the Analytics tab lifetime).
/// Secondary filters are **not** persisted: they reset whenever the data source changes (Live / platform) and whenever the user leaves and re-enters the Analytics tab.
final class AnalyticsFilterState: ObservableObject {
    private static let fullTimesOfDay = Set(["Morning", "Afternoon", "Evening", "Night"])
    private static let fullDaysOfWeek = Set(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])

    @Published var dateRange: AnalyticsDateRange = .allTime
    @Published var selectedStakes: Set<String> = []
    @Published var allStakes: [String] = []
    @Published var allTables: [Int] = []
    @Published var allLocationKeys: [String] = []
    @Published var locationLabelsByKey: [String: String] = [:]
    @Published var selectedTimesOfDay: Set<String> = AnalyticsFilterState.fullTimesOfDay
    @Published var selectedDaysOfWeek: Set<String> = AnalyticsFilterState.fullDaysOfWeek
    @Published var selectedDurations: Set<DurationBucket> = Set(DurationBucket.allCases)
    /// Tables played (online source only when filtering); counts match `OnlineCash.tables`.
    @Published var selectedTablesPlayed: Set<Int> = []
    /// Stable keys: `Location.id` UUID string, or `legacy:<freeform name>` for sessions without a linked `Location`.
    @Published var selectedLocationKeys: Set<String> = []

    /// All dimensions set to “no filter” for the current `all*` metadata (must run after `allStakes` / `allTables` / `allLocationKeys` are updated for the active source).
    func resetSelectionsToNeutral() {
        dateRange = .allTime
        selectedTimesOfDay = AnalyticsFilterState.fullTimesOfDay
        selectedDaysOfWeek = AnalyticsFilterState.fullDaysOfWeek
        selectedDurations = Set(DurationBucket.allCases)
        selectedStakes = allStakes.isEmpty ? [] : Set(allStakes)
        selectedLocationKeys = allLocationKeys.isEmpty ? [] : Set(allLocationKeys)
        selectedTablesPlayed = allTables.isEmpty ? [] : Set(allTables)
    }

    /// Badge and "N Filters" row: only counts filters that apply to the current analytics source.
    func activeFilterCount(for source: AnalyticsSource) -> Int {
        var count = 0
        if dateRange != .allTime { count += 1 }
        if !allStakes.isEmpty && selectedStakes != Set(allStakes) { count += 1 }
        if selectedTimesOfDay != AnalyticsFilterState.fullTimesOfDay { count += 1 }
        if selectedDaysOfWeek != AnalyticsFilterState.fullDaysOfWeek { count += 1 }
        if selectedDurations != Set(DurationBucket.allCases) { count += 1 }
        switch source {
        case .live:
            if !allLocationKeys.isEmpty && selectedLocationKeys != Set(allLocationKeys) { count += 1 }
        case .platform:
            if !allTables.isEmpty && selectedTablesPlayed != Set(allTables) { count += 1 }
        }
        return count
    }

    func clearAll() {
        resetSelectionsToNeutral()
    }

    func clearFilterForAxis(_ axis: AnalyticsAxis) {
        switch axis {
        case .stakes: selectedStakes = allStakes.isEmpty ? [] : Set(allStakes)
        case .location: selectedLocationKeys = allLocationKeys.isEmpty ? [] : Set(allLocationKeys)
        case .timeOfDay: selectedTimesOfDay = AnalyticsFilterState.fullTimesOfDay
        case .dayOfWeek: selectedDaysOfWeek = AnalyticsFilterState.fullDaysOfWeek
        case .sessionDuration: selectedDurations = Set(DurationBucket.allCases)
        case .tablesPlayed: selectedTablesPlayed = allTables.isEmpty ? [] : Set(allTables)
        }
    }
}

// MARK: - Scroll Preference Keys

private struct AxisScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
private struct AxisContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
private struct AxisViewWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Analytics View

struct AnalyticsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var coordinator: ActiveSessionCoordinator
    @EnvironmentObject private var filterState: AnalyticsFilterState
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"
    @AppStorage("analyticsSelectedSource") private var savedSourceKey: String = "live"

    @State private var selectedSource: AnalyticsSource = .live
    @State private var selectedAxis: AnalyticsAxis = .stakes
    @State private var metricMode: MetricMode = .bb
    @State private var showFilterSheet = false
    @State private var allLiveSessions: [LiveCash] = []
    @State private var allOnlineSessions: [OnlineCash] = []
    @State private var refreshID = UUID()

    @Namespace private var toggleNamespace
    @State private var axisScrollOffset: CGFloat = 0
    @State private var axisContentWidth: CGFloat = 0
    @State private var axisContainerWidth: CGFloat = 0

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)])
    private var platforms: FetchedResults<Platform>

    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "startTime != nil AND endTime == nil"),
        animation: .default
    ) private var activeLiveSessions: FetchedResults<LiveCash>

    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "startTime != nil AND endTime == nil"),
        animation: .default
    ) private var activeOnlineSessions: FetchedResults<OnlineCash>

    private var hasActiveSession: Bool {
        !activeLiveSessions.isEmpty || !activeOnlineSessions.isEmpty
    }

    var sortedPlatforms: [Platform] {
        Array(platforms).sorted { p1, p2 in
            let d1 = p1.onlineSessionsArray.compactMap(\.startTime).max() ?? .distantPast
            let d2 = p2.onlineSessionsArray.compactMap(\.startTime).max() ?? .distantPast
            return d1 > d2
        }
    }

    var availableAxes: [AnalyticsAxis] {
        switch selectedSource {
        case .live: return AnalyticsAxis.liveAxes
        case .platform: return AnalyticsAxis.onlineAxes
        }
    }

    // MARK: - Filtered Sessions

    var filteredLiveSessions: [LiveCash] {
        allLiveSessions.filter { s in
            if let start = filterState.dateRange.startDate() {
                guard let st = s.startTime, st >= start else { return false }
            }
            if !filterState.allStakes.isEmpty {
                if !filterState.selectedStakes.contains(liveStakesLabel(for: s)) { return false }
            }
            if !filterState.allLocationKeys.isEmpty {
                if !filterState.selectedLocationKeys.contains(liveLocationKey(for: s)) { return false }
            }
            if !filterState.selectedTimesOfDay.contains(timeOfDayLabel(forDate: s.startTime)) { return false }
            if !filterState.selectedDaysOfWeek.contains(dayOfWeekLabel(forDate: s.startTime)) { return false }
            if !filterState.selectedDurations.contains(DurationBucket.bucket(for: liveSessionHours(s))) { return false }
            return true
        }
    }

    var filteredOnlineSessions: [OnlineCash] {
        allOnlineSessions.filter { s in
            if let start = filterState.dateRange.startDate() {
                guard let st = s.startTime, st >= start else { return false }
            }
            if !filterState.allStakes.isEmpty {
                if !filterState.selectedStakes.contains(onlineStakesLabel(for: s)) { return false }
            }
            if !filterState.selectedTimesOfDay.contains(timeOfDayLabel(forDate: s.startTime)) { return false }
            if !filterState.selectedDaysOfWeek.contains(dayOfWeekLabel(forDate: s.startTime)) { return false }
            if !filterState.selectedDurations.contains(DurationBucket.bucket(for: onlineSessionHours(s))) { return false }
            if !filterState.allTables.isEmpty {
                if !filterState.selectedTablesPlayed.contains(tablesCount(for: s)) { return false }
            }
            return true
        }
    }

    // MARK: - Summary Stats

    var summaryStats: (bb100: Double?, dollar100: Double?, bbHour: Double?, dollarHour: Double?, sessions: Int, hours: Double, hands: Int) {
        switch selectedSource {
        case .live:
            let sessions = filteredLiveSessions
            let totalBBWon = sessions.reduce(0.0) { acc, s in
                guard s.bigBlind > 0 else { return acc }
                return acc + (s.netProfitLoss / s.bigBlind)
            }
            let totalHands = sessions.reduce(0) { $0 + Int($1.handsCount) }
            let totalHours = sessions.reduce(0.0) { $0 + liveSessionHours($1) }
            let totalProfit = sessions.reduce(0.0) { $0 + $1.netProfitLossBase }
            let bb100: Double? = totalHands > 0 ? (totalBBWon / Double(totalHands)) * 100 : nil
            let d100: Double? = totalHands > 0 ? (totalProfit / Double(totalHands)) * 100 : nil
            // BB/hour only meaningful for live when hands are tracked
            let bbhr: Double? = totalHands > 0 && totalHours > 0 ? totalBBWon / totalHours : nil
            let dhr: Double? = totalHours > 0 ? totalProfit / totalHours : nil
            return (bb100, d100, bbhr, dhr, sessions.count, totalHours, totalHands)
        case .platform:
            let sessions = filteredOnlineSessions
            let totalBBWon = sessions.reduce(0.0) { acc, s in
                guard s.bigBlind > 0 else { return acc }
                return acc + (s.netProfitLoss / s.bigBlind)
            }
            let totalHands = sessions.reduce(0) { $0 + Int($1.handsCount) }
            let totalHours = sessions.reduce(0.0) { $0 + onlineSessionHours($1) }
            let totalProfit = sessions.reduce(0.0) { $0 + $1.netProfitLossBase }
            let bb100: Double? = totalHands > 0 ? (totalBBWon / Double(totalHands)) * 100 : nil
            let d100: Double? = totalHands > 0 ? (totalProfit / Double(totalHands)) * 100 : nil
            let bbhr: Double? = totalHours > 0 ? totalBBWon / totalHours : nil
            let dhr: Double? = totalHours > 0 ? totalProfit / totalHours : nil
            return (bb100, d100, bbhr, dhr, sessions.count, totalHours, totalHands)
        }
    }

    var hasNoSessions: Bool {
        switch selectedSource {
        case .live: return allLiveSessions.isEmpty && filterState.activeFilterCount(for: selectedSource) == 0
        case .platform: return allOnlineSessions.isEmpty && filterState.activeFilterCount(for: selectedSource) == 0
        }
    }

    var hasNoFilteredSessions: Bool {
        switch selectedSource {
        case .live: return filteredLiveSessions.isEmpty
        case .platform: return filteredOnlineSessions.isEmpty
        }
    }

    // MARK: - Breakdown Rows

    var breakdownRows: [AnalyticsRowData] {
        switch selectedSource {
        case .live: return computeLiveBreakdown()
        case .platform: return computeOnlineBreakdown()
        }
    }

    private func computeLiveBreakdown() -> [AnalyticsRowData] {
        var groups: [String: [LiveCash]] = [:]
        for s in filteredLiveSessions { groups[liveGroupKey(for: s), default: []].append(s) }
        var rows: [AnalyticsRowData] = []
        for (label, group) in groups {
            guard !group.isEmpty else { continue }
            let bbWon = group.reduce(0.0) { acc, s in
                guard s.bigBlind > 0 else { return acc }
                return acc + (s.netProfitLoss / s.bigBlind)
            }
            rows.append(AnalyticsRowData(
                label: label, sessionCount: group.count,
                totalBBWon: bbWon,
                totalHands: group.reduce(0) { $0 + Int($1.handsCount) },
                totalHours: group.reduce(0.0) { $0 + liveSessionHours($1) },
                totalProfitBase: group.reduce(0.0) { $0 + $1.netProfitLossBase }
            ))
        }
        return sortRows(rows)
    }

    private func computeOnlineBreakdown() -> [AnalyticsRowData] {
        var groups: [String: [OnlineCash]] = [:]
        for s in filteredOnlineSessions { groups[onlineGroupKey(for: s), default: []].append(s) }
        var rows: [AnalyticsRowData] = []
        for (label, group) in groups {
            guard !group.isEmpty else { continue }
            let bbWon = group.reduce(0.0) { acc, s in
                guard s.bigBlind > 0 else { return acc }
                return acc + (s.netProfitLoss / s.bigBlind)
            }
            rows.append(AnalyticsRowData(
                label: label, sessionCount: group.count,
                totalBBWon: bbWon,
                totalHands: group.reduce(0) { $0 + Int($1.handsCount) },
                totalHours: group.reduce(0.0) { $0 + onlineSessionHours($1) },
                totalProfitBase: group.reduce(0.0) { $0 + $1.netProfitLossBase }
            ))
        }
        return sortRows(rows)
    }

    private func sortRows(_ rows: [AnalyticsRowData]) -> [AnalyticsRowData] {
        let byLabel = Dictionary(uniqueKeysWithValues: rows.map { ($0.label, $0) })
        let ordered: [String]
        switch selectedAxis {
        case .stakes:
            ordered = byLabel.keys.sorted { stakeSortKey($0) < stakeSortKey($1) }
        case .location:
            ordered = byLabel.keys.sorted()
        case .timeOfDay:
            let order = ["Morning", "Afternoon", "Evening", "Night"]
            ordered = order.filter { byLabel[$0] != nil }
        case .dayOfWeek:
            let order = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            ordered = order.filter { byLabel[$0] != nil }
        case .sessionDuration:
            let order = DurationBucket.allCases.map(\.rawValue)
            ordered = order.filter { byLabel[$0] != nil }
        case .tablesPlayed:
            ordered = byLabel.keys.sorted { (Int($0) ?? Int.max) < (Int($1) ?? Int.max) }
        }
        return ordered.compactMap { byLabel[$0] }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                sourceSelector
                Divider().background(Color(hex: "#2A2A2A"))
                if hasNoSessions {
                    emptyState(filtersActive: false)
                } else if hasNoFilteredSessions {
                    emptyState(filtersActive: filterState.activeFilterCount(for: selectedSource) > 0)
                } else {
                    mainContent
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedSource)
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showFilterSheet = true } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appGold)
                        .frame(width: 36, height: 36)
                }
                .overlay(alignment: .topTrailing) {
                    if filterState.activeFilterCount(for: selectedSource) > 0 {
                        Text("\(filterState.activeFilterCount(for: selectedSource))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color(hex: "#C9B47A")))
                            .compositingGroup()
                            .offset(CGSize(width: -3, height: 2))
                    }
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            AnalyticsFilterSheet(
                filterState: filterState,
                primaryAxis: selectedAxis,
                isLiveSource: selectedSource == .live
            )
        }
        .onAppear { setupInitialSource() }
        .onChange(of: coordinator.selectedTab) { _, tab in
            if tab == 2 { loadSessions() }
        }
        .id(refreshID)
    }

    // MARK: - Source Selector

    var sourceSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Live pill — larger, semibold, visually primary
                Button { switchSource(.live) } label: {
                    Text("Live")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(selectedSource == .live ? Color(hex: "#000000") : Color(hex: "#FFFFFF"))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(selectedSource == .live ? Color(hex: "#C9B47A") : Color(hex: "#1A1A1A"))
                        )
                }
                .buttonStyle(.plain)

                // Platform pills — standard size, secondary prominence
                ForEach(sortedPlatforms) { platform in
                    Button { switchSource(.platform(platform)) } label: {
                        Text(platform.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(
                                selectedSource == .platform(platform)
                                    ? Color(hex: "#000000")
                                    : Color(hex: "#8A8A8A")
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(
                                    selectedSource == .platform(platform)
                                        ? Color(hex: "#C9B47A")
                                        : Color(hex: "#1A1A1A")
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Main Content

    var mainContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                filterRow
                summaryStatsRow
                performanceCard
                axisSelectorTabs
                breakdownSection
            }
            .padding(.horizontal, 16)
            .padding(.top)
            .padding(.bottom, smartBottomPadding(isSessionActive: hasActiveSession))
            .animation(.easeInOut(duration: 0.25), value: hasActiveSession)
        }
        .refreshable {
            loadSessions(resetFilters: false)
            refreshID = UUID()
        }
    }

    // MARK: - Filter Row

    var filterRow: some View {
        HStack {
            if filterState.activeFilterCount(for: selectedSource) > 0 {
                Button { filterState.clearAll() } label: {
                    HStack(spacing: 6) {
                        Text("\(filterState.activeFilterCount(for: selectedSource)) Filters")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("×")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#8A8A8A"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#1A1A1A"))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(hex: "#2A2A2A"), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            HStack(spacing: 0) {
                ForEach(MetricMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            metricMode = mode
                        }
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(metricMode == mode ? .black : Color(hex: "#8A8A8A"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(
                                Group {
                                    if metricMode == mode {
                                        Capsule()
                                            .fill(Color(hex: "#C9B47A"))
                                            .matchedGeometryEffect(id: "togglePill", in: toggleNamespace)
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color(hex: "#1A1A1A"))
            .clipShape(Capsule())
        }
    }

    // MARK: - Summary Stats Row

    var summaryStatsRow: some View {
        let s = summaryStats
        return HStack(spacing: 8) {
            AnalyticsStatCard(label: "SESSIONS", value: "\(s.sessions)")
            AnalyticsStatCard(label: "HOURS", value: String(format: "%.1f", s.hours))
            AnalyticsStatCard(label: "HANDS", value: "\(s.hands)")
        }
    }

    // MARK: - Performance Card

    var performanceCard: some View {
        let s = summaryStats
        let isLive = (selectedSource == .live)
        let noHandsForLive = isLive && s.hands == 0

        let primaryValue: Double? = metricMode == .bb ? s.bb100 : s.dollar100
        let hourlyValue: Double? = metricMode == .bb ? s.bbHour : s.dollarHour

        let primaryLabel = metricMode == .bb ? "BB/100" : "$/100"
        let hourlyLabel = metricMode == .bb ? "BB/HOUR" : "$/HOUR"

        let primaryText: String = {
            guard let v = primaryValue else { return "—" }
            if metricMode == .bb {
                return v >= 0 ? String(format: "%.1f BB", v) : String(format: "-%.1f BB", abs(v))
            } else {
                return v >= 0
                    ? String(format: "%.2f \(baseCurrency)", v)
                    : String(format: "-%.2f \(baseCurrency)", abs(v))
            }
        }()

        let hourlyText: String = {
            guard let v = hourlyValue else { return "—" }
            if metricMode == .bb {
                return v >= 0 ? String(format: "%.1f BB", v) : String(format: "-%.1f BB", abs(v))
            } else {
                return v >= 0
                    ? String(format: "%.2f \(baseCurrency)", v)
                    : String(format: "-%.2f \(baseCurrency)", abs(v))
            }
        }()

        let primaryColor: Color = (primaryValue ?? 0) >= 0 ? Color(hex: "#4CAF50") : Color(hex: "#F44336")
        let hourlyColor: Color = (hourlyValue ?? 0) >= 0 ? Color(hex: "#4CAF50") : Color(hex: "#F44336")

        return HStack(spacing: 0) {
            Color(hex: "#C9B47A").frame(width: 3)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(primaryLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#8A8A8A"))
                    Text(primaryText)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(primaryValue == nil ? .white : primaryColor)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    if noHandsForLive && metricMode == .bb {
                        Text("Log hands to see BB metrics")
                            .font(.caption)
                            .foregroundColor(.appSecondary)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(hourlyLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#8A8A8A"))
                    Text(hourlyText)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(hourlyValue == nil ? .white : hourlyColor)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(hex: "#0D0D0D"))
        .cornerRadius(16)
        .clipped()
    }

    // MARK: - Axis Selector Tabs

    var axisSelectorTabs: some View {
        let axes = availableAxes
        let canScrollLeft = axisScrollOffset > 8
        let canScrollRight = axisScrollOffset < (axisContentWidth - axisContainerWidth - 8)
        return VStack(spacing: 0) {
            ZStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(axes, id: \.self) { axis in
                            Button {
                                selectedAxis = axis
                                filterState.clearFilterForAxis(axis)
                            } label: {
                                VStack(spacing: 6) {
                                    Text(axis.rawValue)
                                        .font(.system(size: 13, weight: selectedAxis == axis ? .semibold : .medium))
                                        .foregroundColor(selectedAxis == axis ? .white : Color(hex: "#8A8A8A"))
                                    Rectangle()
                                        .fill(selectedAxis == axis ? Color(hex: "#C9B47A") : Color.clear)
                                        .frame(height: 2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 0)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: AxisContentWidthKey.self, value: geo.size.width)
                                .preference(key: AxisScrollOffsetKey.self,
                                    value: -geo.frame(in: .named("axisHScroll")).minX)
                        }
                    )
                }
                .coordinateSpace(name: "axisHScroll")
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: AxisViewWidthKey.self, value: geo.size.width)
                    }
                )
                .onPreferenceChange(AxisScrollOffsetKey.self) { axisScrollOffset = $0 }
                .onPreferenceChange(AxisContentWidthKey.self) { axisContentWidth = $0 }
                .onPreferenceChange(AxisViewWidthKey.self) { axisContainerWidth = $0 }

                HStack(spacing: 0) {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(1), Color.black.opacity(0)]),
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: 40)
                    .opacity(canScrollLeft ? 1 : 0)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.2), value: canScrollLeft)

                    Spacer()

                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0), Color.black.opacity(1)]),
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: 40)
                    .opacity(canScrollRight ? 1 : 0)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.2), value: canScrollRight)
                }
            }
            .padding(.bottom, 10)
            Rectangle().fill(Color(hex: "#2A2A2A")).frame(height: 1)
        }
    }

    // MARK: - Breakdown Section

    var breakdownSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(selectedAxis.columnLabel.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#8A8A8A"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(metricMode == .bb ? "BB/100" : "$/100")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#8A8A8A"))
                    .frame(width: 64, alignment: .trailing)
                Text(metricMode == .bb ? "BB/HR" : "$/HR")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#8A8A8A"))
                    .frame(width: 60, alignment: .trailing)
                Text("TIME")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#8A8A8A"))
                    .frame(width: 48, alignment: .trailing)
            }
            .padding(.vertical, 10)
            Rectangle().fill(Color(hex: "#2A2A2A")).frame(height: 1)
            VStack(spacing: 6) {
                ForEach(breakdownRows) { row in
                    AnalyticsTableRow(row: row, metricMode: metricMode, axis: selectedAxis)
                }
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Empty State

    func emptyState(filtersActive: Bool) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 48))
                    .foregroundColor(.appGold)
                Text("No Sessions")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.appPrimary)
                Text(emptyStateMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.appSecondary)
                    .multilineTextAlignment(.center)
                if filtersActive {
                    Text("Try clearing your filters")
                        .font(.system(size: 13))
                        .foregroundColor(.appGold)
                }
            }
            .padding()
            Spacer()
        }
    }

    var emptyStateMessage: String {
        switch selectedSource {
        case .live: return "Record some live sessions to see analytics"
        case .platform(let p): return "Play some sessions on \(p.displayName) to see analytics"
        }
    }

    // MARK: - Source Switching

    func setupInitialSource() {
        restoreSourceFromDefaults()
        loadSessions()
    }

    func restoreSourceFromDefaults() {
        guard savedSourceKey != "live" else { selectedSource = .live; return }
        if let uuid = UUID(uuidString: savedSourceKey) {
            let req: NSFetchRequest<Platform> = Platform.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            if let p = try? viewContext.fetch(req).first {
                selectedSource = .platform(p)
                return
            }
        }
        selectedSource = .live
    }

    func switchSource(_ source: AnalyticsSource) {
        guard source != selectedSource else { return }
        selectedSource = source
        if !availableAxes.contains(selectedAxis) { selectedAxis = .stakes }
        savedSourceKey = source.persistenceKey
        loadSessions(resetFilters: true)
    }

    // MARK: - Load Sessions

    /// - Parameter resetFilters: `true` when the analytics source or tab context changed — neutral filters. `false` for pull-to-refresh — keep current filter choices and intersect with new metadata.
    func loadSessions(resetFilters: Bool = true) {
        switch selectedSource {
        case .live:
            let req: NSFetchRequest<LiveCash> = LiveCash.fetchRequest()
            req.predicate = NSPredicate(format: "endTime != nil")
            req.sortDescriptors = [NSSortDescriptor(keyPath: \LiveCash.startTime, ascending: false)]
            let sessions = (try? viewContext.fetch(req)) ?? []
            allLiveSessions = sessions
            allOnlineSessions = []

            let stakes = Set(sessions.map { liveStakesLabel(for: $0) }).sorted()
            filterState.allStakes = stakes

            var keyToLabel: [String: String] = [:]
            var keys = Set<String>()
            for s in sessions {
                let k = liveLocationKey(for: s)
                keys.insert(k)
                if keyToLabel[k] == nil {
                    keyToLabel[k] = liveLocationLabel(for: s)
                }
            }
            let sortedKeys = keys.sorted {
                (keyToLabel[$0] ?? $0).localizedCaseInsensitiveCompare(keyToLabel[$1] ?? $1) == .orderedAscending
            }
            filterState.allLocationKeys = sortedKeys
            filterState.locationLabelsByKey = keyToLabel

            filterState.allTables = []
            if resetFilters {
                filterState.resetSelectionsToNeutral()
            } else {
                mergeSelectedStakes(with: Set(stakes))
                mergeSelectedLocationKeys(with: keys)
            }

        case .platform(let platform):
            let req: NSFetchRequest<OnlineCash> = OnlineCash.fetchRequest()
            req.predicate = NSPredicate(format: "platform == %@ AND endTime != nil", platform)
            req.sortDescriptors = [NSSortDescriptor(keyPath: \OnlineCash.startTime, ascending: false)]
            let sessions = (try? viewContext.fetch(req)) ?? []
            allOnlineSessions = sessions
            allLiveSessions = []

            let stakes = Set(sessions.map { onlineStakesLabel(for: $0) }).sorted()
            filterState.allStakes = stakes

            let tableInts = Set(sessions.map { tablesCount(for: $0) }).sorted()
            filterState.allTables = tableInts

            filterState.allLocationKeys = []
            filterState.locationLabelsByKey = [:]
            if resetFilters {
                filterState.resetSelectionsToNeutral()
            } else {
                mergeSelectedStakes(with: Set(stakes))
                mergeSelectedTablesPlayed(with: Set(tableInts))
            }
        }
    }

    private func mergeSelectedStakes(with available: Set<String>) {
        if available.isEmpty {
            filterState.selectedStakes = []
            return
        }
        filterState.selectedStakes = filterState.selectedStakes.intersection(available)
        if filterState.selectedStakes.isEmpty { filterState.selectedStakes = available }
    }

    private func mergeSelectedLocationKeys(with available: Set<String>) {
        if available.isEmpty {
            filterState.selectedLocationKeys = []
            return
        }
        filterState.selectedLocationKeys = filterState.selectedLocationKeys.intersection(available)
        if filterState.selectedLocationKeys.isEmpty { filterState.selectedLocationKeys = available }
    }

    private func mergeSelectedTablesPlayed(with available: Set<Int>) {
        if available.isEmpty {
            filterState.selectedTablesPlayed = []
            return
        }
        filterState.selectedTablesPlayed = filterState.selectedTablesPlayed.intersection(available)
        if filterState.selectedTablesPlayed.isEmpty { filterState.selectedTablesPlayed = available }
    }

    // MARK: - Helpers

    func liveSessionHours(_ s: LiveCash) -> Double {
        guard let start = s.startTime, let end = s.endTime else { return s.duration }
        return max(0, end.timeIntervalSince(start) / 3600.0 - s.breakTime / 60.0)
    }

    func onlineSessionHours(_ s: OnlineCash) -> Double {
        guard let start = s.startTime, let end = s.endTime else { return s.duration }
        return max(0, end.timeIntervalSince(start) / 3600.0 - s.breakTime / 60.0)
    }

    func liveStakesLabel(for s: LiveCash) -> String {
        "\(AppFormatter.blindValue(s.smallBlind))/\(AppFormatter.blindValue(s.bigBlind))"
    }

    func onlineStakesLabel(for s: OnlineCash) -> String {
        "\(AppFormatter.blindValue(s.smallBlind))/\(AppFormatter.blindValue(s.bigBlind))"
    }

    func liveLocationKey(for s: LiveCash) -> String {
        if let id = s.locationEntity?.id {
            return id.uuidString
        }
        return "legacy:\(s.location ?? "Unknown")"
    }

    func liveLocationLabel(for s: LiveCash) -> String {
        s.locationEntity?.name ?? s.location ?? "Unknown"
    }

    func tablesCount(for s: OnlineCash) -> Int {
        let t = Int(s.tables)
        return t <= 0 ? 1 : t
    }

    func tablesLabel(for s: OnlineCash) -> String {
        "\(tablesCount(for: s))"
    }

    func timeOfDayLabel(forDate date: Date?) -> String {
        guard let date = date else { return "Night" }
        switch Calendar.current.component(.hour, from: date) {
        case 6..<12: return "Morning"
        case 12..<18: return "Afternoon"
        case 18..<23: return "Evening"
        default: return "Night"
        }
    }

    func dayOfWeekLabel(forDate date: Date?) -> String {
        guard let date = date else { return "Monday" }
        switch Calendar.current.component(.weekday, from: date) {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 3: return "Tuesday"
        case 4: return "Wednesday"
        case 5: return "Thursday"
        case 6: return "Friday"
        case 7: return "Saturday"
        default: return "Monday"
        }
    }

    func liveGroupKey(for s: LiveCash) -> String {
        switch selectedAxis {
        case .stakes: return liveStakesLabel(for: s)
        case .location: return liveLocationLabel(for: s)
        case .timeOfDay: return timeOfDayLabel(forDate: s.startTime)
        case .dayOfWeek: return dayOfWeekLabel(forDate: s.startTime)
        case .sessionDuration: return DurationBucket.bucket(for: liveSessionHours(s)).rawValue
        case .tablesPlayed: return "1"
        }
    }

    func onlineGroupKey(for s: OnlineCash) -> String {
        switch selectedAxis {
        case .stakes: return onlineStakesLabel(for: s)
        case .location: return "Online"
        case .timeOfDay: return timeOfDayLabel(forDate: s.startTime)
        case .dayOfWeek: return dayOfWeekLabel(forDate: s.startTime)
        case .sessionDuration: return DurationBucket.bucket(for: onlineSessionHours(s)).rawValue
        case .tablesPlayed: return tablesLabel(for: s)
        }
    }

    func stakeSortKey(_ label: String) -> (Double, Double) {
        let parts = label.split(separator: "/")
        guard parts.count == 2 else { return (Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude) }
        return (parseStakeAmount(String(parts[1])), parseStakeAmount(String(parts[0])))
    }

    func parseStakeAmount(_ raw: String) -> Double {
        Double(raw.filter { "0123456789.".contains($0) }) ?? Double.greatestFiniteMagnitude
    }
}

// MARK: - Analytics Stat Card

struct AnalyticsStatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "#8A8A8A"))
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(hex: "#1A1A1A"))
        .cornerRadius(12)
    }
}

// MARK: - Analytics Table Row

struct AnalyticsTableRow: View {
    let row: AnalyticsRowData
    let metricMode: MetricMode
    let axis: AnalyticsAxis

    var isLowSample: Bool { row.totalHours < 2.0 }

    static func formatMetricValue(_ value: Double, decimals: Int = 1) -> String {
        let fmt = String(format: "%.\(decimals)f", abs(value))
        if value > 0 { return "+\(fmt)" }
        if value < 0 { return "-\(fmt)" }
        return fmt
    }

    static func formatHours(_ hours: Double) -> String {
        let rounded = (hours * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 { return "\(Int(rounded))h" }
        return String(format: "%.1fh", rounded)
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                if axis == .timeOfDay {
                    HStack(spacing: 4) {
                        Text(row.label)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        Text(timeRangeSubtitle(for: row.label))
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#8A8A8A"))
                    }
                } else {
                    Text(row.label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                }
                if isLowSample {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#FF9500"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if metricMode == .bb {
                metricCell(row.bb100, width: 64)
                metricCell(row.bbPerHour, width: 60)
            } else {
                metricCell(row.dollarPer100, width: 64)
                metricCell(row.dollarPerHour, width: 60)
            }

            Text(Self.formatHours(row.totalHours))
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#8A8A8A"))
                .frame(width: 48, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "#0D0D0D"))
        .cornerRadius(10)
    }

    @ViewBuilder
    func metricCell(_ value: Double?, width: CGFloat) -> some View {
        if let v = value {
            Text(Self.formatMetricValue(v))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(v >= 0 ? Color(hex: "#4CAF50") : Color(hex: "#F44336"))
                .frame(width: width, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            Text("—")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#8A8A8A"))
                .frame(width: width, alignment: .trailing)
        }
    }

    func timeRangeSubtitle(for label: String) -> String {
        switch label {
        case "Morning": return "(6am–12pm)"
        case "Afternoon": return "(12pm–6pm)"
        case "Evening": return "(6pm–11pm)"
        case "Night": return "(11pm–6am)"
        default: return ""
        }
    }
}

// MARK: - Analytics Filter Sheet

struct AnalyticsFilterSheet: View {
    @ObservedObject var filterState: AnalyticsFilterState
    let primaryAxis: AnalyticsAxis
    let isLiveSource: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var openSection: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        filterSection(title: "Date Range", key: "dateRange",
                            activeCount: filterState.dateRange == .allTime ? 0 : 1) {
                            dateRangeContent
                        }
                        filterSection(title: "Stakes", key: "stakes", activeCount: stakesActiveCount) {
                            stakesContent
                        }
                        if isLiveSource {
                            filterSection(title: "Location", key: "location", activeCount: locationActiveCount) {
                                locationContent
                            }
                        }
                        filterSection(title: "Time of Day", key: "timeOfDay", activeCount: timeOfDayActiveCount) {
                            timeOfDayContent
                        }
                        filterSection(title: "Day of Week", key: "dayOfWeek", activeCount: dayOfWeekActiveCount) {
                            dayOfWeekContent
                        }
                        filterSection(title: "Session Duration", key: "duration", activeCount: durationActiveCount) {
                            durationContent
                        }
                        if !isLiveSource {
                            filterSection(title: "Tables Played", key: "tables", activeCount: tablesActiveCount) {
                                tablesContent
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { sheetFooter }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.appBackground)
    }

    func sectionMatchesPrimaryAxis(key: String) -> Bool {
        switch (key, primaryAxis) {
        case ("stakes", .stakes): return true
        case ("location", .location): return true
        case ("timeOfDay", .timeOfDay): return true
        case ("dayOfWeek", .dayOfWeek): return true
        case ("duration", .sessionDuration): return true
        case ("tables", .tablesPlayed): return true
        default: return false
        }
    }

    // MARK: Active Counts

    var stakesActiveCount: Int {
        guard !filterState.allStakes.isEmpty, filterState.selectedStakes != Set(filterState.allStakes) else { return 0 }
        return filterState.selectedStakes.count
    }
    var locationActiveCount: Int {
        guard !filterState.allLocationKeys.isEmpty, filterState.selectedLocationKeys != Set(filterState.allLocationKeys) else { return 0 }
        return filterState.selectedLocationKeys.count
    }
    var timeOfDayActiveCount: Int {
        let d = Set(["Morning", "Afternoon", "Evening", "Night"])
        return filterState.selectedTimesOfDay == d ? 0 : filterState.selectedTimesOfDay.count
    }
    var dayOfWeekActiveCount: Int {
        let d = Set(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
        return filterState.selectedDaysOfWeek == d ? 0 : filterState.selectedDaysOfWeek.count
    }
    var durationActiveCount: Int {
        filterState.selectedDurations == Set(DurationBucket.allCases) ? 0 : filterState.selectedDurations.count
    }
    var tablesActiveCount: Int {
        guard !filterState.allTables.isEmpty, filterState.selectedTablesPlayed != Set(filterState.allTables) else { return 0 }
        return filterState.selectedTablesPlayed.count
    }

    // MARK: Accordion Section

    func filterSection<Content: View>(title: String, key: String, activeCount: Int, @ViewBuilder content: () -> Content) -> some View {
        let isDisabled = sectionMatchesPrimaryAxis(key: key)
        return VStack(spacing: 0) {
            Button {
                if !isDisabled {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        openSection = openSection == key ? nil : key
                    }
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(isDisabled ? .appSecondary : .white)
                    if activeCount > 0 && !isDisabled {
                        Text("\(activeCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color.appGold)
                            .clipShape(Circle())
                    }
                    if isDisabled {
                        Text("Already used as primary breakdown")
                            .font(.system(size: 12)).italic()
                            .foregroundColor(.appSecondary)
                    }
                    Spacer()
                    if !isDisabled {
                        Image(systemName: openSection == key ? "chevron.up" : "chevron.down")
                            .font(.caption).foregroundColor(.appSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .disabled(isDisabled)

            if openSection == key && !isDisabled {
                content()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.appSurface)
        .cornerRadius(10)
        .padding(.bottom, 8)
    }

    // MARK: Section Contents

    var dateRangeContent: some View {
        VStack(spacing: 8) {
            ForEach(AnalyticsDateRange.allCases, id: \.self) { range in
                Button { filterState.dateRange = range } label: {
                    HStack {
                        Text(range.rawValue).font(.subheadline).foregroundColor(.appPrimary)
                        Spacer()
                        if filterState.dateRange == range {
                            Image(systemName: "checkmark").foregroundColor(.appGold).font(.subheadline)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(filterState.dateRange == range ? Color.appGold.opacity(0.1) : Color.appSurface)
                    .cornerRadius(8)
                }
            }
        }
    }

    var stakesContent: some View {
        FlowLayout(spacing: 8) {
            ForEach(filterState.allStakes, id: \.self) { stake in
                filterChip(label: stake, isSelected: filterState.selectedStakes.contains(stake)) {
                    if filterState.selectedStakes.contains(stake) { filterState.selectedStakes.remove(stake) }
                    else { filterState.selectedStakes.insert(stake) }
                }
            }
        }
    }

    var locationContent: some View {
        FlowLayout(spacing: 8) {
            ForEach(filterState.allLocationKeys, id: \.self) { key in
                filterChip(label: filterState.locationLabelsByKey[key] ?? key, isSelected: filterState.selectedLocationKeys.contains(key)) {
                    if filterState.selectedLocationKeys.contains(key) { filterState.selectedLocationKeys.remove(key) }
                    else { filterState.selectedLocationKeys.insert(key) }
                }
            }
        }
    }

    var timeOfDayContent: some View {
        FlowLayout(spacing: 8) {
            ForEach(["Morning", "Afternoon", "Evening", "Night"], id: \.self) { time in
                filterChip(label: time, isSelected: filterState.selectedTimesOfDay.contains(time)) {
                    if filterState.selectedTimesOfDay.contains(time) { filterState.selectedTimesOfDay.remove(time) }
                    else { filterState.selectedTimesOfDay.insert(time) }
                }
            }
        }
    }

    var dayOfWeekContent: some View {
        FlowLayout(spacing: 8) {
            ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], id: \.self) { day in
                filterChip(label: day, isSelected: filterState.selectedDaysOfWeek.contains(day)) {
                    if filterState.selectedDaysOfWeek.contains(day) { filterState.selectedDaysOfWeek.remove(day) }
                    else { filterState.selectedDaysOfWeek.insert(day) }
                }
            }
        }
    }

    var durationContent: some View {
        FlowLayout(spacing: 8) {
            ForEach(DurationBucket.allCases, id: \.self) { bucket in
                filterChip(label: bucket.rawValue, isSelected: filterState.selectedDurations.contains(bucket)) {
                    if filterState.selectedDurations.contains(bucket) { filterState.selectedDurations.remove(bucket) }
                    else { filterState.selectedDurations.insert(bucket) }
                }
            }
        }
    }

    var tablesContent: some View {
        FlowLayout(spacing: 8) {
            ForEach(filterState.allTables, id: \.self) { t in
                filterChip(label: "\(t)", isSelected: filterState.selectedTablesPlayed.contains(t)) {
                    if filterState.selectedTablesPlayed.contains(t) { filterState.selectedTablesPlayed.remove(t) }
                    else { filterState.selectedTablesPlayed.insert(t) }
                }
            }
        }
    }

    func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label).font(.subheadline).foregroundColor(isSelected ? .black : .white)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.black)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(isSelected ? Color.appGold : Color(hex: "#1A1A1A"))
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    var sheetFooter: some View {
        HStack {
            Button("Clear All") { filterState.clearAll() }
                .foregroundColor(.appSecondary)
            Spacer()
            Button("Apply") { dismiss() }
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(.black)
                .padding(.horizontal, 24).padding(.vertical, 10)
                .background(Color.appGold)
                .cornerRadius(10)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.appBackground)
    }
}
