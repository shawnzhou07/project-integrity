import SwiftUI
import CoreData
import Combine
import UIKit

struct LiveSessionDetailView: View {
    @ObservedObject var session: LiveCash
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var coordinator: ActiveSessionCoordinator
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"
    @AppStorage("exchangeRateInputMode") private var exchangeRateInputMode = "direct"

    @State private var showDeleteAlert = false
    @State private var showVerifyAlert = false
    @State private var showTimeAlert = false
    @State private var showZeroDurationAlert = false
    @Environment(\.dismiss) private var dismiss

    @State private var location = ""
    @State private var currency = "CAD"
    // Dual exchange rates
    @State private var exchangeRateBuyInStr = ""
    @State private var exchangeRateCashOutStr = ""
    // Mode B: amounts in base currency for each rate
    @State private var buyInBaseStr = ""
    @State private var cashOutBaseStr = ""
    @State private var gameType = "No Limit Hold'em"
    @State private var smallBlind = ""
    @State private var bigBlind = ""
    @State private var straddle = ""
    @State private var ante = ""
    @State private var breakTimeStr = ""
    @State private var tableSize = 9
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var prevStartTime = Date()
    @State private var prevEndTime = Date()
    @State private var buyIn = ""
    @State private var cashOut = ""
    @State private var tips = ""
    @State private var handsOverride = ""
    @State private var notes = ""
    @State private var loaded = false
    @State private var elapsed: TimeInterval = 0
    // Tracks whether this detail view was opened while the session was active
    @State private var isSessionActive = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var isSameCurrency: Bool { currency == baseCurrency }
    var breakTimeMinutes: Double { Double(breakTimeStr) ?? 0 }
    var duration: Double { max(0, endTime.timeIntervalSince(startTime) / 3600.0 - breakTimeMinutes / 60.0) }
    var sbDouble: Double { Double(smallBlind) ?? 0 }
    var bbDouble: Double { Double(bigBlind) ?? 0 }
    var buyInDouble: Double { Double(buyIn) ?? 0 }
    var cashOutDouble: Double { Double(cashOut) ?? 0 }
    var exchangeRateBuyIn: Double { Double(exchangeRateBuyInStr) ?? 1.0 }
    var exchangeRateCashOut: Double { Double(exchangeRateCashOutStr) ?? 1.0 }

    // Net result excludes tips
    var netPL: Double { cashOutDouble - buyInDouble }
    // Net in base: each leg converted at its own rate (including tips for header)
    var netPLBase: Double { (cashOutDouble * exchangeRateCashOut) - (buyInDouble * exchangeRateBuyIn) }
    var tipsDouble: Double { Double(tips) ?? 0 }
    /// Net for header: cashOut - buyIn - tips in base. Zero if cashOut not yet entered.
    var headerNetBase: Double {
        guard cashOutDouble > 0 || buyInDouble > 0 else { return 0 }
        let outBase = cashOutDouble * (exchangeRateCashOut > 0 ? exchangeRateCashOut : 1.0)
        let inBase = buyInDouble * (exchangeRateBuyIn > 0 ? exchangeRateBuyIn : 1.0)
        let tipsRate = exchangeRateCashOut > 0 ? exchangeRateCashOut : (exchangeRateBuyIn > 0 ? exchangeRateBuyIn : 1.0)
        return outBase - inBase - (tipsDouble * tipsRate)
    }
    var buyInBase: Double { buyInDouble * exchangeRateBuyIn }
    var cashOutBase: Double { cashOutDouble * exchangeRateCashOut }

    var estimatedHands: Int { Int(duration * Double(UserSettings.shared.handsPerHourLive)) }
    var effectiveHands: Int {
        if let override = Int(handsOverride), override > 0 { return override }
        return isSessionActive ? estimatedHands : Int(session.effectiveHands)
    }

    var isVerified: Bool { session.isVerified }

    var canVerify: Bool {
        !location.trimmingCharacters(in: .whitespaces).isEmpty &&
        !gameType.isEmpty &&
        sbDouble > 0 && bbDouble > 0
    }

    // Live duration text (elapsed minus break time) for the active-session duration row
    var activeDurationText: String {
        let breakHours = breakTimeMinutes / 60.0
        let netHours = max(0, elapsed / 3600.0 - breakHours)
        return AppFormatter.duration(netHours)
    }

    var body: some View {
        mainContentWithAlerts
    }

    private var mainZStack: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Form {
                    headerSection
                    locationSection
                    gameDetailsSection
                    timingSection
                    financialsSection
                    if !isSameCurrency {
                        exchangeRatesSection
                    }
                    handsSection
                    notesSection
                    if !isVerified {
                        deleteSection
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
                .selectAllOnFocus()

                verifyBar
            }
        }
    }

    private var mainContentWithOnChange: some View {
        mainZStack
            .navigationTitle("Live Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isSessionActive {
                    // Green dot appears directly to the right of the title text.
                    // .principal placement centers the title+dot in the nav bar.
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 0) {
                            Text("Live Session")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Circle()
                                .fill(Color(hex: "#34C759"))
                                .frame(width: 10, height: 10)
                                .padding(.leading, 6)
                        }
                    }
                    // Stop button is a separate trailing item with no dot inside it.
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Stop") { stopSession() }
                            .fontWeight(.semibold)
                            .foregroundColor(.appLoss)
                    }
                }
            }
            .onAppear {
                loadFromSession()
                // Hide the floating bar while viewing the currently active session.
                if session.isActive { coordinator.isViewingActiveSessionDetail = true }
            }
            .onDisappear {
                coordinator.isViewingActiveSessionDetail = false
            }
            .onChange(of: location) { _, _ in autoSave() }
            .onChange(of: currency) { _, _ in autoSave() }
            .onChange(of: exchangeRateBuyInStr) { _, _ in autoSave() }
            .onChange(of: exchangeRateCashOutStr) { _, _ in autoSave() }
            .onChange(of: buyInBaseStr) { _, _ in recalcRateFromAmounts(forBuyIn: true); autoSave() }
            .onChange(of: cashOutBaseStr) { _, _ in recalcRateFromAmounts(forBuyIn: false); autoSave() }
            .onChange(of: gameType) { _, _ in autoSave() }
            .onChange(of: smallBlind) { _, _ in autoSave() }
            .onChange(of: bigBlind) { _, _ in autoSave() }
            .onChange(of: straddle) { _, _ in autoSave() }
    }

    private var mainContentWithMoreOnChange: some View {
        mainContentWithOnChange
            .onChange(of: ante) { _, _ in autoSave() }
            .onChange(of: breakTimeStr) { _, _ in autoSave() }
            .onChange(of: tableSize) { _, _ in autoSave() }
            .onChange(of: startTime) { _, _ in
                if endTime <= startTime {
                    showTimeAlert = true
                    startTime = prevStartTime
                } else {
                    prevStartTime = startTime
                    autoSave()
                }
            }
            .onChange(of: endTime) { _, _ in
                guard !isSessionActive else { return }
                if endTime <= startTime {
                    showTimeAlert = true
                    endTime = prevEndTime
                } else {
                    prevEndTime = endTime
                    autoSave()
                }
            }
            .onChange(of: buyIn) { _, _ in autoSave() }
            .onChange(of: cashOut) { _, _ in autoSave() }
            .onChange(of: tips) { _, _ in autoSave() }
            .onChange(of: handsOverride) { _, _ in autoSave() }
            .onChange(of: notes) { _, _ in autoSave() }
    }

    private var mainContentWithAlerts: some View {
        mainContentWithMoreOnChange
            .alert("Invalid Time Range", isPresented: $showTimeAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Start time must be before end time.")
            }
            .alert("Delete Session?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    viewContext.delete(session)
                    try? viewContext.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .alert("Verify Session?", isPresented: $showVerifyAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Verify") { verifySession() }
                    .foregroundStyle(Color.appGold)
            } message: {
                Text("The following fields will be permanently locked and can never be edited:\n\n• Buy-In\n• Cash-Out\n• Start Time & Date\n• End Time & Date\n\nExchange rates, location, game type, blinds, notes, and hands will remain editable.\n\nThis cannot be undone.")
            }
            .alert("Invalid Session Duration", isPresented: $showZeroDurationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your session duration is zero or negative. Please correct your start time, end time, or break time before saving.")
            }
    }

    // MARK: - Bottom Bar

    var verifyBar: some View {
        Group {
            if isSessionActive {
                // Session is currently running — no verify bar shown
                EmptyView()
            } else if isVerified {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.appGold)
                        .font(.subheadline)
                    Text("Verified")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.appGold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.appBackground)
            } else {
                let isStopped = session.endTime != nil
                let buttonOpacity: Double = !isStopped ? 0.4 : (canVerify ? 1.0 : 0.7)
                let isTappable = isStopped && canVerify
                Button {
                    if isTappable { showVerifyAlert = true }
                } label: {
                    Text("Verify Session")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isTappable ? .black : .appGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isTappable ? Color.appGold : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.appGold, lineWidth: isTappable ? 0 : 1.5)
                        )
                        .cornerRadius(12)
                        .opacity(buttonOpacity)
                }
                .disabled(!isTappable)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.appBackground)
            }
        }
    }

    // MARK: - Header (unified with online: shown from session start)

    var headerSection: some View {
        let hasCashOut = cashOutDouble > 0 || (session.cashOut > 0)
        let showZero = isSessionActive && !hasCashOut
        let netVal = showZero ? 0 : headerNetBase
        let glowColor = headerNetColor(netVal: netVal)
        return Section {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net Result")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#8A8A8A"))
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(showZero ? AppFormatter.currency(0, code: baseCurrency) : AppFormatter.currencySigned(netVal, code: baseCurrency))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(glowColor)
                            .shadow(color: isVerified ? glowColor.opacity(0.6) : .clear, radius: isVerified ? 8 : 0, x: 0, y: 0)
                            .shadow(color: isVerified ? glowColor.opacity(0.3) : .clear, radius: isVerified ? 16 : 0, x: 0, y: 0)
                        if isVerified {
                            Image(systemName: "lock.fill")
                                .font(.title3)
                                .foregroundColor(Color(hex: "#C9B47A"))
                                .shadow(color: Color(hex: "#C9B47A"), radius: 6, x: 0, y: 0)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isVerified ? Color(hex: "#C9B47A").opacity(0.12) : Color.clear)
                            .blur(radius: isVerified ? 14 : 0)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 0) {
                    headerStatColumn(title: "Duration", value: isSessionActive ? activeDurationText : AppFormatter.duration(session.computedDuration))
                    headerStatColumn(title: "Hands", value: effectiveHands == 0 ? "—" : AppFormatter.handsCount(effectiveHands))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowBackground(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#0D0D0D"))
        )
    }

    private func headerNetColor(netVal: Double) -> Color {
        if netVal > 0 { return Color(hex: "#4CAF50") }
        if netVal < 0 { return Color(hex: "#F44336") }
        return Color(hex: "#8A8A8A")
    }

    private func headerStatColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(Color(hex: "#8A8A8A"))
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Location

    var locationSection: some View {
        Section {
            HStack {
                Text("Location").foregroundColor(.appPrimary)
                Spacer()
                TextField("Casino / location", text: $location)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.white)
            }
            .listRowBackground(Color.appSurface)

            if isVerified {
                lockedRow(label: "Currency", value: currency)
            } else {
                Picker("Currency", selection: $currency) {
                    ForEach(supportedCurrencies, id: \.self) { Text($0).tag($0) }
                }
                .foregroundColor(.appPrimary)
                .tint(.appGold)
                .listRowBackground(Color.appSurface)
            }
        } header: {
            Text("Location").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Game Details (always editable)

    var gameDetailsSection: some View {
        Section {
            Picker("Game Type", selection: $gameType) {
                ForEach(gameTypes, id: \.self) { Text($0) }
            }
            .foregroundColor(.appPrimary)
            .listRowBackground(Color.appSurface)

            HStack(spacing: 12) {
                blindField(label: "SB", text: $smallBlind)
                blindField(label: "BB", text: $bigBlind)
                blindField(label: "STR (opt.)", text: $straddle)
                blindField(label: "Ante (opt.)", text: $ante)
            }
            .listRowBackground(Color.appSurface)

            Stepper("Table Size: \(tableSize)", value: $tableSize, in: 2...10)
                .foregroundColor(.appPrimary)
                .listRowBackground(Color.appSurface)
        } header: {
            Text("Game Details").foregroundColor(.appGold).textCase(nil)
        }
    }

    @ViewBuilder
    func blindField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.appSecondary)
            CurrencyInputField(text: text, width: nil, textAlignment: .center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.appSurface2)
                .cornerRadius(6)
        }
    }

    // MARK: - Timing

    private func lockedDateTimeRow(label: String, date: Date) -> some View {
        Button { triggerLockHaptic() } label: {
            HStack {
                Text(label)
                    .foregroundColor(Color(hex: "#8A8A8A"))
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(isVerified ? Color(hex: "#C9B47A") : Color(hex: "#8A8A8A"))
                        .shadow(color: isVerified ? Color(hex: "#C9B47A") : .clear, radius: isVerified ? 6 : 0, x: 0, y: 0)
                    Text("\(AppFormatter.longDate(date)) \(AppFormatter.timeOnly(date))")
                        .foregroundColor(.white)
                        .shadow(color: isVerified ? Color(hex: "#C9B47A") : .clear, radius: isVerified ? 6 : 0, x: 0, y: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isVerified ? Color(hex: "#C9B47A").opacity(0.12) : Color.clear)
                        .blur(radius: isVerified ? 14 : 0)
                )
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.appSurface)
    }

    var timingSection: some View {
        Section {
            if isVerified {
                lockedDateTimeRow(label: "Start Time", date: startTime)
            } else {
                DatePicker("Start", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                    .foregroundColor(.appPrimary).tint(.appGold)
                    .listRowBackground(Color.appSurface)
            }
            if !isSessionActive {
                if isVerified {
                    lockedDateTimeRow(label: "End Time", date: endTime)
                } else {
                    DatePicker("End", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                        .foregroundColor(.appPrimary).tint(.appGold)
                        .listRowBackground(Color.appSurface)
                }
            }
            HStack {
                Text("Break (min)").foregroundColor(.appPrimary)
                Spacer()
                CurrencyInputField(text: $breakTimeStr, width: 80, maxDecimalPlaces: 0)
            }
            .listRowBackground(Color.appSurface)
            HStack {
                Text("Duration").foregroundColor(.appPrimary)
                Spacer()
                if isSessionActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: "#34C759"))
                            .frame(width: 8, height: 8)
                        Text(activeDurationText)
                            .foregroundColor(.appSecondary)
                            .monospacedDigit()
                    }
                    .onReceive(timer) { _ in elapsed += 1 }
                } else {
                    Text(AppFormatter.duration(duration)).foregroundColor(.appSecondary)
                }
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Timing").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Financials

    var financialsSection: some View {
        Section {
            if isVerified {
                lockedRow(label: "Buy In", value: "\(currency) \(String(format: "%.2f", buyInDouble))")
            } else {
                HStack {
                    Text("Buy In").foregroundColor(.appPrimary)
                    Spacer()
                    Text(currency).font(.caption).foregroundColor(.appSecondary)
                    CurrencyInputField(text: $buyIn, width: 100)
                }
                .listRowBackground(Color.appSurface)
            }

            if isVerified {
                lockedRow(label: "Cash Out", value: "\(currency) \(String(format: "%.2f", cashOutDouble))")
            } else {
                HStack {
                    Text("Cash Out").foregroundColor(.appPrimary)
                    Spacer()
                    Text(currency).font(.caption).foregroundColor(.appSecondary)
                    CurrencyInputField(text: $cashOut, width: 100)
                }
                .listRowBackground(Color.appSurface)
            }

            HStack {
                Text("Tips").foregroundColor(.appPrimary)
                Spacer()
                Text(currency).font(.caption).foregroundColor(.appSecondary)
                CurrencyInputField(text: $tips, width: 100)
            }
            .listRowBackground(Color.appSurface)

            HStack {
                Text("Net Result")
                    .foregroundColor(Color(hex: "#8A8A8A"))
                Spacer()
                HStack(spacing: 4) {
                    if isVerified {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#C9B47A"))
                            .shadow(color: Color(hex: "#C9B47A"), radius: 6, x: 0, y: 0)
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        let netToShow = isVerified ? session.netProfitLoss : netPL
                        let netBaseToShow = isVerified ? session.netProfitLossBase : netPLBase
                        Text(AppFormatter.currencySigned(netToShow, code: currency))
                            .fontWeight(.semibold)
                            .foregroundColor(netToShow.profitColor)
                            .shadow(color: isVerified ? Color(hex: "#C9B47A") : .clear, radius: isVerified ? 6 : 0, x: 0, y: 0)
                        if !isSameCurrency {
                            Text(AppFormatter.currencySigned(netBaseToShow, code: baseCurrency))
                                .font(.caption)
                                .foregroundColor(netBaseToShow.profitColor)
                                .shadow(color: isVerified ? Color(hex: "#C9B47A") : .clear, radius: isVerified ? 6 : 0, x: 0, y: 0)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "#C9B47A").opacity(isVerified ? 0.12 : 0))
                        .blur(radius: isVerified ? 14 : 0)
                )
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Financials").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Exchange Rates (only for foreign currency sessions; always editable)

    var exchangeRatesSection: some View {
        Section {
            if exchangeRateInputMode == "direct" {
                HStack {
                    Text("Buy-In Rate").foregroundColor(.appPrimary)
                    Spacer()
                    CurrencyInputField(text: $exchangeRateBuyInStr, width: 90, maxDecimalPlaces: 4)
                    Text("\(currency)/\(baseCurrency)").font(.caption).foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface)

                HStack {
                    Text("Buy-In Cost").font(.caption).foregroundColor(.appSecondary)
                    Spacer()
                    Text(AppFormatter.currency(buyInBase, code: baseCurrency)).font(.caption).foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface)
                .allowsHitTesting(false)

                HStack {
                    Text("Cash-Out Rate").foregroundColor(.appPrimary)
                    Spacer()
                    CurrencyInputField(text: $exchangeRateCashOutStr, width: 90, maxDecimalPlaces: 4)
                    Text("\(currency)/\(baseCurrency)").font(.caption).foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface)

                HStack {
                    Text("Cash-Out Proceeds").font(.caption).foregroundColor(.appSecondary)
                    Spacer()
                    Text(AppFormatter.currency(cashOutBase, code: baseCurrency)).font(.caption).foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface)
                .allowsHitTesting(false)

            } else {
                Text("Buy-In Exchange").font(.caption).foregroundColor(.appGold).listRowBackground(Color.appSurface)

                HStack {
                    Text("Amount (\(currency))").foregroundColor(.appPrimary)
                    Spacer()
                    CurrencyInputField(text: $buyIn, width: 100)
                        .disabled(isVerified)
                }
                .listRowBackground(Color.appSurface)

                HStack {
                    Text("Equivalent (\(baseCurrency))").foregroundColor(.appPrimary)
                    Spacer()
                    CurrencyInputField(text: $buyInBaseStr, width: 100)
                }
                .listRowBackground(Color.appSurface)

                HStack {
                    Text("Rate (calculated)").font(.caption).foregroundColor(.appSecondary)
                    Spacer()
                    Text(String(format: "%.4f", exchangeRateBuyIn)).font(.caption).foregroundColor(.appSecondary)
                    Text("\(currency)/\(baseCurrency)").font(.caption2).foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface).allowsHitTesting(false)

                Text("Cash-Out Exchange").font(.caption).foregroundColor(.appGold).listRowBackground(Color.appSurface)

                HStack {
                    Text("Amount (\(currency))").foregroundColor(.appPrimary)
                    Spacer()
                    CurrencyInputField(text: $cashOut, width: 100)
                        .disabled(isVerified)
                }
                .listRowBackground(Color.appSurface)

                HStack {
                    Text("Equivalent (\(baseCurrency))").foregroundColor(.appPrimary)
                    Spacer()
                    CurrencyInputField(text: $cashOutBaseStr, width: 100)
                }
                .listRowBackground(Color.appSurface)

                HStack {
                    Text("Rate (calculated)").font(.caption).foregroundColor(.appSecondary)
                    Spacer()
                    Text(String(format: "%.4f", exchangeRateCashOut)).font(.caption).foregroundColor(.appSecondary)
                    Text("\(currency)/\(baseCurrency)").font(.caption2).foregroundColor(.appSecondary)
                }
                .listRowBackground(Color.appSurface).allowsHitTesting(false)
            }
        } header: {
            Text("Exchange Rates").foregroundColor(.appGold).textCase(nil)
        } footer: {
            Text("Exchange rates are always editable.").foregroundColor(.appSecondary)
        }
    }

    // MARK: - Hands

    var handsSection: some View {
        Section {
            HStack {
                Text("Hands Played").foregroundColor(.appPrimary)
                Spacer()
                TextField("Auto (\(estimatedHands) est.)", text: $handsOverride)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    .foregroundColor(.white).frame(width: 140)
            }
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Hands").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Notes

    var notesSection: some View {
        Section {
            TextEditor(text: $notes)
                .frame(minHeight: 80).foregroundColor(.appPrimary)
                .scrollContentBackground(.hidden).background(Color.appSurface)
                .listRowBackground(Color.appSurface)
        } header: {
            Text("Notes").foregroundColor(.appGold).textCase(nil)
        }
    }

    // MARK: - Delete

    var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Text("Delete Session").frame(maxWidth: .infinity).foregroundColor(.appLoss)
            }
            .listRowBackground(Color.appSurface)
        }
    }

    // MARK: - Locked Field Row

    @ViewBuilder
    func lockedRow(label: String, value: String) -> some View {
        Button { triggerLockHaptic() } label: {
            HStack {
                Text(label)
                    .foregroundColor(Color(hex: "#8A8A8A"))
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(isVerified ? Color(hex: "#C9B47A") : Color(hex: "#8A8A8A"))
                        .shadow(color: isVerified ? Color(hex: "#C9B47A") : .clear, radius: isVerified ? 6 : 0, x: 0, y: 0)
                    Text(value)
                        .foregroundColor(.white)
                        .shadow(color: isVerified ? Color(hex: "#C9B47A") : .clear, radius: isVerified ? 6 : 0, x: 0, y: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isVerified ? Color(hex: "#C9B47A").opacity(0.12) : Color.clear)
                        .blur(radius: isVerified ? 14 : 0)
                )
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Helpers

    func triggerLockHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }

    func recalcRateFromAmounts(forBuyIn: Bool) {
        if forBuyIn {
            let amt = Double(buyIn) ?? 0
            let base = Double(buyInBaseStr) ?? 0
            if amt > 0 && base > 0 {
                exchangeRateBuyInStr = String(format: "%.4f", base / amt)
            }
        } else {
            let amt = Double(cashOut) ?? 0
            let base = Double(cashOutBaseStr) ?? 0
            if amt > 0 && base > 0 {
                exchangeRateCashOutStr = String(format: "%.4f", base / amt)
            }
        }
    }

    func verifySession() {
        guard duration > 0 else { showZeroDurationAlert = true; return }
        session.isVerified = true
        autoSave()
        NotificationCenter.default.post(name: Notification.Name("sessionVerified"), object: nil)
    }

    /// Stop the active session: record end time and transition to stopped state.
    func stopSession() {
        endTime = Date()
        session.endTime = endTime
        session.breakTime = breakTimeMinutes
        session.duration = max(0, endTime.timeIntervalSince(startTime) / 3600.0 - breakTimeMinutes / 60.0)
        isSessionActive = false
        prevEndTime = endTime
        try? viewContext.save()
    }

    func loadFromSession() {
        guard !loaded else { return }
        loaded = true
        // Capture active state before setting up other fields
        isSessionActive = session.isActive
        location = session.location ?? ""
        currency = session.currency ?? baseCurrency
        gameType = session.gameType ?? "No Limit Hold'em"

        // Load structured blind fields
        if session.smallBlind > 0 || session.bigBlind > 0 {
            smallBlind = AppFormatter.blindValue(session.smallBlind)
            bigBlind = AppFormatter.blindValue(session.bigBlind)
            straddle = session.straddle > 0 ? AppFormatter.blindValue(session.straddle) : ""
            ante = session.ante > 0 ? AppFormatter.blindValue(session.ante) : ""
        } else if let blindsStr = session.blinds, !blindsStr.isEmpty {
            let parts = blindsStr.split(separator: "/")
            if parts.count >= 2 {
                smallBlind = String(parts[0]).trimmingCharacters(in: .whitespaces)
                bigBlind = String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }
        breakTimeStr = session.breakTime > 0 ? String(Int(session.breakTime)) : ""
        tableSize = Int(session.tableSize)
        startTime = session.startTime ?? Date()
        // For active sessions, use a placeholder endTime that is NOT written back to Core Data
        endTime = session.isActive ? Date() : (session.endTime ?? Date())
        prevStartTime = startTime
        prevEndTime = endTime
        buyIn = session.buyIn == 0 ? "" : String(format: "%.2f", session.buyIn)
        cashOut = session.cashOut == 0 ? "" : String(format: "%.2f", session.cashOut)
        tips = session.tips == 0 ? "" : String(format: "%.2f", session.tips)
        handsOverride = session.handsCount > 0 ? "\(session.handsCount)" : ""
        notes = session.notes ?? ""

        if session.exchangeRateCashOut > 0 {
            let rBI = session.exchangeRateBuyIn > 0 ? session.exchangeRateBuyIn : session.exchangeRateCashOut
            exchangeRateBuyInStr = rBI == 1.0 ? "" : String(format: "%.4f", rBI)
            exchangeRateCashOutStr = session.exchangeRateCashOut == 1.0 ? "" : String(format: "%.4f", session.exchangeRateCashOut)
        } else if session.exchangeRateToBase > 0 && session.exchangeRateToBase != 1.0 {
            exchangeRateBuyInStr = String(format: "%.4f", session.exchangeRateToBase)
            exchangeRateCashOutStr = String(format: "%.4f", session.exchangeRateToBase)
        } else {
            let defaultRate = UserSettings.shared.defaultExchangeRate(sessionCurrency: session.currency ?? baseCurrency, baseCurrency: baseCurrency)
            exchangeRateBuyInStr = defaultRate == 1.0 ? "" : String(format: "%.4f", defaultRate)
            exchangeRateCashOutStr = defaultRate == 1.0 ? "" : String(format: "%.4f", defaultRate)
        }

        if exchangeRateInputMode == "amounts" {
            let rateBI = Double(exchangeRateBuyInStr) ?? 1.0
            let rateCO = Double(exchangeRateCashOutStr) ?? 1.0
            if session.buyIn > 0 { buyInBaseStr = String(format: "%.2f", session.buyIn * rateBI) }
            if session.cashOut > 0 { cashOutBaseStr = String(format: "%.2f", session.cashOut * rateCO) }
        }

        if session.isActive, let start = session.startTime {
            elapsed = Date().timeIntervalSince(start)
        }
    }

    func autoSave() {
        guard loaded else { return }
        // Location is always editable (even when verified) so users can correct venue.
        session.location = location
        if !isVerified {
            session.currency = currency
            session.buyIn = Double(buyIn) ?? 0
            session.cashOut = Double(cashOut) ?? 0
        }
        session.exchangeRateBuyIn = exchangeRateBuyIn
        session.exchangeRateCashOut = exchangeRateCashOut
        session.exchangeRateToBase = exchangeRateCashOut

        session.gameType = gameType
        session.smallBlind = sbDouble
        session.bigBlind = bbDouble
        session.straddle = Double(straddle) ?? 0
        session.ante = Double(ante) ?? 0
        session.blinds = "\(AppFormatter.blindValue(sbDouble))/\(AppFormatter.blindValue(bbDouble))"
        session.tableSize = Int16(tableSize)
        session.breakTime = breakTimeMinutes
        if !isVerified {
            session.startTime = startTime
            if !isSessionActive {
                session.endTime = endTime
                session.duration = duration
            }
        }
        session.tips = Double(tips) ?? 0
        session.netProfitLoss = netPL
        session.netProfitLossBase = netPLBase
        session.handsCount = Int32(handsOverride) ?? 0
        session.notes = notes.isEmpty ? nil : notes
        try? viewContext.save()
    }
}
