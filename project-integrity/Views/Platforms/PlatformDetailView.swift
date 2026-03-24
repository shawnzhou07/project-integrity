// Refer to UI_MASTER.md at project root before making UI changes.
import SwiftUI
import CoreData

struct PlatformDetailView: View {
    @ObservedObject var platform: Platform
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @EnvironmentObject var coordinator: ActiveSessionCoordinator
    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "isVerified == NO AND endTime != nil")
    ) private var unverifiedOnlineSessions: FetchedResults<OnlineCash>
    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "isVerified == NO AND endTime != nil")
    ) private var unverifiedLiveSessions: FetchedResults<LiveCash>

    @State private var showDeposit = false
    @State private var showWithdrawal = false
    @State private var showAdjustment = false
    @State private var showDeleteAlert = false
    @State private var selectedDeposit: Deposit? = nil
    @State private var selectedWithdrawal: Withdrawal? = nil
    @State private var showUnverifiedSessionAlert = false
    @Environment(\.dismiss) private var dismiss

    var hasAnyRecords: Bool {
        !platform.depositsArray.isEmpty ||
        !platform.withdrawalsArray.isEmpty ||
        !platform.onlineSessionsArray.isEmpty ||
        !platform.adjustmentsArray.isEmpty
    }
    var hasUnverifiedSession: Bool {
        !unverifiedOnlineSessions.isEmpty || !unverifiedLiveSessions.isEmpty
    }

    func performRefresh() async {
        viewContext.refreshAllObjects()
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
                    WithdrawalsSectionView(platform: platform, baseCurrency: baseCurrency, selectedWithdrawal: $selectedWithdrawal)
                    adjustmentsSection
                    dangerZone
                }
                .padding()
            }
            .refreshable {
                await performRefresh()
            }
        }
        .navigationTitle(platform.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    PlatformSettingsView(platform: platform)
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(.appGold)
                }
            }
        }
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
        .sheet(item: $selectedDeposit) { d in
            DepositDetailSheet(deposit: d)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $selectedWithdrawal) { w in
            WithdrawalDetailSheet(withdrawal: w, baseCurrency: baseCurrency)
                .environment(\.managedObjectContext, viewContext)
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
        .alert("Unverified Session", isPresented: $showUnverifiedSessionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You have an unverified session. Please verify your previous session before recording a deposit or withdrawal.")
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
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    if hasUnverifiedSession {
                        showUnverifiedSessionAlert = true
                    } else {
                        showDeposit = true
                    }
                } label: {
                    actionPill(title: "Deposit", systemImage: "arrow.down.circle.fill", tint: Color(hex: "#F44336"))
                }
                Button {
                    if hasUnverifiedSession {
                        showUnverifiedSessionAlert = true
                    } else {
                        showWithdrawal = true
                    }
                } label: {
                    actionPill(title: "Withdraw", systemImage: "arrow.up.circle.fill", tint: Color(hex: "#4CAF50"))
                }
                Button {
                    showAdjustment = true
                } label: {
                    actionPill(title: "Adjust", systemImage: "plusminus.circle.fill", tint: .appGold)
                }
            }
            NavigationLink {
                OnlinePlatformAnalyticsView(platform: platform)
                    .environment(\.managedObjectContext, viewContext)
            } label: {
                Label("Analytics", systemImage: "chart.bar.xaxis")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appGold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.appSurface)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appGold.opacity(0.4), lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func actionPill(title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.appSurface)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.4), lineWidth: 1))
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
                                Text(session.displayBlinds.isEmpty ? GameTypePreviewDisplay.short(session.gameType) : "\(GameTypePreviewDisplay.short(session.gameType)) \(session.displayBlinds)")
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

    // MARK: - Deposits Section

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
                    Button {
                        selectedDeposit = deposit
                    } label: {
                        DepositRowView(deposit: deposit, platformCurrency: platform.displayCurrency, baseCurrency: baseCurrency)
                    }
                    .buttonStyle(.plain)
                }
            }
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

// MARK: - Withdrawals Section View

private struct WithdrawalsSectionView: View {
    let platform: Platform
    let baseCurrency: String
    @Binding var selectedWithdrawal: Withdrawal?

    @FetchRequest private var withdrawals: FetchedResults<Withdrawal>

    init(platform: Platform, baseCurrency: String, selectedWithdrawal: Binding<Withdrawal?>) {
        self.platform = platform
        self.baseCurrency = baseCurrency
        self._selectedWithdrawal = selectedWithdrawal
        self._withdrawals = FetchRequest<Withdrawal>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Withdrawal.date, ascending: false)],
            predicate: NSPredicate(format: "platform == %@", platform),
            animation: .default
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Withdrawals")
                .font(.headline)
                .foregroundColor(.appGold)

            if withdrawals.isEmpty {
                Text("No withdrawals recorded.")
                    .font(.caption)
                    .foregroundColor(.appSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.appSurface)
                    .cornerRadius(8)
            } else {
                ForEach(withdrawals) { withdrawal in
                    Button {
                        selectedWithdrawal = withdrawal
                    } label: {
                        WithdrawalRowView(withdrawal: withdrawal, platformCurrency: platform.displayCurrency, baseCurrency: baseCurrency)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Deposit Row

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

// MARK: - Withdrawal Row

struct WithdrawalRowView: View {
    let withdrawal: Withdrawal
    let platformCurrency: String
    let baseCurrency: String

    private var isPending: Bool { (withdrawal.withdrawalStatus ?? "received") == "pending" }

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
                }
                Text(withdrawal.isForeignExchange ? "FX Withdrawal" : "Direct Withdrawal")
                    .font(.caption2)
                    .foregroundColor(.appSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if isPending {
                    Text(AppFormatter.currencySigned(-withdrawal.amountRequested, code: platformCurrency))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.appLoss)
                    Text("PENDING")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#FF9500"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#2A1500"))
                        .cornerRadius(6)
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

// MARK: - Deposit Detail Sheet

struct DepositDetailSheet: View {
    @ObservedObject var deposit: Deposit
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"

    @State private var selectedMethod: String = ""
    private var originalMethod: String { deposit.method ?? depositMethods[0] }
    private var methodChanged: Bool { selectedMethod != originalMethod }

    var platformCurrency: String { deposit.platform?.displayCurrency ?? "USD" }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        // Locked: Date
                        lockedRow(label: "Date", value: AppFormatter.shortDate(deposit.date ?? Date()))
                        // Locked: Amount Sent
                        lockedRow(label: "Amount Sent (\(baseCurrency))", value: AppFormatter.currency(deposit.amountSent, code: baseCurrency))
                        // Locked: Amount Received
                        lockedRow(label: "Amount Received (\(platformCurrency))", value: AppFormatter.currency(deposit.amountReceived, code: platformCurrency))
                        // Locked: Type
                        lockedRow(label: "Type", value: deposit.isForeignExchange ? "FX Transfer" : "Direct Deposit")
                        // Locked: Effective Rate (FX only)
                        if deposit.isForeignExchange && deposit.effectiveExchangeRate > 0 {
                            lockedRow(
                                label: "Effective Rate (\(baseCurrency)/\(platformCurrency))",
                                value: String(format: "%.4f", deposit.effectiveExchangeRate)
                            )
                        }

                        // Editable: Method
                        HStack {
                            Text("Method")
                                .font(.subheadline)
                                .foregroundColor(.appSecondary)
                            Spacer()
                            Picker("Method", selection: $selectedMethod) {
                                ForEach(depositMethods, id: \.self) { Text($0) }
                            }
                            .tint(.appGold)
                            .pickerStyle(.menu)
                        }
                        .padding()
                        .background(Color.appSurface)
                        .cornerRadius(8)

                        if methodChanged {
                            Button {
                                deposit.method = selectedMethod
                                try? viewContext.save()
                                viewContext.refreshAllObjects()
                                NotificationCenter.default.post(name: Notification.Name("platformDataChanged"), object: nil)
                                dismiss()
                            } label: {
                                Text("Save")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.appGold)
                                    .cornerRadius(10)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Deposit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.appSecondary)
                }
            }
        }
        .onAppear { selectedMethod = originalMethod }
    }

    @ViewBuilder
    func lockedRow(label: String, value: String) -> some View {
        HStack {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundColor(.appGold)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.appSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.appPrimary)
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(8)
    }
}

// MARK: - Withdrawal Detail Sheet

struct WithdrawalDetailSheet: View {
    @ObservedObject var withdrawal: Withdrawal
    let baseCurrency: String
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMethod: String = ""
    @State private var showMarkReceived = false
    @State private var showRemoveAlert = false

    private var originalMethod: String { withdrawal.method ?? withdrawalMethods[0] }
    private var methodChanged: Bool { selectedMethod != originalMethod }
    private var isPending: Bool { (withdrawal.withdrawalStatus ?? "received") == "pending" }

    var platformCurrency: String { withdrawal.platform?.displayCurrency ?? "USD" }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        // Received badge for non-pending withdrawals
                        if !isPending {
                            HStack {
                                Spacer()
                                Text("Received")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.appProfit)
                                    .cornerRadius(8)
                                Spacer()
                            }
                        }

                        // Locked: Date
                        lockedRow(label: "Date", value: AppFormatter.shortDate(withdrawal.date ?? Date()))
                        // Locked: Amount Requested
                        lockedRow(label: "Amount Requested (\(platformCurrency))", value: AppFormatter.currency(withdrawal.amountRequested, code: platformCurrency))
                        // Locked: Amount Received (received only)
                        if !isPending {
                            lockedRow(label: "Amount Received (\(baseCurrency))", value: AppFormatter.currency(withdrawal.amountReceived, code: baseCurrency))
                            if withdrawal.isForeignExchange && withdrawal.effectiveExchangeRate > 0 {
                                lockedRow(
                                    label: "Effective Rate (\(baseCurrency)/\(platformCurrency))",
                                    value: String(format: "%.4f", withdrawal.effectiveExchangeRate)
                                )
                            }
                            if let rd = withdrawal.receivedDate {
                                lockedRow(label: "Received Date", value: AppFormatter.shortDate(rd))
                            }
                        }
                        // Locked: Notes (if any)
                        if let notes = withdrawal.notes, !notes.isEmpty {
                            lockedRow(label: "Notes", value: notes)
                        }

                        // Editable: Method
                        HStack {
                            Text("Method")
                                .font(.subheadline)
                                .foregroundColor(.appSecondary)
                            Spacer()
                            Picker("Method", selection: $selectedMethod) {
                                ForEach(withdrawalMethods, id: \.self) { Text($0) }
                            }
                            .tint(.appGold)
                            .pickerStyle(.menu)
                        }
                        .padding()
                        .background(Color.appSurface)
                        .cornerRadius(8)

                        if methodChanged {
                            Button {
                                withdrawal.method = selectedMethod
                                try? viewContext.save()
                                viewContext.refreshAllObjects()
                                NotificationCenter.default.post(name: Notification.Name("platformDataChanged"), object: nil)
                                dismiss()
                            } label: {
                                Text("Save")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.appGold)
                                    .cornerRadius(10)
                            }
                            .padding(.top, 4)
                        }

                        // Action buttons for pending withdrawals
                        if isPending {
                            VStack(spacing: 12) {
                                Button {
                                    showMarkReceived = true
                                } label: {
                                    Text("Withdrawal Received")
                                        .font(.headline)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.appGold)
                                        .cornerRadius(12)
                                }

                                Button {
                                    showRemoveAlert = true
                                } label: {
                                    Text("Withdrawal Failed")
                                        .font(.headline)
                                        .foregroundColor(.appLoss)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.appBackground)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appLoss, lineWidth: 1.5))
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Withdrawal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.appSecondary)
                }
            }
        }
        .onAppear { selectedMethod = originalMethod }
        .sheet(isPresented: $showMarkReceived, onDismiss: {
            if (withdrawal.withdrawalStatus ?? "received") == "received" {
                dismiss()
            }
        }) {
            MarkReceivedSheet(withdrawal: withdrawal, baseCurrency: baseCurrency)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Remove Withdrawal?", isPresented: $showRemoveAlert) {
            Button("Remove", role: .destructive) {
                viewContext.delete(withdrawal)
                try? viewContext.save()
                viewContext.refreshAllObjects()
                NotificationCenter.default.post(name: Notification.Name("platformDataChanged"), object: nil)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This withdrawal will be removed and your platform balance will be restored.")
        }
    }

    @ViewBuilder
    func lockedRow(label: String, value: String) -> some View {
        HStack {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundColor(.appGold)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.appSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.appPrimary)
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(8)
    }
}

// MARK: - Mark Received Sheet

struct MarkReceivedSheet: View {
    @ObservedObject var withdrawal: Withdrawal
    let baseCurrency: String
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("exchangeRateInputMode") private var exchangeRateInputMode = "direct"

    @State private var isForeignExchange = false
    @State private var amountReceivedText = ""
    @State private var receivedDate = Date()
    @State private var exchangeRateStr = ""
    @State private var selectedMethod: String = ""
    @State private var notes: String = ""

    var platformCurrency: String { withdrawal.platform?.displayCurrency ?? "USD" }
    var isForeignCurrency: Bool { platformCurrency != baseCurrency }

    // Mode A: base = requested × rate
    var computedBaseAmount: Double {
        let req = withdrawal.amountRequested
        let rate = Double(exchangeRateStr) ?? 0
        guard req > 0, rate > 0 else { return 0 }
        return req * rate
    }

    // Mode B: rate = base / requested
    var computedRate: Double {
        let req = withdrawal.amountRequested
        let base = Double(amountReceivedText) ?? 0
        guard req > 0, base > 0 else { return 0 }
        return base / req
    }

    var isValid: Bool {
        if isForeignExchange && isForeignCurrency {
            if exchangeRateInputMode == "direct" {
                return (Double(exchangeRateStr) ?? 0) > 0
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

                    Section {
                        Button {
                            confirmReceived()
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
            .navigationTitle("Withdrawal Received")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.appSecondary)
                }
            }
        }
        .onAppear {
            isForeignExchange = isForeignCurrency
            let storedRate = withdrawal.effectiveExchangeRate
            if isForeignCurrency && storedRate > 0 {
                exchangeRateStr = String(format: "%.4f", storedRate)
            }
            selectedMethod = withdrawal.method ?? withdrawalMethods[0]
        }
    }

    var amountsSection: some View {
        Section {
            // Amount Requested (read-only locked)
            lockedRow(
                label: "Amount Requested (\(platformCurrency))",
                value: AppFormatter.currency(withdrawal.amountRequested, code: platformCurrency)
            )

            if isForeignCurrency {
                Toggle(isOn: $isForeignExchange.animation(.easeInOut)) {
                    Text("Foreign Exchange").foregroundColor(.appPrimary)
                }
                .tint(.appGold)
                .listRowBackground(Color.appSurface)
            }

            if isForeignExchange && isForeignCurrency {
                if exchangeRateInputMode == "direct" {
                    // Mode A: user enters rate
                    HStack {
                        Text("Cash-Out Rate").foregroundColor(.appPrimary)
                        Spacer()
                        CurrencyInputField(text: $exchangeRateStr, width: 90, maxDecimalPlaces: 4, textColor: .appGold)
                        Text("\(baseCurrency)/\(platformCurrency)")
                            .font(.caption).foregroundColor(.appSecondary)
                    }
                    .listRowBackground(Color.appSurface)

                    HStack {
                        Text("Amount Received (\(baseCurrency))").foregroundColor(.appSecondary)
                        Spacer()
                        Text(computedBaseAmount > 0
                             ? AppFormatter.currency(computedBaseAmount, code: baseCurrency)
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

                // Effective Rate (read-only display)
                let rate = exchangeRateInputMode == "direct"
                    ? (Double(exchangeRateStr) ?? 0)
                    : computedRate
                if rate > 0 {
                    HStack {
                        Text("Effective Rate (\(baseCurrency)/\(platformCurrency))")
                            .foregroundColor(.appSecondary)
                        Spacer()
                        Text(String(format: "%.4f", rate))
                            .foregroundColor(.appNeutral)
                    }
                    .listRowBackground(Color.appSurface)
                }
            } else {
                // FX OFF: platform currency amount
                HStack {
                    Text("Amount Received (\(platformCurrency))").foregroundColor(.appPrimary)
                    Spacer()
                    CurrencyInputField(text: $amountReceivedText, width: 120)
                }
                .listRowBackground(Color.appSurface)
            }
        } header: {
            Text("Amounts").foregroundColor(.appGold).textCase(nil)
        }
    }

    var detailsSection: some View {
        Section {
            // Method (editable)
            Picker("Method", selection: $selectedMethod) {
                ForEach(withdrawalMethods, id: \.self) { Text($0) }
            }
            .foregroundColor(.appPrimary)
            .tint(.appGold)
            .listRowBackground(Color.appSurface)

            // Date Requested (read-only locked)
            lockedRow(
                label: "Date Requested",
                value: AppFormatter.shortDate(withdrawal.date ?? Date())
            )

            // Date Received (editable)
            DatePicker("Date Received", selection: $receivedDate, displayedComponents: .date)
                .foregroundColor(.appPrimary)
                .tint(.appGold)
                .listRowBackground(Color.appSurface)

            // Notes (editable)
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .foregroundColor(.appPrimary)
                .listRowBackground(Color.appSurface)
        } header: {
            Text("Details").foregroundColor(.appGold).textCase(nil)
        }
    }

    @ViewBuilder
    func lockedRow(label: String, value: String) -> some View {
        HStack {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundColor(.appGold)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.appSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.appPrimary)
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(8)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    func confirmReceived() {
        let receivedAmount: Double
        let finalRate: Double

        if isForeignExchange && isForeignCurrency {
            if exchangeRateInputMode == "direct" {
                let rate = Double(exchangeRateStr) ?? 0
                guard rate > 0 else { return }
                receivedAmount = computedBaseAmount
                finalRate = rate
            } else {
                let base = Double(amountReceivedText) ?? 0
                guard base > 0 else { return }
                receivedAmount = base
                finalRate = computedRate > 0 ? computedRate : 1.0
            }
        } else {
            let amount = Double(amountReceivedText) ?? 0
            guard amount > 0 else { return }
            receivedAmount = amount
            finalRate = 1.0
        }

        withdrawal.amountReceived = receivedAmount
        withdrawal.receivedDate = receivedDate
        withdrawal.withdrawalStatus = "received"
        withdrawal.effectiveExchangeRate = finalRate
        withdrawal.isForeignExchange = isForeignExchange && isForeignCurrency
        withdrawal.method = selectedMethod
        if !notes.isEmpty {
            withdrawal.notes = notes
        }
        if let platform = withdrawal.platform {
            viewContext.refresh(platform, mergeChanges: true)
        }
        try? viewContext.save()
        viewContext.refreshAllObjects()
        NotificationCenter.default.post(name: Notification.Name("platformDataChanged"), object: nil)
        dismiss()
    }
}
