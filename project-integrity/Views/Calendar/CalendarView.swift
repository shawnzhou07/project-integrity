import SwiftUI
import CoreData

// MARK: - Session reference for calendar (online or live)
enum CalendarSessionItem: Identifiable {
    case online(OnlineCash)
    case live(LiveCash)

    var id: UUID {
        switch self {
        case .online(let s): return s.id ?? UUID()
        case .live(let s): return s.id ?? UUID()
        }
    }

    var startTime: Date { sessionDate }
    var sessionDate: Date {
        switch self {
        case .online(let s): return s.startTime ?? Date()
        case .live(let s): return s.startTime ?? Date()
        }
    }
    var netProfitLossBase: Double {
        switch self {
        case .online(let s): return s.netProfitLossBase
        case .live(let s): return s.netResultBase
        }
    }
    var computedDuration: Double {
        switch self {
        case .online(let s): return s.computedDuration
        case .live(let s): return s.computedDuration
        }
    }
    var handsCount: Int {
        switch self {
        case .online(let s): return Int(s.effectiveHands)
        case .live(let s): return Int(s.effectiveHands)
        }
    }
    var isLive: Bool {
        if case .live = self { return true }
        return false
    }
    var gameTypeBlinds: String {
        switch self {
        case .online(let s): return s.displayBlinds.isEmpty ? (s.displayGameType ) : "\(s.displayGameType) \(s.displayBlinds)"
        case .live(let s): return s.displayBlinds.isEmpty ? (s.displayGameType ) : "\(s.displayGameType) \(s.displayBlinds)"
        }
    }
    var currencyCode: String {
        switch self {
        case .online(let s): return s.platform?.displayCurrency ?? "CAD"
        case .live(let s): return s.currency ?? "CAD"
        }
    }
}

// MARK: - Day aggregate for calendar
struct DayStats {
    var netResultBase: Double = 0
    var durationHours: Double = 0
    var handsCount: Int = 0
    var sessions: [CalendarSessionItem] = []
    var sessionCount: Int { sessions.count }
}

// MARK: - Calendar amount format (strict 3 significant digits / compact rules)
func formatCalendarAmount(_ value: Double) -> String {
    let absVal = abs(value)
    let sign = value > 0 ? "+" : (value < 0 ? "-" : "")
    if value == 0 { return "0" }
    if absVal >= 1_000_000 {
        let n = absVal / 1_000_000
        let str = toThreeSignificantDigits(n)
        return sign + str + "m"
    }
    if absVal >= 10_000 {
        let n = absVal / 1_000
        let str = toMaxOneDecimal(n)
        return sign + str + "k"
    }
    if absVal >= 1_000 {
        let n = absVal / 1_000
        let str = toMaxTwoDecimalsStripZeros(n)
        return sign + str + "k"
    }
    if absVal >= 100 {
        return sign + "\(Int(absVal.rounded()))"
    }
    if absVal >= 10 {
        let str = toMaxOneDecimal(absVal)
        return sign + str
    }
    let str = toMaxTwoDecimalsStripZeros(absVal)
    return sign + str
}

private func toThreeSignificantDigits(_ value: Double) -> String {
    guard value.isFinite, value > 0 else { return "0" }
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumSignificantDigits = 1
    formatter.maximumSignificantDigits = 3
    formatter.decimalSeparator = "."
    let s = formatter.string(from: NSNumber(value: value)) ?? "0"
    return trimTrailingZerosFromNumberString(s)
}

private func toMaxOneDecimal(_ value: Double) -> String {
    guard value.isFinite else { return "0" }
    let formatter = NumberFormatter()
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 1
    formatter.decimalSeparator = "."
    formatter.minimumIntegerDigits = 1
    let s = formatter.string(from: NSNumber(value: value)) ?? "0"
    return trimTrailingZerosFromNumberString(s)
}

private func toMaxTwoDecimalsStripZeros(_ value: Double) -> String {
    guard value.isFinite else { return "0" }
    let formatter = NumberFormatter()
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 2
    formatter.decimalSeparator = "."
    formatter.minimumIntegerDigits = 1
    let s = formatter.string(from: NSNumber(value: value)) ?? "0"
    return trimTrailingZerosFromNumberString(s)
}

private func trimTrailingZerosFromNumberString(_ s: String) -> String {
    var t = s
    while t.hasSuffix("0") { t.removeLast() }
    if t.hasSuffix(".") { t.removeLast() }
    return t
}

// MARK: - Calendar menu button style (subtle pressed opacity)
private struct CalendarMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Calendar View

struct CalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \OnlineCash.startTime, ascending: true)])
    private var onlineSessions: FetchedResults<OnlineCash>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LiveCash.startTime, ascending: true)])
    private var liveSessions: FetchedResults<LiveCash>

    @State private var displayedMonth: Date = Date()
    @State private var dayStats: [Date: DayStats] = [:]
    @State private var selectedDay: Date? = nil
    @State private var showMonthPicker = false
    @State private var showYearPicker = false
    @State private var refreshID = UUID()
    @State private var slideForward = true

    private let cal = Calendar.current
    private let goldColor = Color(hex: "#C9B47A")
    private let grayDim = Color(hex: "#8A8A8A")
    private let grayFiller = Color(hex: "#3A3A3A")
    private let bgBlack = Color(hex: "#000000")
    private let greenBg = Color(hex: "#0D2B0D")
    private let greenBorder = Color(hex: "#4CAF50")
    private let redBg = Color(hex: "#2B0D0D")
    private let redBorder = Color(hex: "#F44336")
    private let zeroBg = Color(hex: "#1A1A1A")
    private let zeroBorder = Color(hex: "#555555")
    private let cardBg = Color(hex: "#0D0D0D")
    private let separatorColor = Color(hex: "#2A2A2A")
    private let greenBgTop = Color(hex: "#0F330F")
    private let redBgTop = Color(hex: "#330F0F")
    private let zeroBgTop = Color(hex: "#222222")

    private var monthYearComponents: DateComponents {
        cal.dateComponents([.year, .month], from: displayedMonth)
    }

    private var firstDayOfMonth: Date {
        cal.date(from: DateComponents(year: cal.component(.year, from: displayedMonth), month: cal.component(.month, from: displayedMonth), day: 1)) ?? displayedMonth
    }

    private var numberOfDaysInMonth: Int {
        cal.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
    }

    private var firstWeekdayOneBased: Int {
        let weekday = cal.component(.weekday, from: firstDayOfMonth)
        return weekday
    }

    var body: some View {
        ZStack {
            bgBlack.ignoresSafeArea()
            VStack(spacing: 0) {
                monthYearBar
                Rectangle()
                    .fill(separatorColor)
                    .frame(height: 1)
                dayOfWeekHeader
                Rectangle()
                    .fill(separatorColor)
                    .frame(height: 1)
                monthGrid(for: displayedMonth)
                    .id(displayedMonth)
                    .transition(.asymmetric(
                        insertion: .move(edge: slideForward ? .trailing : .leading),
                        removal: .move(edge: slideForward ? .leading : .trailing)
                    ))
                    .animation(.easeInOut(duration: 0.25), value: displayedMonth)
                    .gesture(
                        DragGesture(minimumDistance: 30)
                            .onEnded { value in
                                let thresh: CGFloat = 50
                                if value.translation.width < -thresh {
                                    slideForward = true
                                    advanceMonth(by: 1)
                                } else if value.translation.width > thresh {
                                    slideForward = false
                                    advanceMonth(by: -1)
                                }
                            }
                    )
                    .onChange(of: displayedMonth) { _, _ in
                        recomputeDayStats()
                    }
            }
        }
        .id(refreshID)
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .background(bgBlack)
        .refreshable {
            await performRefresh()
        }
        .sheet(item: selectedDayBinding) { day in
            dayDetailSheet(for: day)
        }
        .onAppear {
            recomputeDayStats()
        }
    }

    private var monthYearBar: some View {
        HStack {
            Button {
                slideForward = false
                withAnimation(.easeInOut(duration: 0.25)) { advanceMonth(by: -1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(goldColor)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            HStack(spacing: 8) {
                Menu {
                    ForEach(1...12, id: \.self) { month in
                        Button(monthName(month)) {
                            slideForward = (month > cal.component(.month, from: displayedMonth))
                            setMonth(month)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(monthName(cal.component(.month, from: displayedMonth)))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(goldColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#1A1A1A"))
                    .cornerRadius(8)
                }
                .buttonStyle(CalendarMenuButtonStyle())

                Menu {
                    ForEach(2020...2030, id: \.self) { year in
                        Button(String(year)) {
                            slideForward = (year > cal.component(.year, from: displayedMonth))
                            setYear(year)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(String(cal.component(.year, from: displayedMonth)))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(goldColor)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(goldColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#1A1A1A"))
                    .cornerRadius(8)
                }
                .buttonStyle(CalendarMenuButtonStyle())
            }
            Spacer()
            Button {
                slideForward = true
                withAnimation(.easeInOut(duration: 0.25)) { advanceMonth(by: 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(goldColor)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(bgBlack)
    }

    private func monthName(_ month: Int) -> String {
        let d = cal.date(from: DateComponents(year: 2024, month: month, day: 1))!
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: d)
    }

    private func advanceMonth(by delta: Int) {
        if let next = cal.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = next
        }
    }

    private func setMonth(_ month: Int) {
        let year = cal.component(.year, from: displayedMonth)
        if let d = cal.date(from: DateComponents(year: year, month: month, day: 1)) {
            withAnimation(.easeInOut(duration: 0.25)) { displayedMonth = d }
        }
    }

    private func setYear(_ year: Int) {
        let month = cal.component(.month, from: displayedMonth)
        if let d = cal.date(from: DateComponents(year: year, month: month, day: 1)) {
            withAnimation(.easeInOut(duration: 0.25)) { displayedMonth = d }
        }
    }

    private var dayOfWeekHeader: some View {
        HStack(spacing: 0) {
            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { d in
                Text(d)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(grayDim)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }

    private static let cellRowHeight: CGFloat = 72
    private static let cellSpacing: CGFloat = 4
    private static let gridHorizontalPadding: CGFloat = 16

    private func monthGrid(for month: Date) -> some View {
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
        let firstWeekday = cal.component(.weekday, from: monthStart)
        let startOffset = firstWeekday - 1

        return GeometryReader { geo in
            let cellW = max(0, (geo.size.width - 32) / 7)
            VStack(spacing: Self.cellSpacing) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col
                            let dayOffset = idx - startOffset
                            let cellDate = cal.date(byAdding: .day, value: dayOffset, to: monthStart)
                            dayCell(cellDate: cellDate, monthStart: monthStart, cellWidth: cellW)
                        }
                    }
                    .frame(height: Self.cellRowHeight)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func dayCell(cellDate: Date?, monthStart: Date, cellWidth: CGFloat) -> some View {
        let isCurrentMonth = cellDate.map { cal.isDate($0, equalTo: monthStart, toGranularity: .month) } ?? false
        let startOfDay = cellDate.map { cal.startOfDay(for: $0) }
        let stats = startOfDay.flatMap { dayStats[$0] }
        let hasSessions = stats.map { $0.sessionCount > 0 } ?? false
        let dayNum = cellDate.map { cal.component(.day, from: $0) } ?? 0

        return ZStack(alignment: .top) {
            if isCurrentMonth && hasSessions, let s = stats {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [gradientTop(for: s.netResultBase), backgroundColor(for: s.netResultBase)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor(for: s.netResultBase), lineWidth: 1)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(4)
            }
            VStack(alignment: .center, spacing: 0) {
                Text("\(dayNum)")
                    .font(.system(size: hasSessions ? 12 : 14, weight: hasSessions ? .semibold : .regular))
                    .foregroundColor(isCurrentMonth ? (hasSessions ? .white : grayDim) : grayFiller)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                if isCurrentMonth && hasSessions, let s = stats {
                    Spacer(minLength: 0)
                    Text(formatCalendarAmount(s.netResultBase))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(valueColor(s.netResultBase))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: false, vertical: false)
            .frame(width: cellWidth, height: Self.cellRowHeight)
        }
        .frame(width: cellWidth, height: Self.cellRowHeight)
        .clipped()
        .opacity(isCurrentMonth ? 1 : 0.25)
        .contentShape(Rectangle())
        .onTapGesture {
            if isCurrentMonth && hasSessions, let d = startOfDay {
                selectedDay = d
            }
        }
    }

    private func gradientTop(for value: Double) -> Color {
        if value > 0 { return greenBgTop }
        if value < 0 { return redBgTop }
        return zeroBgTop
    }

    private func backgroundColor(for value: Double) -> Color {
        if value > 0 { return greenBg }
        if value < 0 { return redBg }
        return zeroBg
    }

    private func borderColor(for value: Double) -> Color {
        if value > 0 { return greenBorder }
        if value < 0 { return redBorder }
        return zeroBorder
    }

    private func valueColor(_ value: Double) -> Color {
        if value > 0 { return greenBorder }
        if value < 0 { return redBorder }
        return grayDim
    }

    private func recomputeDayStats() {
        var result: [Date: DayStats] = [:]
        for s in onlineSessions {
            guard let start = s.startTime else { continue }
            let day = cal.startOfDay(for: start)
            var stats = result[day] ?? DayStats()
            stats.netResultBase += s.netProfitLossBase
            stats.durationHours += s.computedDuration
            stats.handsCount += Int(s.effectiveHands)
            stats.sessions.append(.online(s))
            result[day] = stats
        }
        for s in liveSessions {
            guard let start = s.startTime else { continue }
            let day = cal.startOfDay(for: start)
            var stats = result[day] ?? DayStats()
            stats.netResultBase += s.netResultBase
            stats.durationHours += s.computedDuration
            stats.handsCount += Int(s.effectiveHands)
            stats.sessions.append(.live(s))
            result[day] = stats
        }
        dayStats = result
    }

    func performRefresh() async {
        viewContext.refreshAllObjects()
        recomputeDayStats()
        refreshID = UUID()
    }

    private struct SelectedDayWrapper: Identifiable {
        let id: Date
        var date: Date { id }
    }

    private var selectedDayBinding: Binding<SelectedDayWrapper?> {
        Binding(
            get: { selectedDay.map { SelectedDayWrapper(id: $0) } },
            set: { selectedDay = $0?.id }
        )
    }

    private func dayDetailSheet(for day: SelectedDayWrapper) -> some View {
        let date = day.date
        let stats = dayStats[date] ?? DayStats()
        let sessions = stats.sessions

        return NavigationStack {
            ZStack {
                bgBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Capsule()
                            .fill(Color(hex: "#3A3A3A"))
                            .frame(width: 36, height: 4)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                            .padding(.bottom, 4)

                        Text(dayDetailHeaderString(date))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Net Result")
                                        .font(.caption)
                                        .foregroundColor(grayDim)
                                    Text(fullPrecisionSigned(stats.netResultBase))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(valueColor(stats.netResultBase))
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Sessions")
                                        .font(.caption)
                                        .foregroundColor(grayDim)
                                    Text("\(stats.sessionCount)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            HStack(alignment: .top, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Hours Played")
                                        .font(.caption)
                                        .foregroundColor(grayDim)
                                    Text(AppFormatter.duration(stats.durationHours))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Hands Played")
                                        .font(.caption)
                                        .foregroundColor(grayDim)
                                    Text(stats.handsCount == 0 ? "—" : "\(stats.handsCount)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardBg)
                        .cornerRadius(12)

                        if sessions.count > 1 {
                            Text("Sessions")
                                .font(.headline)
                                .foregroundColor(goldColor)
                            VStack(spacing: 8) {
                                ForEach(sessions) { item in
                                    sessionRow(item: item)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func dayDetailHeaderString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: date)
    }

    private func fullPrecisionSigned(_ value: Double) -> String {
        AppFormatter.currencySigned(value, code: baseCurrency)
    }

    @ViewBuilder
    private func sessionRow(item: CalendarSessionItem) -> some View {
        switch item {
        case .online(let s):
            NavigationLink {
                OnlineSessionDetailView(session: s)
            } label: {
                sessionRowLabel(item: item)
            }
            .buttonStyle(.plain)
        case .live(let s):
            NavigationLink {
                LiveSessionDetailView(session: s)
            } label: {
                sessionRowLabel(item: item)
            }
            .buttonStyle(.plain)
        }
    }

    private func sessionRowLabel(item: CalendarSessionItem) -> some View {
        HStack {
            Image(systemName: item.isLive ? "building.columns" : "desktopcomputer")
                .foregroundColor(goldColor)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.gameTypeBlinds)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text(AppFormatter.duration(item.computedDuration))
                    .font(.caption)
                    .foregroundColor(grayDim)
            }
            Spacer()
            Text(AppFormatter.currencySigned(item.netProfitLossBase, code: item.currencyCode))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor(item.netProfitLossBase))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#1A1A1A"))
        .cornerRadius(10)
    }
}

#Preview {
    NavigationStack {
        CalendarView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
    .preferredColorScheme(.dark)
}
