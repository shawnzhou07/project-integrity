import SwiftUI
import CoreData

struct WithdrawalFormView: View {
    let platform: Platform
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @State private var amountRequested = ""
    @State private var dateRequested = Date()
    @State private var method = "E-Transfer"
    @State private var notes = ""
    @State private var alreadyReceived = false
    @State private var amountReceived = ""
    @State private var settlementDate = Date()

    @State private var showNegativeBalanceAlert = false
    @State private var showPendingConfirmation = false
    @State private var showSettledConfirmation = false
    @State private var savedAmount: Double = 0
    @State private var savedCurrency: String = ""

    var isValid: Bool {
        let requested = Double(amountRequested) ?? 0
        guard requested > 0 else { return false }
        if alreadyReceived {
            return (Double(amountReceived) ?? 0) > 0
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Form {
                    Section {
                        HStack {
                            Text("Amount Requested (\(platform.displayCurrency))")
                                .foregroundColor(.appPrimary)
                            Spacer()
                            CurrencyInputField(text: $amountRequested, width: 120)
                        }
                        .listRowBackground(Color.appSurface)

                        DatePicker("Date Requested", selection: $dateRequested, displayedComponents: .date)
                            .foregroundColor(.appPrimary)
                            .tint(.appGold)
                            .listRowBackground(Color.appSurface)

                        Picker("Method", selection: $method) {
                            ForEach(withdrawalMethods, id: \.self) { Text($0) }
                        }
                        .foregroundColor(.appPrimary)
                        .tint(.appGold)
                        .listRowBackground(Color.appSurface)

                        Toggle(isOn: $alreadyReceived) {
                            Text("Already Received")
                                .foregroundColor(.appPrimary)
                        }
                        .tint(.appGold)
                        .listRowBackground(Color.appSurface)

                        if alreadyReceived {
                            HStack {
                                Text("Amount Received (\(baseCurrency))")
                                    .foregroundColor(.appPrimary)
                                Spacer()
                                CurrencyInputField(text: $amountReceived, width: 120)
                            }
                            .listRowBackground(Color.appSurface)
                            .transition(.opacity.combined(with: .move(edge: .top)))

                            DatePicker("Settlement Date", selection: $settlementDate, displayedComponents: .date)
                                .foregroundColor(.appPrimary)
                                .tint(.appGold)
                                .listRowBackground(Color.appSurface)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        TextField("Notes (optional)", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .foregroundColor(.appPrimary)
                            .listRowBackground(Color.appSurface)
                    } header: {
                        Text("Withdrawal").foregroundColor(.appGold).textCase(nil)
                    }
                    .animation(.easeInOut(duration: 0.25), value: alreadyReceived)

                    Section {
                        Button {
                            let requested = Double(amountRequested) ?? 0
                            if requested > 0 && platform.currentBalance - requested < 0 {
                                showNegativeBalanceAlert = true
                            } else {
                                performSave()
                            }
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
        .alert("Insufficient Balance", isPresented: $showNegativeBalanceAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            let requested = Double(amountRequested) ?? 0
            Text("This withdrawal of \(AppFormatter.currency(requested, code: platform.displayCurrency)) exceeds the current platform balance of \(AppFormatter.currency(platform.currentBalance, code: platform.displayCurrency)).")
        }
        .alert("Withdrawal Recorded", isPresented: $showPendingConfirmation) {
            Button("OK") { dismiss() }
        } message: {
            Text("Withdrawal of \(AppFormatter.currency(savedAmount, code: savedCurrency)) recorded as pending. Mark it as received when funds arrive.")
        }
        .alert("Withdrawal Recorded", isPresented: $showSettledConfirmation) {
            Button("OK") { dismiss() }
        } message: {
            Text("Withdrawal recorded as received.")
        }
    }

    func performSave() {
        let requested = Double(amountRequested) ?? 0
        guard requested > 0 else { return }

        let withdrawal = Withdrawal(context: viewContext)
        withdrawal.id = UUID()
        withdrawal.date = dateRequested
        withdrawal.amountRequested = requested
        withdrawal.method = method
        withdrawal.notes = notes.isEmpty ? nil : notes
        withdrawal.isForeignExchange = false
        withdrawal.effectiveExchangeRate = 0
        withdrawal.processingFee = 0
        withdrawal.platform = platform

        if alreadyReceived {
            let received = Double(amountReceived) ?? 0
            withdrawal.amountReceived = received
            withdrawal.settlementDate = settlementDate
            withdrawal.isPending = false
        } else {
            withdrawal.amountReceived = 0
            withdrawal.settlementDate = nil
            withdrawal.isPending = true
        }

        do {
            try viewContext.save()
            savedAmount = requested
            savedCurrency = platform.displayCurrency
            if alreadyReceived {
                showSettledConfirmation = true
            } else {
                showPendingConfirmation = true
            }
        } catch {
            print("Save withdrawal error: \(error)")
        }
    }
}
