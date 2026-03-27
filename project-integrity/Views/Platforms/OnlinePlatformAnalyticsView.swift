// 📖 Refer to UI_MASTER.md, ARCHITECTURE.md, and BUSINESS_RULES.md before making UI or logic changes.
// 📝 Update relevant .md docs after making changes (except CHANGELOG.md which updates per build). See README.md Documentation Maintenance section.
import SwiftUI
import CoreData
import Combine

// MARK: - Breakdown Axis

enum AnalyticsAxis: String, CaseIterable {
    case stakes = "Stakes"
    case timeOfDay = "Time of Day"
    case dayOfWeek = "Day of Week"
    case sessionDuration = "Session Duration"
    case tablesPlayed = "Tables Played"

    var columnLabel: String {
        switch self {
        case .stakes: return "Stake"
        case .timeOfDay: return "Time"
        case .dayOfWeek: return "Day"
        case .sessionDuration: return "Duration"
        case .tablesPlayed: return "Tables"
        }
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

class OnlineAnalyticsFilterState: ObservableObject {
    @Published var dateRange: AnalyticsDateRange = .allTime
    @Published var selectedStakes: Set<String> = []
    @Published var allStakes: [String] = []
    @Published var allTables: [String] = []
    @Published var selectedTimesOfDay: Set<String> = Set(["Morning", "Afternoon", "Evening", "Night"])
    @Published var selectedDaysOfWeek: Set<String> = Set(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
    @Published var selectedDurations: Set<DurationBucket> = Set(DurationBucket.allCases)
    @Published var selectedTables: Set<String> = []

    var activeFilterCount: Int {
        var count = 0
        if dateRange != .allTime { count += 1 }
        if !allStakes.isEmpty && selectedStakes != Set(allStakes) { count += 1 }
        if selectedTimesOfDay != Set(["Morning", "Afternoon", "Evening", "Night"]) { count += 1 }
        if selectedDaysOfWeek != Set(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]) { count += 1 }
        if selectedDurations != Set(DurationBucket.allCases) { count += 1 }
        if !allTables.isEmpty && selectedTables != Set(allTables) { count += 1 }
        return count
    }

    var activeChips: [(label: String, key: String)] {
        var chips: [(String, String)] = []
        if dateRange != .allTime { chips.append((dateRange.rawValue, "dateRange")) }
        if !allStakes.isEmpty && selectedStakes != Set(allStakes) {
            chips.append(("Stakes filtered", "stakes"))
        }
        if selectedTimesOfDay != Set(["Morning", "Afternoon", "Evening", "Night"]) {
            chips.append(("Times filtered", "times"))
        }
        if selectedDaysOfWeek != Set(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]) {
            chips.append(("Days filtered", "days"))
        }
        if selectedDurations != Set(DurationBucket.allCases) {
            chips.append(("Duration filtered", "durations"))
        }
        if !allTables.isEmpty && selectedTables != Set(allTables) {
            chips.append(("Tables filtered", "tables"))
        }
        return chips
    }

    func resetChip(key: String) {
        switch key {
        case "dateRange": dateRange = .allTime
        case "stakes": selectedStakes = Set(allStakes)
        case "times": selectedTimesOfDay = Set(["Morning", "Afternoon", "Evening", "Night"])
        case "days": selectedDaysOfWeek = Set(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
        case "durations": selectedDurations = Set(DurationBucket.allCases)
        case "tables": selectedTables = Set(allTables)
        default: break
        }
    }

    func clearAll() {
        dateRange = .allTime
        selectedStakes = Set(allStakes)
        selectedTimesOfDay = Set(["Morning", "Afternoon", "Evening", "Night"])
        selectedDaysOfWeek = Set(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
        selectedDurations = Set(DurationBucket.allCases)
        selectedTables = Set(allTables)
    }

    func clearFilterForAxis(_ axis: AnalyticsAxis) {
        switch axis {
        case .stakes:
            selectedStakes = Set(allStakes)
        case .timeOfDay:
            selectedTimesOfDay = Set(["Morning", "Afternoon", "Evening", "Night"])
        case .dayOfWeek:
            selectedDaysOfWeek = Set(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
        case .sessionDuration:
            selectedDurations = Set(DurationBucket.allCases)
        case .tablesPlayed:
            selectedTables = Set(allTables)
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

// MARK: - Main View

struct OnlinePlatformAnalyticsView: View {
    let platform: Platform
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @StateObject private var filterState = OnlineAnalyticsFilterState()
    @State private var selectedAxis: AnalyticsAxis = .stakes
    @State private var metricMode: MetricMode = .bb
    @State private var showFilterSheet = false
    @State private var allSessions: [OnlineCash] = []
    @State private var refreshID = UUID()

    @Namespace private var toggleNamespace
    @State private var axisScrollOffset: CGFloat = 0
    @State private var axisContentWidth: CGFloat = 0
    @State private var axisContainerWidth: CGFloat = 0

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

    // MARK: Filtered + Grouped

    var filteredSessions: [OnlineCash] {
        allSessions.filter { session in
            // Date range
            if let start = filterState.dateRange.startDate() {
                guard let st = session.startTime, st >= start else { return false }
            }
            // Stakes
            let stakeLabel = stakesLabel(for: session)
            if !filterState.allStakes.isEmpty && !filterState.selectedStakes.contains(stakeLabel) {
                return false
            }
            // Time of day
            let tod = timeOfDayLabel(for: session)
            if !filterState.selectedTimesOfDay.contains(tod) { return false }
            // Day of week
            let dow = dayOfWeekLabel(for: session)
            if !filterState.selectedDaysOfWeek.contains(dow) { return false }
            // Duration
            let bucket = DurationBucket.bucket(for: sessionHours(session))
            if !filterState.selectedDurations.contains(bucket) { return false }
            // Tables
            let tableLabel = tablesLabel(for: session)
            if !filterState.selectedTables.contains(tableLabel) { return false }
            return true
        }
    }

    var summaryStats: (bb100: Double?, dollar100: Double?, bbHour: Double?, dollarHour: Double?, sessions: Int, hours: Double, hands: Int) {
        let sessions = filteredSessions
        let totalBBWon = sessions.reduce(0.0) { acc, s in
            guard s.bigBlind > 0 else { return acc }
            return acc + (s.netProfitLoss / s.bigBlind)
        }
        let totalHands = sessions.reduce(0) { $0 + Int($1.handsCount) }
        let totalHours = sessions.reduce(0.0) { $0 + sessionHours($1) }
        let totalProfit = sessions.reduce(0.0) { $0 + $1.netProfitLossBase }

        let bb100: Double? = totalHands > 0 ? (totalBBWon / Double(totalHands)) * 100 : nil
        let d100: Double? = totalHands > 0 ? (totalProfit / Double(totalHands)) * 100 : nil
        let bbhr: Double? = totalHours > 0 ? totalBBWon / totalHours : nil
        let dhr: Double? = totalHours > 0 ? totalProfit / totalHours : nil

        return (bb100, d100, bbhr, dhr, sessions.count, totalHours, totalHands)
    }

    var breakdownRows: [AnalyticsRowData] {
        let sessions = filteredSessions
        var groups: [String: [OnlineCash]] = [:]

        for session in sessions {
            let key = groupKey(for: session)
            groups[key, default: []].append(session)
        }

        var rows: [AnalyticsRowData] = []
        for (label, group) in groups {
            guard !group.isEmpty else { continue }
            let totalBBWon = group.reduce(0.0) { acc, s in
                guard s.bigBlind > 0 else { return acc }
                return acc + (s.netProfitLoss / s.bigBlind)
            }
            let totalHands = group.reduce(0) { $0 + Int($1.handsCount) }
            let totalHours = group.reduce(0.0) { $0 + sessionHours($1) }
            let totalProfit = group.reduce(0.0) { $0 + $1.netProfitLossBase }
            rows.append(AnalyticsRowData(
                label: label,
                sessionCount: group.count,
                totalBBWon: totalBBWon,
                totalHands: totalHands,
                totalHours: totalHours,
                totalProfitBase: totalProfit
            ))
        }

        let rowByLabel = Dictionary(uniqueKeysWithValues: rows.map { ($0.label, $0) })
        let orderedLabels: [String]
        switch selectedAxis {
        case .stakes:
            orderedLabels = rowByLabel.keys.sorted { lhs, rhs in
                stakeSortKey(lhs) < stakeSortKey(rhs)
            }
        case .timeOfDay:
            let order = ["Morning", "Afternoon", "Evening", "Night"]
            orderedLabels = order.filter { rowByLabel[$0] != nil }
        case .dayOfWeek:
            let order = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            orderedLabels = order.filter { rowByLabel[$0] != nil }
        case .sessionDuration:
            let order = DurationBucket.allCases.map(\.rawValue)
            orderedLabels = order.filter { rowByLabel[$0] != nil }
        case .tablesPlayed:
            orderedLabels = rowByLabel.keys.sorted {
                (Int($0) ?? Int.max) < (Int($1) ?? Int.max)
            }
        }
        return orderedLabels.compactMap { rowByLabel[$0] }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            if allSessions.isEmpty && filterState.activeFilterCount == 0 {
                emptyState(filtersActive: false)
            } else if filteredSessions.isEmpty {
                emptyState(filtersActive: filterState.activeFilterCount > 0)
            } else {
                mainContent
            }
        }
        .navigationTitle(platform.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appGold)
                        .frame(width: 36, height: 36)
                }
                .overlay(alignment: .topTrailing) {
                    if filterState.activeFilterCount > 0 {
                        Text("\(filterState.activeFilterCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 20, height: 20)
                            .background(
                                Circle().fill(
                                    Color(red: 201.0 / 255.0, green: 180.0 / 255.0, blue: 122.0 / 255.0, opacity: 1.0)
                                )
                            )
                            .compositingGroup()
                            .offset(CGSize(width: -3, height: 2))
                    }
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            AnalyticsFilterSheet(filterState: filterState, primaryAxis: selectedAxis)
        }
        .onAppear { loadSessions() }
        .id(refreshID)
    }

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
            loadSessions()
            refreshID = UUID()
        }
    }

    // MARK: - Filter Row (Filters pill + BB/$ toggle)

    var filterRow: some View {
        HStack {
            if filterState.activeFilterCount > 0 {
                Button {
                    filterState.clearAll()
                } label: {
                    HStack(spacing: 6) {
                        Text("\(filterState.activeFilterCount) Filters")
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

    // MARK: - Overall Performance Card

    var performanceCard: some View {
        let s = summaryStats
        let primaryValue: Double? = metricMode == .bb ? s.bb100 : s.dollar100
        let hourlyValue: Double? = metricMode == .bb ? s.bbHour : s.dollarHour

        let primaryLabel = metricMode == .bb ? "BB/100" : "$/100"
        let hourlyLabel = metricMode == .bb ? "BB/HOUR" : "CAD/HOUR"

        let primaryText: String = {
            guard let v = primaryValue else { return "—" }
            let unit = metricMode == .bb ? "BB" : baseCurrency
            if metricMode == .bb {
                return v >= 0 ? String(format: "%.1f BB", v) : String(format: "-%.1f BB", abs(v))
            } else {
                return v >= 0 ? String(format: "%.2f \(unit)", v) : String(format: "-%.2f \(unit)", abs(v))
            }
        }()

        let hourlyText: String = {
            guard let v = hourlyValue else { return "—" }
            let unit = metricMode == .bb ? "BB" : baseCurrency
            if metricMode == .bb {
                return v >= 0 ? String(format: "%.1f BB", v) : String(format: "-%.1f BB", abs(v))
            } else {
                return v >= 0 ? String(format: "%.2f \(unit)", v) : String(format: "-%.2f \(unit)", abs(v))
            }
        }()

        let primaryColor: Color = (primaryValue ?? 0) >= 0 ? Color(hex: "#4CAF50") : Color(hex: "#F44336")
        let hourlyColor: Color = (hourlyValue ?? 0) >= 0 ? Color(hex: "#4CAF50") : Color(hex: "#F44336")

        return HStack(spacing: 0) {
            Color(hex: "#C9B47A")
                .frame(width: 3)

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
        let canScrollLeft = axisScrollOffset > 8
        let canScrollRight = axisScrollOffset < (axisContentWidth - axisContainerWidth - 8)

        return VStack(spacing: 0) {
            ZStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(AnalyticsAxis.allCases, id: \.self) { axis in
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

            Rectangle()
                .fill(Color(hex: "#2A2A2A"))
                .frame(height: 1)
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

            Rectangle()
                .fill(Color(hex: "#2A2A2A"))
                .frame(height: 1)

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
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.appGold)
            Text("No Sessions")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.appPrimary)
            Text("Play some sessions on this platform to see analytics")
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
    }

    // MARK: - Helpers

    func loadSessions() {
        let request: NSFetchRequest<OnlineCash> = OnlineCash.fetchRequest()
        request.predicate = NSPredicate(format: "platform == %@", platform)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \OnlineCash.startTime, ascending: false)]
        allSessions = (try? viewContext.fetch(request)) ?? []

        // Derive all unique stakes
        let stakes = Set(allSessions.map { stakesLabel(for: $0) }).sorted()
        filterState.allStakes = stakes
        // Ensure all stakes selected by default if not yet set
        if filterState.selectedStakes.isEmpty {
            filterState.selectedStakes = Set(stakes)
        }

        let tables = Set(allSessions.map { tablesLabel(for: $0) }).sorted {
            (Int($0) ?? Int.max) < (Int($1) ?? Int.max)
        }
        filterState.allTables = tables
        let tableSet = Set(tables)
        filterState.selectedTables = filterState.selectedTables.intersection(tableSet)
        if filterState.selectedTables.isEmpty {
            filterState.selectedTables = Set(tables)
        }
    }

    func sessionHours(_ session: OnlineCash) -> Double {
        guard let start = session.startTime, let end = session.endTime else {
            return session.duration
        }
        let raw = end.timeIntervalSince(start) / 3600.0
        let breakH = session.breakTime / 60.0
        return max(0, raw - breakH)
    }

    func stakesLabel(for session: OnlineCash) -> String {
        let sb = AppFormatter.blindValue(session.smallBlind)
        let bb = AppFormatter.blindValue(session.bigBlind)
        return "\(sb)/\(bb)"
    }

    func timeOfDayLabel(for session: OnlineCash) -> String {
        guard let start = session.startTime else { return "Night" }
        let hour = Calendar.current.component(.hour, from: start)
        switch hour {
        case 6..<12: return "Morning"
        case 12..<18: return "Afternoon"
        case 18..<23: return "Evening"
        default: return "Night"
        }
    }

    func dayOfWeekLabel(for session: OnlineCash) -> String {
        guard let start = session.startTime else { return "Monday" }
        let weekday = Calendar.current.component(.weekday, from: start)
        switch weekday {
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

    func tablesLabel(for session: OnlineCash) -> String {
        let t = Int(session.tables)
        if t <= 0 { return "1" }
        return "\(t)"
    }

    func stakeSortKey(_ label: String) -> (Double, Double) {
        let parts = label.split(separator: "/")
        guard parts.count == 2 else { return (Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude) }
        let sb = parseStakeAmount(String(parts[0]))
        let bb = parseStakeAmount(String(parts[1]))
        return (bb, sb)
    }

    func parseStakeAmount(_ raw: String) -> Double {
        let filtered = raw.filter { "0123456789.".contains($0) }
        return Double(filtered) ?? Double.greatestFiniteMagnitude
    }

    func groupKey(for session: OnlineCash) -> String {
        switch selectedAxis {
        case .stakes: return stakesLabel(for: session)
        case .timeOfDay: return timeOfDayLabel(for: session)
        case .dayOfWeek: return dayOfWeekLabel(for: session)
        case .sessionDuration: return DurationBucket.bucket(for: sessionHours(session)).rawValue
        case .tablesPlayed: return tablesLabel(for: session)
        }
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
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded))h"
        }
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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

// MARK: - Filter Sheet

struct AnalyticsFilterSheet: View {
    @ObservedObject var filterState: OnlineAnalyticsFilterState
    let primaryAxis: AnalyticsAxis
    @Environment(\.dismiss) private var dismiss

    @State private var openSection: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        filterSection(title: "Date Range", key: "dateRange", activeCount: filterState.dateRange == .allTime ? 0 : 1) {
                            dateRangeContent
                        }
                        filterSection(title: "Stakes", key: "stakes", activeCount: stakesActiveCount) {
                            stakesContent
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
                        filterSection(title: "Tables Played", key: "tables", activeCount: tablesActiveCount) {
                            tablesContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                sheetFooter
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.appBackground)
    }

    func sectionMatchesPrimaryAxis(key: String) -> Bool {
        switch (key, primaryAxis) {
        case ("stakes", .stakes): return true
        case ("timeOfDay", .timeOfDay): return true
        case ("dayOfWeek", .dayOfWeek): return true
        case ("duration", .sessionDuration): return true
        case ("tables", .tablesPlayed): return true
        default: return false
        }
    }

    // MARK: - Accordion Section

    var stakesActiveCount: Int {
        guard !filterState.allStakes.isEmpty, filterState.selectedStakes != Set(filterState.allStakes) else { return 0 }
        return filterState.selectedStakes.count
    }

    var timeOfDayActiveCount: Int {
        let defaults = Set(["Morning", "Afternoon", "Evening", "Night"])
        guard filterState.selectedTimesOfDay != defaults else { return 0 }
        return filterState.selectedTimesOfDay.count
    }

    var dayOfWeekActiveCount: Int {
        let defaults = Set(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
        guard filterState.selectedDaysOfWeek != defaults else { return 0 }
        return filterState.selectedDaysOfWeek.count
    }

    var durationActiveCount: Int {
        let defaults = Set(DurationBucket.allCases)
        guard filterState.selectedDurations != defaults else { return 0 }
        return filterState.selectedDurations.count
    }

    var tablesActiveCount: Int {
        guard !filterState.allTables.isEmpty, filterState.selectedTables != Set(filterState.allTables) else { return 0 }
        return filterState.selectedTables.count
    }

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
                        .font(.subheadline)
                        .fontWeight(.semibold)
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
                            .font(.system(size: 12))
                            .italic()
                            .foregroundColor(.appSecondary)
                    }
                    Spacer()
                    if !isDisabled {
                        Image(systemName: openSection == key ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.appSecondary)
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

    // MARK: - Section Contents

    var dateRangeContent: some View {
        VStack(spacing: 8) {
            ForEach(AnalyticsDateRange.allCases, id: \.self) { range in
                Button {
                    filterState.dateRange = range
                } label: {
                    HStack {
                        Text(range.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.appPrimary)
                        Spacer()
                        if filterState.dateRange == range {
                            Image(systemName: "checkmark")
                                .foregroundColor(.appGold)
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
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
                    if filterState.selectedStakes.contains(stake) {
                        filterState.selectedStakes.remove(stake)
                    } else {
                        filterState.selectedStakes.insert(stake)
                    }
                }
            }
        }
    }

    var timeOfDayContent: some View {
        FlowLayout(spacing: 8) {
            ForEach(["Morning", "Afternoon", "Evening", "Night"], id: \.self) { time in
                filterChip(label: time, isSelected: filterState.selectedTimesOfDay.contains(time)) {
                    if filterState.selectedTimesOfDay.contains(time) {
                        filterState.selectedTimesOfDay.remove(time)
                    } else {
                        filterState.selectedTimesOfDay.insert(time)
                    }
                }
            }
        }
    }

    var dayOfWeekContent: some View {
        FlowLayout(spacing: 8) {
            ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], id: \.self) { day in
                filterChip(label: day, isSelected: filterState.selectedDaysOfWeek.contains(day)) {
                    if filterState.selectedDaysOfWeek.contains(day) {
                        filterState.selectedDaysOfWeek.remove(day)
                    } else {
                        filterState.selectedDaysOfWeek.insert(day)
                    }
                }
            }
        }
    }

    var durationContent: some View {
        FlowLayout(spacing: 8) {
            ForEach(DurationBucket.allCases, id: \.self) { bucket in
                filterChip(label: bucket.rawValue, isSelected: filterState.selectedDurations.contains(bucket)) {
                    if filterState.selectedDurations.contains(bucket) {
                        filterState.selectedDurations.remove(bucket)
                    } else {
                        filterState.selectedDurations.insert(bucket)
                    }
                }
            }
        }
    }

    var tablesContent: some View {
        FlowLayout(spacing: 8) {
            ForEach(filterState.allTables, id: \.self) { t in
                filterChip(label: t, isSelected: filterState.selectedTables.contains(t)) {
                    if filterState.selectedTables.contains(t) {
                        filterState.selectedTables.remove(t)
                    } else {
                        filterState.selectedTables.insert(t)
                    }
                }
            }
        }
    }

    func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .black : .white)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.appGold : Color(hex: "#1A1A1A"))
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    var sheetFooter: some View {
        HStack {
            Button("Clear All") {
                filterState.clearAll()
            }
            .foregroundColor(.appSecondary)
            Spacer()
            Button("Apply") {
                dismiss()
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color.appGold)
            .cornerRadius(10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appBackground)
    }
}
