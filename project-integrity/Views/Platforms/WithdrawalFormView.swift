// 📖 Refer to UI_MASTER.md, ARCHITECTURE.md, and BUSINESS_RULES.md before making UI or logic changes.
// 📝 Update relevant .md docs after making changes (except CHANGELOG.md which updates per build). See README.md Documentation Maintenance section.
import SwiftUI
import CoreData
import Combine

struct WithdrawalFormView: View {
    let platform: Platform
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"
    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "isVerified == NO AND endTime != nil")
    ) private var unverifiedOnlineSessions: FetchedResults<OnlineCash>
    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "isVerified == NO AND endTime != nil")
    ) private var unverifiedLiveSessions: FetchedResults<LiveCash>
    @AppStorage("exchangeRateInputMode") private var exchangeRateInputMode = "direct"
    @AppStorage("defaultRateUSDToBase") private var defaultRateUSDToBase = 1.36
    @AppStorage("defaultRateEURToBase") private var defaultRateEURToBase = 1.47

    @State private var amountRequested = ""
    @State private var date = Date()
    @State private var method = "E-Transfer"
    @State private var notes = ""
    @State private var showConfirmation = false
    @State private var showUnverifiedSessionAlert = false

    @State private var alreadyReceived = false
    @State private var isForeignExchange = false
    @State private var amountReceivedText = ""
    @State private var effectiveRateStr = ""
    @State private var receivedDate = Date()

    var isSameCurrency: Bool { platform.displayCurrency == baseCurrency }
    var hasUnverifiedSession: Bool {
        !unverifiedOnlineSessions.isEmpty || !unverifiedLiveSessions.isEmpty
    }

    var defaultRate: Double {
        switch platform.displayCurrency {
        case "USD": return defaultRateUSDToBase
        case "EUR": return defaultRateEURToBase
        default: return 1.0
        }
    }

    // Mode A: base amount = requested × rate
    var computedBaseModeA: Double {
        let req = Double(amountRequested) ?? 0
        let rate = Double(effectiveRateStr) ?? 0
        guard req > 0, rate > 0 else { return 0 }
        return req * rate
    }

    // Mode B: rate = base / requested
    var computedRateModeB: Double {
        let req = Double(amountRequested) ?? 0
        let base = Double(amountReceivedText) ?? 0
        guard req > 0, base > 0 else { return 0 }
        return base / req
    }

    var finalEffectiveRate: Double {
        guard alreadyReceived && isForeignExchange && !isSameCurrency else { return 1.0 }
        if exchangeRateInputMode == "direct" {
            return Double(effectiveRateStr) ?? 1.0
        } else {
            return computedRateModeB > 0 ? computedRateModeB : 1.0
        }
    }

    // Base currency amount to store as amountReceived
    var finalAmountReceived: Double {
        guard alreadyReceived else { return 0 }
        if isForeignExchange && !isSameCurrency {
            if exchangeRateInputMode == "direct" {
                return computedBaseModeA
            } else {
                return Double(amountReceivedText) ?? 0
            }
        }
        return Double(amountReceivedText) ?? 0
    }

    // Processing fee: requested minus received (platform currency), FX-OFF only
    var processingFeeDisplay: String {
        guard alreadyReceived, !isForeignExchange || isSameCurrency else { return "—" }
        let req = Double(amountRequested) ?? 0
        let rec = Double(amountReceivedText) ?? 0
        guard req > 0, rec > 0 else { return "—" }
        let fee = req - rec
        return String(format: "%.2f", fee)
    }

    // Formatted string for the read-only Effective Rate display row
    var effectiveRateDisplayValue: String {
        if exchangeRateInputMode == "direct" {
            let rate = Double(effectiveRateStr) ?? 0
            return rate > 0 ? String(format: "%.4f", rate) : "—"
        } else {
            return computedRateModeB > 0 ? String(format: "%.4f", computedRateModeB) : "—"
        }
    }

    var isValid: Bool {
        guard (Double(amountRequested) ?? 0) > 0 else { return false }
        guard alreadyReceived else { return true }
        if isForeignExchange && !isSameCurrency {
            if exchangeRateInputMode == "direct" {
                return (Double(effectiveRateStr) ?? 0) > 0
            } else {
                return (Double(amountReceivedText) ?? 0) > 0
            }
        }
        return (Double(amountReceivedText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Form {
                    amountsSection
                    detailsSection
                    saveSection
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
            }
            .navigationTitle("Record Withdrawal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.appSecondary)
                }
            }
        }
        .onAppear {
            isForeignExchange = !isSameCurrency
            if !isSameCurrency {
                effectiveRateStr = String(format: "%.4f", defaultRate)
            }
        }
        .alert("Withdrawal Recorded", isPresented: $showConfirmation) {
            Button("OK") { dismiss() }
        } message: {
            let requested = Double(amountRequested) ?? 0
            let statusText = alreadyReceived ? "received" : "pending"
            Text("Withdrawal of \(AppFormatter.currency(requested, code: platform.displayCurrency)) recorded as \(statusText).")
        }
        .alert("Unverified Session", isPresented: $showUnverifiedSessionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You have an unverified session. Please verify your previous session before recording a withdrawal.")
        }
    }

    var amountsSection: some View {
        Section {
            // Amount Requested — always visible
            HStack {
                Text("Amount Requested (\(platform.displayCurrency))").foregroundColor(.appPrimary)
                Spacer()
                CurrencyInputField(text: $amountRequested, width: 120)
            }
            .listRowBackground(Color.appSurface)

            Toggle(isOn: $alreadyReceived.animation(.easeInOut)) {
                Text("Already Received").foregroundColor(.appPrimary)
            }
            .tint(.appGold)
            .listRowBackground(Color.appSurface)

            if alreadyReceived {
                if !isSameCurrency {
                    Toggle(isOn: $isForeignExchange.animation(.easeInOut)) {
                        Text("Foreign Exchange").foregroundColor(.appPrimary)
                    }
                    .tint(.appGold)
                    .listRowBackground(Color.appSurface)
                }

                if isForeignExchange && !isSameCurrency {
                    if exchangeRateInputMode == "direct" {
                        // Mode A: user enters rate
                        HStack {
                            Text("Cash-Out Rate").foregroundColor(.appPrimary)
                            Spacer()
                            CurrencyInputField(text: $effectiveRateStr, width: 90, maxDecimalPlaces: 4, textColor: .appGold)
                            Text("\(baseCurrency)/\(platform.displayCurrency)")
                                .font(.caption).foregroundColor(.appSecondary)
                        }
                        .listRowBackground(Color.appSurface)

                        HStack {
                            Text("Amount Received (\(baseCurrency))").foregroundColor(.appSecondary)
                            Spacer()
                            Text(computedBaseModeA > 0
                                 ? AppFormatter.currency(computedBaseModeA, code: baseCurrency)
                                 : "—")
                                .foregroundColor(.appNeutral)
                        }
                        .listRowBackground(Color.appSurface)
                    } else {
                        // Mode B: user enters base amount
                        HStack {
                            Text("Amount Received (\(baseCurrency))").foregroundColor(.appPrimary)
                            Spacer()
                            CurrencyInputField(text: $amountReceivedText, width: 120)
                        }
                        .listRowBackground(Color.appSurface)
                    }
                } else {
                    // FX OFF or same currency: platform currency amount
                    HStack {
                        Text("Amount Received (\(platform.displayCurrency))").foregroundColor(.appPrimary)
                        Spacer()
                        CurrencyInputField(text: $amountReceivedText, width: 120)
                    }
                    .listRowBackground(Color.appSurface)
                }

                // Shared row: Effective Rate (FX ON) or Processing Fee (FX OFF) — same slot, no layout shift
                HStack {
                    Text(isForeignExchange && !isSameCurrency
                         ? "Effective Rate (\(baseCurrency)/\(platform.displayCurrency))"
                         : "Processing Fee (\(platform.displayCurrency))")
                        .foregroundColor(.appSecondary)
                    Spacer()
                    Text(isForeignExchange && !isSameCurrency
                         ? effectiveRateDisplayValue
                         : processingFeeDisplay)
                        .foregroundColor(.appNeutral)
                }
                .listRowBackground(Color.appSurface)
            }
        } header: {
            Text("Amounts").foregroundColor(.appGold).textCase(nil)
        }
    }

    var detailsSection: some View {
        Section {
            Picker("Method", selection: $method) {
                ForEach(withdrawalMethods, id: \.self) { Text($0) }
            }
            .foregroundColor(.appPrimary)
            .tint(.appGold)
            .listRowBackground(Color.appSurface)

            DatePicker("Date Requested", selection: $date, displayedComponents: .date)
                .foregroundColor(.appPrimary)
                .tint(.appGold)
                .listRowBackground(Color.appSurface)

            if alreadyReceived {
                DatePicker("Date Received", selection: $receivedDate, displayedComponents: .date)
                    .foregroundColor(.appPrimary)
                    .tint(.appGold)
                    .listRowBackground(Color.appSurface)
            }

            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .foregroundColor(.appPrimary)
                .listRowBackground(Color.appSurface)
        } header: {
            Text("Details").foregroundColor(.appGold).textCase(nil)
        }
    }

    var saveSection: some View {
        Section {
            Button {
                guard !hasUnverifiedSession else {
                    showUnverifiedSessionAlert = true
                    return
                }
                performSave()
            } label: {
                Text("Save Withdrawal")
                    .font(.headline)
                    .foregroundColor(isValid ? .black : .appSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .disabled(!isValid)
            .listRowBackground(isValid ? Color.appGold : Color.appSurface2)
        }
    }

    func performSave() {
        let requested = Double(amountRequested) ?? 0
        guard requested > 0 else { return }

        let withdrawal = Withdrawal(context: viewContext)
        withdrawal.id = UUID()
        withdrawal.date = date
        withdrawal.amountRequested = requested
        withdrawal.method = method
        withdrawal.notes = notes.isEmpty ? nil : notes
        withdrawal.platform = platform
        withdrawal.processingFee = 0
        withdrawal.isForeignExchange = alreadyReceived && isForeignExchange && !isSameCurrency
        withdrawal.effectiveExchangeRate = finalEffectiveRate

        if alreadyReceived {
            withdrawal.withdrawalStatus = "received"
            withdrawal.amountReceived = finalAmountReceived
            withdrawal.receivedDate = receivedDate
        } else {
            withdrawal.withdrawalStatus = "pending"
            withdrawal.amountReceived = 0
            withdrawal.receivedDate = nil
        }

        print("DEBUG: withdrawal.platform set correctly: \(withdrawal.platform == platform)")

        do {
            try viewContext.save()
            viewContext.refresh(platform, mergeChanges: true)
            platform.objectWillChange.send()
            showConfirmation = true
        } catch {
            print("Save withdrawal error: \(error)")
        }
    }
}
