import SwiftUI
import CoreData

struct PlatformDetailView: View {
    @ObservedObject var platform: Platform
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @EnvironmentObject var coordinator: ActiveSessionCoordinator

    @State private var showDeposit = false
    @State private var showWithdrawal = false
    @State private var showAdjustment = false
    @State private var showDeleteAlert = false
    @State private var showWithdrawalDetail: Withdrawal? = nil
    @State private var refreshID = UUID()
    @Environment(\.dismiss) private var dismiss

    var hasAnyRecords: Bool {
        !platform.depositsArray.isEmpty ||
        !platform.withdrawalsArray.isEmpty ||
        !platform.onlineSessionsArray.isEmpty ||
        !platform.adjustmentsArray.isEmpty
    }

    func performRefresh() async {
        viewContext.refreshAllObjects()
        refreshID = UUID()
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    balanceCard
                    actionButtons
                    sessionsSection
                    depositsSection
                    withdrawalsSection
                    adjustmentsSection
                    dangerZone
                }
                .padding()
            }
            .refreshable {
                await performRefresh()
            }
        }
        .id(refreshID)
        .navigationTitle(platform.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDeposit) {
            DepositFormView(platform: platform)
        }
        .sheet(isPresented: $showWithdrawal) {
            WithdrawalFormView(platform: platform)
        }
        .sheet(isPresented: $showAdjustment) {
            AddAdjustmentView(initialPlatform: platform)
                .environmentObject(coordinator)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("sessionVerified"))) { _ in
            viewContext.refreshAllObjects()
            refreshID = UUID()
        }
        .alert("Delete Platform?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                viewContext.delete(platform)
                try? viewContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this platform. This cannot be undone.")
        }
    }

    // MARK: - Balance Card

    var balanceCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net Result")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    Text(AppFormatter.currencySigned(platform.netResult, code: baseCurrency))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(platform.netResult.profitColor)
                    if platform.pendingWithdrawalsCount > 0 {
                        Text("Includes estimate for \(platform.pendingWithdrawalsCount) pending withdrawal(s)")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#FF9500"))
                    }
                    if platform.displayCurrency != baseCurrency {
                        Text(AppFormatter.currencySigned(platform.netResultInPlatformCurrency, code: platform.displayCurrency))
                            .font(.caption)
                            .foregroundColor(platform.netResultInPlatformCurrency.profitColor)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Current Balance")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    Text(AppFormatter.currency(platform.currentBalance, code: platform.displayCurrency))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.appPrimary)
                }
            }

            Divider().background(Color.appBorder)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Deposited")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    Text(AppFormatter.currency(platform.totalDeposited, code: baseCurrency))
                        .font(.subheadline)
                        .foregroundColor(.appPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Withdrawn")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    Text(AppFormatter.currency(platform.totalWithdrawn, code: baseCurrency))
                        .font(.subheadline)
                        .foregroundColor(.appPrimary)
                }
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(8)
    }

    // MARK: - Action Buttons

    var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showDeposit = true
            } label: {
                Label("Deposit", systemImage: "arrow.down.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "#F44336"))
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.appSurface)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#F44336").opacity(0.4), lineWidth: 1))
            }
            Button {
                showWithdrawal = true
            } label: {
                Label("Withdraw", systemImage: "arrow.up.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "#4CAF50"))
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.appSurface)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#4CAF50").opacity(0.4), lineWidth: 1))
            }
            Button {
                showAdjustment = true
            } label: {
                Label("Adjust", systemImage: "plusminus.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appGold)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.appSurface)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appGold.opacity(0.4), lineWidth: 1))
            }
        }
    }

    // MARK: - Sessions Section

    var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sessions")
                    .font(.headline)
                    .foregroundColor(.appGold)
                Spacer()
                Text("\(platform.onlineSessionsArray.count)")
                    .font(.caption)
                    .foregroundColor(.appSecondary)
            }

            if platform.onlineSessionsArray.isEmpty {
                Text("No sessions recorded for this platform.")
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.appSurface)
                    .cornerRadius(8)
            } else {
                ForEach(platform.onlineSessionsArray.prefix(5)) { session in
                    NavigationLink {
                        OnlineSessionDetailView(session: session)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(AppFormatter.shortDate(session.sessionDate))
                                    .font(.caption)
                                    .foregroundColor(.appSecondary)
                                Text(session.displayBlinds.isEmpty ? session.displayGameType : "\(session.displayGameType) \(session.displayBlinds)")
                                    .font(.subheadline)
                                    .foregroundColor(.appPrimary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(AppFormatter.currencySigned(session.netProfitLoss, code: platform.displayCurrency))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(session.netProfitLoss.profitColor)
                                Text(AppFormatter.duration(session.computedDuration))
                                    .font(.caption)
                                    .foregroundColor(.appSecondary)
                            }
                        }
                        .padding()
                        .background(Color.appSurface)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - Deposits Section (no delete)

    var depositsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Deposits")
                .font(.headline)
                .foregroundColor(.appGold)

            if platform.depositsArray.isEmpty {
                Text("No deposits recorded.")
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.appSurface)
                    .cornerRadius(8)
            } else {
                ForEach(platform.depositsArray.reversed()) { deposit in
                    DepositRowView(deposit: deposit, platformCurrency: platform.displayCurrency, baseCurrency: baseCurrency)
                }
            }
        }
    }

    // MARK: - Withdrawals Section (no delete)

    var withdrawalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Withdrawals")
                .font(.headline)
                .foregroundColor(.appGold)

            if platform.withdrawalsArray.isEmpty {
                Text("No withdrawals recorded.")
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.appSurface)
                    .cornerRadius(8)
            } else {
                ForEach(platform.withdrawalsArray.reversed()) { withdrawal in
                    Button {
                        if withdrawal.isPending {
                            showWithdrawalDetail = withdrawal
                        }
                    } label: {
                        WithdrawalRowView(withdrawal: withdrawal, platformCurrency: platform.displayCurrency, baseCurrency: baseCurrency)
                    }
                    .buttonStyle(.plain)
                    .disabled(!withdrawal.isPending)
                }
            }
        }
        .sheet(item: $showWithdrawalDetail) { w in
            WithdrawalDetailSheet(withdrawal: w, baseCurrency: baseCurrency)
                .environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: - Adjustments Section

    var adjustmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Adjustments")
                    .font(.headline)
                    .foregroundColor(.appGold)
                Spacer()
                let total = platform.totalAdjustments
                if total != 0 {
                    Text(AppFormatter.currencySigned(total, code: baseCurrency))
                        .font(.caption)
                        .foregroundColor(total.profitColor)
                }
            }

            if platform.adjustmentsArray.isEmpty {
                Text("No adjustments recorded.")
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.appSurface)
                    .cornerRadius(8)
            } else {
                ForEach(platform.adjustmentsArray.sorted(by: { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) })) { adj in
                    NavigationLink {
                        AdjustmentDetailView(adjustment: adj)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(adj.name ?? "Adjustment")
                                    .font(.subheadline)
                                    .foregroundColor(.appPrimary)
                                Text(AppFormatter.shortDate(adj.date ?? Date()))
                                    .font(.caption)
                                    .foregroundColor(.appSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(AppFormatter.currencySigned(adj.amountBase, code: baseCurrency))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(adj.amountBase.profitColor)
                                if let currency = adj.currency, currency != baseCurrency {
                                    Text(AppFormatter.currencySigned(adj.amount, code: currency))
                                        .font(.caption)
                                        .foregroundColor(.appSecondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.appSurface)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - Danger Zone

    var dangerZone: some View {
        Group {
            if hasAnyRecords {
                Text("Cannot delete platform with existing records")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#8A8A8A"))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appSurface)
                    .cornerRadius(8)
            } else {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Text("Delete Platform")
                        .font(.subheadline)
                        .foregroundColor(.appLoss)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appSurface)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appLoss.opacity(0.3), lineWidth: 1))
                }
            }
        }
    }
}

struct DepositRowView: View {
    let deposit: Deposit
    let platformCurrency: String
    let baseCurrency: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.appProfit)
                        .font(.caption)
                    Text(AppFormatter.shortDate(deposit.date ?? Date()))
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    Text("·")
                        .foregroundColor(.appSecondary)
                    Text(deposit.method ?? "—")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
                Text(deposit.isForeignExchange ? "FX Transfer" : "Direct Deposit")
                    .font(.caption2)
                    .foregroundColor(.appSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(AppFormatter.currencySigned(deposit.amountReceived, code: platformCurrency))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appProfit)
                Text(AppFormatter.currencySigned(-deposit.amountSent, code: baseCurrency))
                    .font(.caption)
                    .foregroundColor(.appLoss)
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(8)
    }
}

struct WithdrawalRowView: View {
    let withdrawal: Withdrawal
    let platformCurrency: String
    let baseCurrency: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.appLoss)
                        .font(.caption)
                    Text(AppFormatter.shortDate(withdrawal.date ?? Date()))
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    Text("·")
                        .foregroundColor(.appSecondary)
                    Text(withdrawal.method ?? "—")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                    if withdrawal.isPending {
                        Text("PENDING")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "#FF9500"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#2A1500"))
                            .cornerRadius(6)
                    }
                }
                Text(withdrawal.isForeignExchange ? "FX Withdrawal" : "Direct Withdrawal")
                    .font(.caption2)
                    .foregroundColor(.appSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if withdrawal.isPending {
                    Text(AppFormatter.currencySigned(-withdrawal.amountRequested, code: platformCurrency))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.appLoss)
                } else {
                    Text(AppFormatter.currencySigned(withdrawal.amountReceived, code: baseCurrency))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.appProfit)
                    Text(AppFormatter.currencySigned(-withdrawal.amountRequested, code: platformCurrency))
                        .font(.caption)
                        .foregroundColor(.appLoss)
                }
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(8)
    }
}

// MARK: - Withdrawal Detail (Mark as Received)

struct WithdrawalDetailSheet: View {
    let withdrawal: Withdrawal
    let baseCurrency: String
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var amountReceived = ""
    @State private var settlementDate = Date()
    @State private var showSettleForm = false

    var platformCurrency: String { withdrawal.platform?.displayCurrency ?? "USD" }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Requested")
                                .font(.caption)
                                .foregroundColor(.appSecondary)
                            Text(AppFormatter.currency(withdrawal.amountRequested, code: platformCurrency))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.appPrimary)
                            Text(AppFormatter.shortDate(withdrawal.date ?? Date()))
                                .font(.caption)
                                .foregroundColor(.appSecondary)
                            Text(withdrawal.method ?? "—")
                                .font(.caption)
                                .foregroundColor(.appSecondary)
                            if let n = withdrawal.notes, !n.isEmpty {
                                Text(n)
                                    .font(.caption)
                                    .foregroundColor(.appSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.appSurface)
                        .cornerRadius(12)

                        Button {
                            showSettleForm = true
                        } label: {
                            Text("Mark as Received")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.appGold)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Pending Withdrawal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.appSecondary)
                }
            }
            .sheet(isPresented: $showSettleForm) {
                MarkAsReceivedSheet(
                    withdrawal: withdrawal,
                    baseCurrency: baseCurrency,
                    amountReceived: $amountReceived,
                    settlementDate: $settlementDate,
                    onConfirm: {
                        performSettle()
                        showSettleForm = false
                        dismiss()
                    }
                )
                .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    func performSettle() {
        let received = Double(amountReceived) ?? 0
        withdrawal.isPending = false
        withdrawal.amountReceived = received
        withdrawal.settlementDate = settlementDate
        do {
            try viewContext.save()
        } catch {
            print("Settle withdrawal error: \(error)")
        }
    }
}

struct MarkAsReceivedSheet: View {
    let withdrawal: Withdrawal
    let baseCurrency: String
    @Binding var amountReceived: String
    @Binding var settlementDate: Date
    let onConfirm: () -> Void
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    var isValid: Bool { (Double(amountReceived) ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Form {
                    Section {
                        HStack {
                            Text("Amount Received (\(baseCurrency))")
                                .foregroundColor(.appPrimary)
                            Spacer()
                            CurrencyInputField(text: $amountReceived, width: 120)
                        }
                        .listRowBackground(Color.appSurface)

                        DatePicker("Settlement Date", selection: $settlementDate, displayedComponents: .date)
                            .foregroundColor(.appPrimary)
                            .tint(.appGold)
                            .listRowBackground(Color.appSurface)
                    } header: {
                        Text("Settlement").foregroundColor(.appGold).textCase(nil)
                    }

                    Section {
                        Button {
                            onConfirm()
                        } label: {
                            Text("Confirm")
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
            .navigationTitle("Mark as Received")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.appSecondary)
                }
            }
        }
    }
}
