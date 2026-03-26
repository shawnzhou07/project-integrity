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
    @Published var selectedTimesOfDay: Set<String> = Set(["Morning", "Afternoon", "Evening", "Night"])
    @Published var selectedDaysOfWeek: Set<String> = Set(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
    @Published var selectedDurations: Set<DurationBucket> = Set(DurationBucket.allCases)
    @Published var selectedTables: Set<String> = Set(["1", "2", "3", "4+"])

    var activeFilterCount: Int {
        var count = 0
        if dateRange != .allTime { count += 1 }
        if !allStakes.isEmpty && selectedStakes != Set(allStakes) { count += 1 }
        if selectedTimesOfDay != Set(["Morning", "Afternoon", "Evening", "Night"]) { count += 1 }
        if selectedDaysOfWeek != Set(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]) { count += 1 }
        if selectedDurations != Set(DurationBucket.allCases) { count += 1 }
        if selectedTables != Set(["1", "2", "3", "4+"]) { count += 1 }
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
        if selectedDaysOfWeek != Set(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]) {
            chips.append(("Days filtered", "days"))
        }
        if selectedDurations != Set(DurationBucket.allCases) {
            chips.append(("Duration filtered", "durations"))
        }
        if selectedTables != Set(["1", "2", "3", "4+"]) {
            chips.append(("Tables filtered", "tables"))
        }
        return chips
    }

    func resetChip(key: String) {
        switch key {
        case "dateRange": dateRange = .allTime
        case "stakes": selectedStakes = Set(allStakes)
        case "times": selectedTimesOfDay = Set(["Morning", "Afternoon", "Evening", "Night"])
        case "days": selectedDaysOfWeek = Set(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
        case "durations": selectedDurations = Set(DurationBucket.allCases)
        case "tables": selectedTables = Set(["1", "2", "3", "4+"])
        default: break
        }
    }

    func clearAll() {
        dateRange = .allTime
        selectedStakes = Set(allStakes)
        selectedTimesOfDay = Set(["Morning", "Afternoon", "Evening", "Night"])
        selectedDaysOfWeek = Set(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
        selectedDurations = Set(DurationBucket.allCases)
        selectedTables = Set(["1", "2", "3", "4+"])
    }

    func clearFilterForAxis(_ axis: AnalyticsAxis) {
        switch axis {
        case .stakes:
            selectedStakes = Set(allStakes)
        case .timeOfDay:
            selectedTimesOfDay = Set(["Morning", "Afternoon", "Evening", "Night"])
        case .dayOfWeek:
            selectedDaysOfWeek = Set(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
        case .sessionDuration:
            selectedDurations = Set(DurationBucket.allCases)
        case .tablesPlayed:
            selectedTables = Set(["1", "2", "3", "4+"])
        }
    }
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

        return rows.sorted { $0.totalBBWon > $1.totalBBWon }
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
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.appGold)
                        if filterState.activeFilterCount > 0 {
                            Text("\(filterState.activeFilterCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 14, height: 14)
                                .background(Color.appGold)
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
                        }
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
                overviewCard
                metricToggle
                axisPicker
                activeFilterChips
                breakdownTable
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, smartBottomPadding(isSessionActive: hasActiveSession))
            .animation(.easeInOut(duration: 0.25), value: hasActiveSession)
        }
        .refreshable {
            loadSessions()
            refreshID = UUID()
        }
    }

    // MARK: - BB/$ Toggle

    var metricToggle: some View {
        Picker("Metric", selection: $metricMode) {
            ForEach(MetricMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .tint(.appGold)
        .animation(.none, value: metricMode)
        .padding(12)
        .background(Color(hex: "#0D0D0D"))
        .cornerRadius(12)
    }

    // MARK: - Summary Cards

    var overviewCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Performance Overview")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appGold)
                Spacer()
            }
            summaryCardsGrid
            datasetLabel
        }
        .padding(16)
        .background(Color.appSurface)
        .cornerRadius(16)
    }

    var summaryCardsGrid: some View {
        let s = summaryStats
        let noHands = s.hands == 0
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                if metricMode == .bb {
                    SummaryMetricCard(
                        label: "BB/100",
                        value: s.bb100.map { String(format: "%.1f BB", $0) },
                        isPositive: s.bb100.map { $0 > 0 },
                        isNegative: s.bb100.map { $0 < 0 }
                    )
                    SummaryMetricCard(
                        label: "BB/hour",
                        value: s.bbHour.map { String(format: "%.1f BB", $0) },
                        isPositive: s.bbHour.map { $0 > 0 },
                        isNegative: s.bbHour.map { $0 < 0 }
                    )
                } else {
                    SummaryMetricCard(
                        label: "$/100",
                        value: s.dollar100.map { String(format: "%.2f \(baseCurrency)", $0) },
                        isPositive: s.dollar100.map { $0 > 0 },
                        isNegative: s.dollar100.map { $0 < 0 }
                    )
                    SummaryMetricCard(
                        label: "$/hour",
                        value: s.dollarHour.map { String(format: "%.2f \(baseCurrency)", $0) },
                        isPositive: s.dollarHour.map { $0 > 0 },
                        isNegative: s.dollarHour.map { $0 < 0 }
                    )
                }
            }
            if noHands && !filteredSessions.isEmpty {
                Text("Enter hands played in sessions to see BB metrics.")
                    .font(.system(size: 12))
                    .foregroundColor(.appSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
            }
        }
    }

    var datasetLabel: some View {
        let s = summaryStats
        return Text("\(s.sessions) sessions · \(String(format: "%.1f", s.hours)) hours · \(s.hands) hands")
            .font(.system(size: 12))
            .foregroundColor(.appSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
    }

    // MARK: - Axis Picker

    var axisPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AnalyticsAxis.allCases, id: \.self) { axis in
                    Button {
                        selectedAxis = axis
                        filterState.clearFilterForAxis(axis)
                    } label: {
                        Text(axis.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedAxis == axis ? .black : .appSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedAxis == axis ? Color.appGold : Color(hex: "#1A1A1A"))
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    // MARK: - Active Filter Chips

    @ViewBuilder
    var activeFilterChips: some View {
        let chips = filterState.activeChips
        if !chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips, id: \.key) { chip in
                        HStack(spacing: 4) {
                            Text(chip.label)
                                .font(.caption)
                                .foregroundColor(.black)
                            Button {
                                filterState.resetChip(key: chip.key)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.appGold)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    // MARK: - Breakdown Table

    var breakdownTable: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text(selectedAxis.columnLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#8A8A8A"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if metricMode == .bb {
                    Text("BB/100")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#8A8A8A"))
                        .frame(width: 72, alignment: .trailing)
                    Text("BB/hr")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#8A8A8A"))
                        .frame(width: 72, alignment: .trailing)
                } else {
                    Text("$/100")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#8A8A8A"))
                        .frame(width: 72, alignment: .trailing)
                    Text("$/hr")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#8A8A8A"))
                        .frame(width: 72, alignment: .trailing)
                }
                Text("Hours")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#8A8A8A"))
                    .frame(width: 56, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#1A1A1A"))

            // Rows
            ForEach(breakdownRows) { row in
                AnalyticsTableRow(row: row, metricMode: metricMode)
            }
        }
        .background(Color(hex: "#0D0D0D"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appBorder.opacity(0.7), lineWidth: 1)
        )
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
        guard let start = session.startTime else { return "Mon" }
        let weekday = Calendar.current.component(.weekday, from: start)
        switch weekday {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return "Mon"
        }
    }

    func tablesLabel(for session: OnlineCash) -> String {
        let t = Int(session.tables)
        if t >= 4 { return "4+" }
        if t <= 0 { return "1" }
        return "\(t)"
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

// MARK: - Summary Metric Card

struct SummaryMetricCard: View {
    let label: String
    let value: String?
    let isPositive: Bool?
    let isNegative: Bool?

    var valueColor: Color {
        if isPositive == true { return .appProfit }
        if isNegative == true { return .appLoss }
        return .appSecondary
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.appSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value ?? "—")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(value == nil ? .appSecondary : valueColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80)
        .background(Color(hex: "#0B0B0B"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appBorder.opacity(0.6), lineWidth: 1)
        )
    }
}

// MARK: - Analytics Table Row

struct AnalyticsTableRow: View {
    let row: AnalyticsRowData
    let metricMode: MetricMode

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
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    Text(row.label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isLowSample ? Color(hex: "#555555") : .appPrimary)
                    if isLowSample {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#FF9500"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if metricMode == .bb {
                    metricCell(row.bb100, width: 72)
                    metricCell(row.bbPerHour, width: 72)
                } else {
                    metricCell(row.dollarPer100, width: 72)
                    metricCell(row.dollarPerHour, width: 72)
                }

                Text(Self.formatHours(row.totalHours))
                    .font(.system(size: 13))
                    .foregroundColor(.appSecondary)
                    .frame(width: 56, alignment: .trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()
                .background(Color(hex: "#2A2A2A"))
        }
    }

    @ViewBuilder
    func metricCell(_ value: Double?, width: CGFloat) -> some View {
        if let v = value {
            Text(Self.formatMetricValue(v))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(cellColor(for: v))
                .frame(width: width, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            Text("—")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.appSecondary)
                .frame(width: width, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    func cellColor(for value: Double) -> Color {
        if isLowSample { return Color(hex: "#555555") }
        return value.profitColor
    }
}

// MARK: - Filter Sheet

struct AnalyticsFilterSheet: View {
    @ObservedObject var filterState: OnlineAnalyticsFilterState
    let primaryAxis: AnalyticsAxis
    @Environment(\.dismiss) private var dismiss

    @State private var openSection: String? = "dateRange"

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        filterSection(title: "Date Range", key: "dateRange") {
                            dateRangeContent
                        }
                        filterSection(title: "Stakes", key: "stakes") {
                            stakesContent
                        }
                        filterSection(title: "Time of Day", key: "timeOfDay") {
                            timeOfDayContent
                        }
                        filterSection(title: "Day of Week", key: "dayOfWeek") {
                            dayOfWeekContent
                        }
                        filterSection(title: "Session Duration", key: "duration") {
                            durationContent
                        }
                        filterSection(title: "Tables Played", key: "tables") {
                            tablesContent
                        }
                    }
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

    func filterSection<Content: View>(title: String, key: String, @ViewBuilder content: () -> Content) -> some View {
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
                        .foregroundColor(isDisabled ? .appSecondary : .appPrimary)
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

            Divider().background(Color.appBorder)
        }
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
            ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
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
            ForEach(["1", "2", "3", "4+"], id: \.self) { t in
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
            Text(label)
                .font(.subheadline)
                .foregroundColor(isSelected ? .black : .appSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.appGold : Color(hex: "#1A1A1A"))
                .cornerRadius(20)
        }
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
