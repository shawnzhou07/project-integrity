import SwiftUI
import CoreData

struct StatsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \OnlineCash.startTime, ascending: false)])
    private var onlineSessions: FetchedResults<OnlineCash>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LiveCash.startTime, ascending: false)])
    private var liveSessions: FetchedResults<LiveCash>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Adjustment.date, ascending: false)])
    private var adjustments: FetchedResults<Adjustment>

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

    @State private var includeAdjustments = true
    @State private var showFilterSheet = false
    @StateObject private var filterState = FilterState()
    @State private var refreshID = UUID()

    var stats: StatsResult {
        computeStats(
            online: Array(onlineSessions),
            live: Array(liveSessions),
            adjustments: Array(adjustments),
            filterState: filterState,
            showAdjustments: includeAdjustments
        )
    }

    func performRefresh() async {
        viewContext.refreshAllObjects()
        refreshID = UUID()
    }

    private var hasActiveSession: Bool {
        !activeLiveSessions.isEmpty || !activeOnlineSessions.isEmpty
    }

    /// Floating bar height (56pt) + its bottom padding (8pt) + 16pt gap above it.
    private static let floatingBarHeight: CGFloat = 56
    private static let floatingBarBottomPadding: CGFloat = 8
    private static let gapAboveFloatingBar: CGFloat = 16

    private var floatingButtonBottomPadding: CGFloat {
        hasActiveSession
            ? (Self.floatingBarHeight + Self.floatingBarBottomPadding + Self.gapAboveFloatingBar)
            : Self.gapAboveFloatingBar
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    netResultHeader
                    performanceSection
                    volumeSection
                    resultsSection
                    platformBreakdown
                }
                .padding()
            }
            .refreshable {
                await performRefresh()
            }
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: 12) {
                    NavigationLink {
                        ChartsView(filterState: filterState)
                            .environment(\.managedObjectContext, viewContext)
                    } label: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "#000000"))
                            .frame(width: 56, height: 56)
                            .background(Color(hex: "#C9B47A"))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        CalendarView()
                            .environment(\.managedObjectContext, viewContext)
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "#000000"))
                            .frame(width: 56, height: 56)
                            .background(Color(hex: "#C9B47A"))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 16)
                .padding(.bottom, floatingButtonBottomPadding)
                .animation(.easeInOut(duration: 0.25), value: floatingButtonBottomPadding)
            }
        }
        .id(refreshID)
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                FilterNavBarButton(activeCount: filterState.activeFilterCount) {
                    showFilterSheet = true
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheetView(filterState: filterState, showSessionsOnlyFilters: false)
                .environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: - Net Result Header

    var netResultHeader: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(baseCurrency)
                    .font(.caption).foregroundColor(.appSecondary)
                Text(AppFormatter.currencySigned(stats.netResult))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(stats.netResult.profitColor)
                    .minimumScaleFactor(0.5)
            }
            Toggle(isOn: $includeAdjustments) {
                Text("Include Adjustments")
                    .font(.caption).foregroundColor(.appSecondary)
            }
            .tint(.appGold)
            .padding(.horizontal, 4)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.appSurface)
        .cornerRadius(8)
    }

    // MARK: - Performance Section

    var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance")
                .font(.headline).foregroundColor(.appGold)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    title: "Hourly Rate",
                    value: AppFormatter.hourlyRate(stats.hourlyRate, code: baseCurrency),
                    icon: "clock.fill",
                    color: stats.sessionCount == 0 ? .appSecondary : stats.hourlyRate.profitColor
                )
                StatCard(
                    title: "Avg Net Result",
                    value: AppFormatter.currencySigned(stats.avgResult, code: baseCurrency),
                    icon: "chart.line.uptrend.xyaxis",
                    color: stats.sessionCount == 0 ? .appSecondary : stats.avgResult.profitColor
                )
                StatCard(
                    title: "Net Result (BB)",
                    value: bbSigned(stats.totalBBWon) + " BB",
                    icon: "b.circle.fill",
                    color: stats.sessionCount == 0 ? .appSecondary : stats.totalBBWon.profitColor
                )
                StatCard(
                    title: "BB / Hour",
                    value: bbSigned(stats.bbPerHour) + " BB/hr",
                    icon: "speedometer",
                    color: stats.sessionCount == 0 ? .appSecondary : stats.bbPerHour.profitColor
                )
                StatCard(
                    title: "BB / 100 Hands",
                    value: bbSigned(stats.bbPer100),
                    icon: "suit.spade.fill",
                    color: stats.totalHands == 0 ? .appSecondary : stats.bbPer100.profitColor
                )
            }
        }
    }

    // MARK: - Volume Section

    var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Volume")
                .font(.headline).foregroundColor(.appGold)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    title: "Sessions",
                    value: "\(stats.sessionCount)",
                    icon: "calendar",
                    color: .appGold,
                    valueColor: .appPrimary
                )
                StatCard(
                    title: "Hours Played",
                    value: AppFormatter.duration(stats.totalHours),
                    icon: "timer",
                    color: .appGold,
                    valueColor: .appPrimary
                )
                StatCard(
                    title: "Hands Played",
                    value: AppFormatter.handsCount(stats.totalHands),
                    icon: "suit.spade.fill",
                    color: .appGold,
                    valueColor: .appPrimary
                )
                StatCard(
                    title: "Avg Session",
                    value: AppFormatter.duration(stats.avgSessionDuration),
                    icon: "hourglass",
                    color: .appGold,
                    valueColor: .appPrimary
                )
                StatCard(
                    title: "Avg Buy In",
                    value: AppFormatter.currency(stats.avgBuyIn, code: baseCurrency),
                    icon: "dollarsign.circle.fill",
                    color: .appGold,
                    valueColor: .appPrimary
                )
                StatCard(
                    title: "Total Tips",
                    value: AppFormatter.currency(stats.totalTips, code: baseCurrency),
                    icon: "heart.fill",
                    color: .appGold,
                    valueColor: .appPrimary
                )
            }
        }
    }

    // MARK: - Results Section

    var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.headline).foregroundColor(.appGold)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    title: "Win Rate",
                    value: AppFormatter.percentage(stats.winRate),
                    icon: "trophy.fill",
                    color: winRateColor
                )
                StatCard(
                    title: "Winning Sessions",
                    value: "\(stats.winCount)",
                    icon: "arrow.up.circle.fill",
                    color: .appProfit
                )
                StatCard(
                    title: "Losing Sessions",
                    value: "\(stats.loseCount)",
                    icon: "arrow.down.circle.fill",
                    color: .appLoss
                )
                StatCard(
                    title: "Biggest Win",
                    value: AppFormatter.currencySigned(stats.biggestWin, code: baseCurrency),
                    icon: "star.fill",
                    color: stats.sessionCount == 0 ? .appSecondary : .appProfit
                )
                StatCard(
                    title: "Biggest Loss",
                    value: AppFormatter.currencySigned(stats.biggestLoss, code: baseCurrency),
                    icon: "exclamationmark.circle.fill",
                    color: stats.sessionCount == 0 ? .appSecondary : .appLoss
                )
                StatCard(
                    title: "Longest Session",
                    value: AppFormatter.duration(stats.longestSessionHours),
                    icon: "moon.stars.fill",
                    color: stats.sessionCount == 0 ? .appSecondary : .appGold
                )
                StatCard(
                    title: "Win Streak",
                    value: "\(stats.longestWinStreak)",
                    icon: "flame.fill",
                    color: stats.sessionCount == 0 ? .appSecondary : .appProfit
                )
                StatCard(
                    title: "Lose Streak",
                    value: "\(stats.longestLoseStreak)",
                    icon: "snowflake",
                    color: stats.sessionCount == 0 ? .appSecondary : .appLoss
                )
            }
        }
    }

    var winRateColor: Color {
        if stats.sessionCount == 0 { return .appSecondary }
        if stats.winRate == 0.5 { return .appSecondary }
        return stats.winRate > 0.5 ? .appProfit : .appLoss
    }

    func bbSigned(_ value: Double) -> String {
        let formatted = AppFormatter.bbValue(abs(value))
        if value > 0 { return "+\(formatted)" }
        if value < 0 { return "-\(formatted)" }
        return formatted
    }

    // MARK: - Platform Breakdown

    var platformBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Platform Breakdown")
                .font(.headline).foregroundColor(.appGold)
            if platforms.isEmpty {
                Text("No platforms added yet.")
                    .font(.subheadline).foregroundColor(.appSecondary)
                    .padding().frame(maxWidth: .infinity)
                    .background(Color.appSurface).cornerRadius(8)
            } else {
                ForEach(Array(platforms)) { platform in
                    PlatformBreakdownRow(platform: platform, baseCurrency: baseCurrency)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var valueColor: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(color).font(.caption)
                Spacer()
            }
            Text(value)
                .font(.title3).fontWeight(.bold).foregroundColor(valueColor ?? color)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(title)
                .font(.caption).foregroundColor(.appSecondary)
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(8)
    }
}

struct PlatformBreakdownRow: View {
    let platform: Platform
    let baseCurrency: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(platform.displayName)
                    .font(.subheadline).fontWeight(.medium).foregroundColor(.appPrimary)
                HStack(spacing: 8) {
                    Text("Balance: \(AppFormatter.currency(platform.currentBalance, code: platform.displayCurrency))")
                        .font(.caption).foregroundColor(.appSecondary)
                    Text("·").foregroundColor(.appBorder)
                    Text("\(platform.onlineSessionsArray.count) sessions")
                        .font(.caption).foregroundColor(.appSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(AppFormatter.currencySigned(platform.netResult))
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(platform.netResult.profitColor)
                Text("net result")
                    .font(.caption2).foregroundColor(.appSecondary)
            }
        }
        .padding().background(Color.appSurface).cornerRadius(8)
    }
}

#Preview {
    StatsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .preferredColorScheme(.dark)
}
