import SwiftUI
import CoreData
import Charts

// MARK: - Chart point with full session context for tooltip

struct ChartPointData: Identifiable {
    let id: Int
    let x: Double
    let y: Double
    let sessionIndex: Int
    let startTime: Date
    let isLive: Bool
    let locationOrPlatformName: String
    let durationHours: Double
    let hands: Int
    let gameType: String
    let blindsString: String
}

// MARK: - Charts View

struct ChartsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"
    @ObservedObject var filterState: FilterState
    @StateObject private var chartFilterState = ChartFilterState()

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \OnlineCash.startTime, ascending: false)])
    private var onlineSessions: FetchedResults<OnlineCash>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LiveCash.startTime, ascending: false)])
    private var liveSessions: FetchedResults<LiveCash>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Location.name, ascending: true)])
    private var allLocations: FetchedResults<Location>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)])
    private var allPlatforms: FetchedResults<Platform>

    enum XAxisOption: String, CaseIterable {
        case sessions = "Sessions"
        case hoursPlayed = "Hours Played"
        case handsPlayed = "Hands Played"
    }

    enum YAxisOption: String, CaseIterable {
        case netResult = "Net Result"
        case hourlyRate = "Hourly Rate"
        case bbWon = "BB Won"
        case bbPer100 = "BB/100"
    }

    @State private var xAxis: XAxisOption = .sessions
    @State private var yAxis: YAxisOption = .netResult
    @State private var selectedPointIndex: Int? = nil
    @State private var selectedPointScreenPosition: CGPoint? = nil
    @State private var chartPlotSize: CGSize? = nil
    @State private var showStakesSheet = false
    @State private var showLocationSheet = false
    @State private var showPlatformSheet = false

    private let goldColor = Color(hex: "#C9B47A")
    private let grayAxis = Color(hex: "#8A8A8A")
    private let gridColor = Color(hex: "#2A2A2A")
    private let zeroLineColor = Color(hex: "#666666")
    private let cardBg = Color(hex: "#0D0D0D")
    private let tooltipBg = Color(hex: "#1A1A1A")
    private let dividerColor = Color(hex: "#2A2A2A")

    // MARK: - Chart-filtered sessions (uses chartFilterState only)

    var chartFilteredSessions: [(session: Any, startTime: Date, durationHours: Double, netBase: Double, hands: Int, bbWon: Double, bbPer100: Double, isLive: Bool, locationOrPlatformName: String, gameType: String, blindsString: String)] {
        var list: [(Any, Date, Double, Double, Int, Double, Double, Bool, String, String, String)] = []

        switch chartFilterState.sessionType {
        case .all, .live:
            for s in liveSessions {
                guard chartFilterState.isDateIncluded(s.sessionDate) else { continue }
                if let locID = chartFilterState.selectedLocationID {
                    guard s.locationEntity?.id == locID else { continue }
                }
                let blindsStr = blindLevelString(sb: s.smallBlind, bb: s.bigBlind)
                if !chartFilterState.selectedStakes.isEmpty {
                    guard chartFilterState.selectedStakes.contains(blindsStr) else { continue }
                }
                list.append((s, s.sessionDate, s.computedDuration, s.netResultBase, s.effectiveHands, s.bbWon, s.bbPer100, true, s.displayLocation, s.displayGameType, s.displayBlinds))
            }
        case .online:
            break
        }

        switch chartFilterState.sessionType {
        case .all, .online:
            for s in onlineSessions {
                guard chartFilterState.isDateIncluded(s.sessionDate) else { continue }
                if let platID = chartFilterState.selectedPlatformID {
                    guard s.platform?.id == platID else { continue }
                }
                let blindsStr = blindLevelString(sb: s.smallBlind, bb: s.bigBlind)
                if !chartFilterState.selectedStakes.isEmpty {
                    guard chartFilterState.selectedStakes.contains(blindsStr) else { continue }
                }
                list.append((s, s.sessionDate, s.computedDuration, s.netProfitLossBase, s.effectiveHands, s.bbWon, s.bbPer100, false, s.platformName, s.displayGameType, s.displayBlinds))
            }
        case .live:
            break
        }

        list.sort { ($0.1 as Date) < ($1.1 as Date) }
        return list.map { (session: $0.0, startTime: $0.1, durationHours: $0.2, netBase: $0.3, hands: $0.4, bbWon: $0.5, bbPer100: $0.6, isLive: $0.7, locationOrPlatformName: $0.8, gameType: $0.9, blindsString: $0.10) }
    }

    private func blindLevelString(sb: Double, bb: Double) -> String {
        guard sb > 0, bb > 0 else { return "" }
        return "\(AppFormatter.blindValue(sb))/\(AppFormatter.blindValue(bb))"
    }

    var uniqueStakesFromSessions: [String] {
        var set = Set<String>()
        for s in liveSessions {
            let b = blindLevelString(sb: s.smallBlind, bb: s.bigBlind)
            if !b.isEmpty { set.insert(b) }
        }
        for s in onlineSessions {
            let b = blindLevelString(sb: s.smallBlind, bb: s.bigBlind)
            if !b.isEmpty { set.insert(b) }
        }
        return set.sorted()
    }

    var chartPoints: [ChartPointData] {
        var sessions = chartFilteredSessions
        if xAxis == .handsPlayed {
            sessions = sessions.filter { $0.hands > 0 }
        }
        guard !sessions.isEmpty else { return [] }

        var cumHours: Double = 0
        var cumHands: Int = 0
        var cumNet: Double = 0
        var cumBB: Double = 0

        var points: [ChartPointData] = []
        for (idx, s) in sessions.enumerated() {
            cumHours += s.durationHours
            cumHands += s.hands

            let xVal: Double
            switch xAxis {
            case .sessions: xVal = Double(idx + 1)
            case .hoursPlayed: xVal = cumHours
            case .handsPlayed: xVal = Double(cumHands)
            }

            let yVal: Double
            switch yAxis {
            case .netResult:
                cumNet += s.netBase
                yVal = cumNet
            case .hourlyRate:
                yVal = s.netBase / max(s.durationHours, 0.01)
            case .bbWon:
                cumBB += s.bbWon
                yVal = cumBB
            case .bbPer100:
                yVal = s.bbPer100
            }

            points.append(ChartPointData(
                id: idx,
                x: xVal,
                y: yVal,
                sessionIndex: idx + 1,
                startTime: s.startTime,
                isLive: s.isLive,
                locationOrPlatformName: s.locationOrPlatformName,
                durationHours: s.durationHours,
                hands: s.hands,
                gameType: s.gameType,
                blindsString: s.blindsString
            ))
        }
        return points
    }

    var dataPointCount: Int { chartPoints.count }
    var chartFiltersActive: Bool { chartFilterState.activeFilterCount > 0 }
    var xAxisTitle: String { xAxis.rawValue }

    private func chartValueFormatted(_ value: Double) -> String {
        switch yAxis {
        case .netResult, .hourlyRate:
            return AppFormatter.currencySigned(value, code: baseCurrency)
        case .bbWon, .bbPer100:
            return "\(AppFormatter.bbValue(value)) BB"
        }
    }

    private var chartMetricTitle: String {
        switch yAxis {
        case .netResult: return "Net Result (\(baseCurrency))"
        case .hourlyRate: return "Hourly Rate (\(baseCurrency)/hr)"
        case .bbWon: return "BB Won"
        case .bbPer100: return "BB/100 Hands"
        }
    }

    private var yRangeCrossesZero: Bool {
        guard !chartPoints.isEmpty else { return false }
        let ys = chartPoints.map(\.y)
        return (ys.min() ?? 0) <= 0 && (ys.max() ?? 0) >= 0
    }

    /// Y scale domain (low...high) so positive values appear at top, negative at bottom.
    private var yScaleDomain: ClosedRange<Double>? {
        guard !chartPoints.isEmpty else { return nil }
        let ys = chartPoints.map(\.y)
        let low = ys.min() ?? 0
        let high = ys.max() ?? 0
        let span = high - low
        let padding = span > 0 ? span * 0.05 : 1.0
        var yMin = low - padding
        var yMax = high + padding
        if yRangeCrossesZero {
            if yMin > 0 { yMin = 0 }
            if yMax < 0 { yMax = 0 }
        }
        return yMin ... yMax
    }

    private func chartYAxisTickLabel(_ value: Double) -> String {
        switch yAxis {
        case .netResult, .hourlyRate:
            return AppFormatter.currencyCompact(value, code: baseCurrency)
        case .bbWon, .bbPer100:
            return "\(AppFormatter.bbValue(value)) BB"
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    chartCard
                    statsBar
                    configCard
                    chartFiltersCard
                }
                .padding()
            }
        }
        .navigationTitle("Charts")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showStakesSheet) {
            ChartStakesPickerSheet(selectedStakes: $chartFilterState.selectedStakes, options: uniqueStakesFromSessions)
        }
        .sheet(isPresented: $showLocationSheet) {
            LocationPickerSheet(selectedLocation: Binding(
                get: { chartFilterState.selectedLocationID.flatMap { id in allLocations.first { $0.id == id } } },
                set: { chartFilterState.selectedLocationID = $0?.id }
            ), onSelectNone: { chartFilterState.selectedLocationID = nil })
            .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showPlatformSheet) {
            ChartPlatformPickerSheet(platforms: Array(allPlatforms), selectedPlatformID: $chartFilterState.selectedPlatformID)
        }
    }

    // MARK: - Chart Card

    var chartCard: some View {
        Group {
            if chartPoints.isEmpty {
                emptyStateView
            } else {
                chartWithOverlay
            }
        }
        .frame(height: 320)
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(cardBg)
        .cornerRadius(16)
    }

    var emptyStateView: some View {
        VStack(spacing: 0) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(goldColor.opacity(0.6))
            Text("No Sessions to Chart")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .padding(.top, 16)
            Text("Start logging sessions to see your results here")
                .font(.system(size: 14))
                .foregroundColor(grayAxis)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
    }

    private var chartWithAxes: some View {
        let areaGradient = LinearGradient(
            colors: [goldColor.opacity(0.3), Color.clear],
            startPoint: .top,
            endPoint: .bottom
        )
        let zeroLineDashStyle = StrokeStyle(lineWidth: 1, dash: [4, 4])

        let baseChart = Chart {
            if yRangeCrossesZero {
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color(hex: "#555555"))
                    .lineStyle(zeroLineDashStyle)
            }
            ForEach(chartPoints) { point in
                let isSelected = selectedPointIndex == point.id
                LineMark(x: .value("X", point.x), y: .value("Y", point.y))
                    .foregroundStyle(goldColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("X", point.x), y: .value("Y", point.y))
                    .foregroundStyle(areaGradient)
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("X", point.x), y: .value("Y", point.y))
                    .foregroundStyle(goldColor)
                    .symbolSize(isSelected ? 64 : 25)
            }
        }
        let chartWithYScale: some View = Group {
            if let domain = yScaleDomain {
                baseChart.chartYScale(domain: domain)
            } else {
                baseChart
            }
        }
        return chartWithYScale
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
                AxisValueLabel()
                    .foregroundStyle(grayAxis)
                    .font(.system(size: 11))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color(hex: "#1E1E1E"))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(chartYAxisTickLabel(v))
                            .foregroundStyle(grayAxis)
                            .font(.system(size: 11))
                    } else {
                        Text("")
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                chartOverlayContent(proxy: proxy, geo: geo)
            }
        }
    }

    private func chartOverlayContent(proxy: ChartProxy, geo: GeometryProxy) -> some View {
        let frame: CGRect
        if #available(iOS 17.0, *) {
            frame = CGRect(origin: .zero, size: geo.size)
        } else {
            frame = geo[proxy.plotAreaFrame]
        }
        return ZStack(alignment: .trailing) {
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    findNearestPoint(proxy: proxy, location: location, plotFrame: frame)
                }
        }
        .onAppear {
            chartPlotSize = CGSize(width: frame.width, height: frame.height)
        }
        .onChange(of: chartPoints.count) { _, _ in
            chartPlotSize = CGSize(width: frame.width, height: frame.height)
        }
    }

    var chartWithOverlay: some View {
        let chart = chartWithAxes

        return ZStack(alignment: .topLeading) {
            chart
                .animation(.easeInOut(duration: 0.4), value: xAxis)
                .animation(.easeInOut(duration: 0.4), value: yAxis)
                .animation(.easeInOut(duration: 0.4), value: chartFilterState.sessionType)
                .animation(.easeInOut(duration: 0.4), value: chartFilterState.dateRange)
                .animation(.easeInOut(duration: 0.4), value: chartFilterState.selectedStakes)
                .animation(.easeInOut(duration: 0.4), value: chartFilterState.selectedLocationID)
                .animation(.easeInOut(duration: 0.4), value: chartFilterState.selectedPlatformID)

            if let idx = selectedPointIndex, idx < chartPoints.count, let pos = selectedPointScreenPosition, let plotSize = chartPlotSize {
                tooltipView(for: chartPoints[idx], position: pos, plotSize: plotSize)
                    .onTapGesture { selectedPointIndex = nil; selectedPointScreenPosition = nil }
            }
        }
    }

    private func findNearestPoint(proxy: ChartProxy, location: CGPoint, plotFrame: CGRect) {
        var nearest: Int? = nil
        var minDist: CGFloat = .infinity
        var hitPos: CGPoint? = nil
        for (i, point) in chartPoints.enumerated() {
            guard let posX = proxy.position(forX: point.x),
                  let posY = proxy.position(forY: point.y) else { continue }
            let pos = CGPoint(x: posX + plotFrame.minX, y: posY + plotFrame.minY)
            let dist = hypot(pos.x - location.x, pos.y - location.y)
            if dist < minDist {
                minDist = dist
                nearest = i
                hitPos = pos
            }
        }
        let hitThreshold: CGFloat = 44
        if let n = nearest, minDist < hitThreshold {
            if selectedPointIndex == n {
                selectedPointIndex = nil
                selectedPointScreenPosition = nil
            } else {
                selectedPointIndex = n
                selectedPointScreenPosition = hitPos
            }
        } else {
            selectedPointIndex = nil
            selectedPointScreenPosition = nil
        }
    }

    private func tooltipView(for point: ChartPointData, position: CGPoint, plotSize: CGSize) -> some View {
        let isLowerHalf = position.y > plotSize.height / 2
        let isLeftSide = position.x < plotSize.width * 0.4
        let tooltipW: CGFloat = 220
        let tooltipH: CGFloat = 220
        let pad: CGFloat = 8
        let xOffset: CGFloat = isLeftSide ? 0 : -tooltipW
        let yOffset: CGFloat = isLowerHalf ? -tooltipH - 12 : 12
        let rawX = position.x + xOffset
        let rawY = position.y + yOffset
        let xClamp = min(max(rawX, pad), plotSize.width - tooltipW - pad)
        let yClamp2 = min(max(rawY, pad), plotSize.height - tooltipH - pad)

        return VStack(alignment: .leading, spacing: 0) {
            Text(AppFormatter.longDate(point.startTime))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(goldColor)
            Text(point.isLive ? "Live · \(point.locationOrPlatformName)" : "Online · \(point.locationOrPlatformName)")
                .font(.system(size: 12))
                .foregroundColor(grayAxis)
            Divider().background(dividerColor).padding(.vertical, 8)
            Text(chartValueFormatted(point.y))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(chartValueColor(point.y))
            Text(xAxisContextString(point))
                .font(.system(size: 12))
                .foregroundColor(grayAxis)
            Divider().background(dividerColor).padding(.vertical, 8)
            HStack(spacing: 16) {
                Label(AppFormatter.duration(point.durationHours), systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(grayAxis)
                Label(point.hands == 0 ? "—" : "\(point.hands)", systemImage: "suit.spade.fill")
                    .font(.system(size: 12))
                    .foregroundColor(grayAxis)
            }
            if yAxis == .netResult || yAxis == .hourlyRate {
                Text("\(point.gameType) \(point.blindsString)")
                    .font(.system(size: 12))
                    .foregroundColor(grayAxis)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(minWidth: 200, alignment: .leading)
        .background(tooltipBg)
        .cornerRadius(12)
        .shadow(radius: 10)
        .offset(x: xClamp, y: yClamp2)
    }

    private func chartValueColor(_ value: Double) -> Color {
        if yAxis == .bbWon || yAxis == .bbPer100 { return .white }
        if value > 0 { return Color(hex: "#4CAF50") }
        if value < 0 { return Color(hex: "#F44336") }
        return grayAxis
    }

    private func xAxisContextString(_ point: ChartPointData) -> String {
        switch xAxis {
        case .sessions: return "Session \(point.sessionIndex)"
        case .hoursPlayed: return String(format: "%.1f hrs played", point.x)
        case .handsPlayed:
            let nf = NumberFormatter()
            nf.numberStyle = .decimal
            let str = nf.string(from: NSNumber(value: point.x)) ?? "\(Int(point.x))"
            return "\(str) hands played"
        }
    }

    var statsBar: some View {
        HStack {
            Text("\(dataPointCount) sessions")
                .font(.system(size: 12))
                .foregroundColor(grayAxis)
            Spacer()
            Text(chartMetricTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(goldColor)
            Spacer()
            if chartFiltersActive {
                HStack(spacing: 4) {
                    Circle().fill(goldColor).frame(width: 6, height: 6)
                    Text("Filtered")
                        .font(.system(size: 12))
                        .foregroundColor(grayAxis)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    var configCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("X Axis").font(.subheadline).foregroundColor(grayAxis)
                Spacer()
                Picker("X Axis", selection: $xAxis) {
                    ForEach(XAxisOption.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu).tint(.appGold)
            }
            .padding(16)
            Divider().background(gridColor)
            HStack {
                Text("Y Axis").font(.subheadline).foregroundColor(grayAxis)
                Spacer()
                Picker("Y Axis", selection: $yAxis) {
                    ForEach(YAxisOption.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu).tint(.appGold)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .background(cardBg)
        .cornerRadius(16)
    }

    // MARK: - Chart Filters Card

    var chartFiltersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Chart Filters")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(goldColor)
                if chartFiltersActive {
                    Circle().fill(goldColor).frame(width: 6, height: 6)
                    Text("\(chartFilterState.activeFilterCount)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(goldColor)
                        .cornerRadius(8)
                }
            }
            VStack(spacing: 0) {
                HStack {
                    Text("Session Type").font(.subheadline).foregroundColor(grayAxis)
                    Spacer()
                    Picker("Session Type", selection: $chartFilterState.sessionType) {
                        ForEach([ChartSessionType.all, .live, .online], id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                .padding(.vertical, 12)
                Divider().background(gridColor)
                HStack {
                    Text("Stakes").font(.subheadline).foregroundColor(grayAxis)
                    Spacer()
                    Button {
                        showStakesSheet = true
                    } label: {
                        Text(stakesDisplayText)
                            .foregroundColor(.white)
                    }
                }
                .padding(.vertical, 12)
                Divider().background(gridColor)
                if chartFilterState.sessionType == .all || chartFilterState.sessionType == .live {
                    HStack {
                        Text("Location").font(.subheadline).foregroundColor(grayAxis)
                        Spacer()
                        Button {
                            showLocationSheet = true
                        } label: {
                            Text(locationDisplayText)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.vertical, 12)
                    Divider().background(gridColor)
                }
                if chartFilterState.sessionType == .all || chartFilterState.sessionType == .online {
                    HStack {
                        Text("Platform").font(.subheadline).foregroundColor(grayAxis)
                        Spacer()
                        Button {
                            showPlatformSheet = true
                        } label: {
                            Text(platformDisplayText)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.vertical, 12)
                    Divider().background(gridColor)
                }
                HStack {
                    Text("Date Range").font(.subheadline).foregroundColor(grayAxis)
                    Spacer()
                    Picker("Date Range", selection: $chartFilterState.dateRange) {
                        ForEach(ChartDateRange.allCases, id: \.self) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.menu).tint(.appGold)
                }
                .padding(.vertical, 12)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(cardBg)
        .cornerRadius(16)
        .animation(.easeInOut(duration: 0.4), value: chartFilterState.sessionType)
    }

    var stakesDisplayText: String {
        if chartFilterState.selectedStakes.isEmpty { return "All Stakes" }
        if chartFilterState.selectedStakes.count == 1 { return chartFilterState.selectedStakes.first! }
        return "\(chartFilterState.selectedStakes.count) selected"
    }

    var locationDisplayText: String {
        guard let id = chartFilterState.selectedLocationID,
              let loc = allLocations.first(where: { $0.id == id }) else { return "All Locations" }
        return loc.displayName
    }

    var platformDisplayText: String {
        guard let id = chartFilterState.selectedPlatformID,
              let plat = allPlatforms.first(where: { $0.id == id }) else { return "All Platforms" }
        return plat.displayName
    }
}

// MARK: - Stakes Picker Sheet

struct ChartStakesPickerSheet: View {
    @Binding var selectedStakes: Set<String>
    let options: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            selectedStakes = []
                            dismiss()
                        } label: {
                            HStack {
                                Text("All Stakes")
                                    .foregroundColor(.white)
                                Spacer()
                                if selectedStakes.isEmpty {
                                    Image(systemName: "checkmark").foregroundColor(.appGold)
                                }
                            }
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(10)
                        }
                        Text("Select one or more")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#8A8A8A"))
                        FlowLayout(spacing: 8) {
                            ForEach(options, id: \.self) { stake in
                                let isSelected = selectedStakes.contains(stake)
                                Button {
                                    if isSelected {
                                        selectedStakes.remove(stake)
                                    } else {
                                        selectedStakes.insert(stake)
                                    }
                                } label: {
                                    Text(stake)
                                        .font(.subheadline)
                                        .foregroundColor(isSelected ? .black : .white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? Color(hex: "#C9B47A") : Color(hex: "#2A2A2A"))
                                        .cornerRadius(20)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Stakes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.appGold)
                }
            }
        }
    }
}

// MARK: - Platform Picker for Chart (single selection, optional)

struct ChartPlatformPickerSheet: View {
    let platforms: [Platform]
    @Binding var selectedPlatformID: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                List {
                    Button {
                        selectedPlatformID = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("All Platforms").foregroundColor(.white)
                            Spacer()
                            if selectedPlatformID == nil { Image(systemName: "checkmark").foregroundColor(.appGold) }
                        }
                    }
                    .listRowBackground(Color.appSurface)
                    ForEach(platforms) { p in
                        Button {
                            selectedPlatformID = p.id
                            dismiss()
                        } label: {
                            HStack {
                                Text(p.displayName).foregroundColor(.white)
                                Spacer()
                                if p.id == selectedPlatformID { Image(systemName: "checkmark").foregroundColor(.appGold) }
                            }
                        }
                        .listRowBackground(Color.appSurface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Platform")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.appGold)
                }
            }
        }
    }
}

// MARK: - Flow layout for chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (i, pos) in result.positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? 400
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var positions: [CGPoint] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        let totalHeight = y + rowHeight
        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

#Preview {
    NavigationStack {
        ChartsView(filterState: FilterState())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .preferredColorScheme(.dark)
}
