// 📖 Refer to UI_MASTER.md, ARCHITECTURE.md, and BUSINESS_RULES.md before making UI or logic changes.
// 📝 Update relevant .md docs after making changes (except CHANGELOG.md which updates per build). See README.md Documentation Maintenance section.
import SwiftUI
import CoreData
import Combine

struct PlatformsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("baseCurrency") private var baseCurrency = "CAD"
    @EnvironmentObject var coordinator: ActiveSessionCoordinator

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)],
        animation: .default
    ) private var platforms: FetchedResults<Platform>

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

    @State private var showAddPlatform = false
    @State private var platformToDelete: Platform? = nil
    @State private var showDeleteAlert = false
    @State private var externalDepositPlatform: Platform? = nil
    @State private var externalWithdrawalPlatform: Platform? = nil
    @State private var showExternalDeposit = false
    @State private var showExternalWithdrawal = false
    @State private var showPlatformSettingsSheet = false
    @State private var platformForSettings: Platform? = nil

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            if platforms.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(Array(platforms)) { platform in
                        NavigationLink {
                            PlatformDetailView(platform: platform)
                        } label: {
                            PlatformRowView(platform: platform, baseCurrency: baseCurrency)
                        }
                        .listRowBackground(Color.appSurface)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .contextMenu {
                            Button {
                                platformForSettings = platform
                                showPlatformSettingsSheet = true
                            } label: {
                                Label("Settings", systemImage: "gearshape")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                platformToDelete = platform
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: smartBottomPadding(isSessionActive: hasActiveSession))
                }
                .animation(.easeInOut(duration: 0.25), value: hasActiveSession)
                .refreshable {
                    await performRefresh()
                }
            }
        }
        .navigationTitle("Platforms")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddPlatform = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.appGold)
                }
            }
        }
        .sheet(isPresented: $showAddPlatform) {
            AddPlatformView()
        }
        .sheet(isPresented: $showExternalDeposit, onDismiss: {
            refreshPlatformsForList()
        }) {
            if let p = externalDepositPlatform {
                DepositFormView(platform: p)
            }
        }
        .sheet(isPresented: $showExternalWithdrawal, onDismiss: {
            refreshPlatformsForList()
        }) {
            if let p = externalWithdrawalPlatform {
                WithdrawalFormView(platform: p)
            }
        }
        .sheet(isPresented: $showPlatformSettingsSheet) {
            if let platform = platformForSettings {
                PlatformSettingsView(platform: platform)
            }
        }
        .onAppear {
            handleCoordinatorTriggers()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("sessionVerified"))) { _ in
            refreshPlatformsForList()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("platformDataChanged"))) { _ in
            refreshPlatformsForList()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("balanceUpdated"))) { _ in
            refreshPlatformsForList()
        }
        .onChange(of: coordinator.shouldOpenAddPlatform) { _, v in
            if v { showAddPlatform = true; coordinator.shouldOpenAddPlatform = false }
        }
        .onChange(of: coordinator.platformIDForDeposit) { _, _ in handleCoordinatorTriggers() }
        .onChange(of: coordinator.platformIDForWithdrawal) { _, _ in handleCoordinatorTriggers() }
        .alert(deleteAlertTitle, isPresented: $showDeleteAlert) {
            if platformToDeleteHasRecords {
                Button("OK", role: .cancel) {
                    platformToDelete = nil
                }
            } else {
                Button("Delete", role: .destructive) {
                    if let p = platformToDelete {
                        viewContext.delete(p)
                        try? viewContext.save()
                    }
                    platformToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    platformToDelete = nil
                }
            }
        } message: {
            Text(deleteAlertMessage)
        }
    }

    var platformToDeleteHasRecords: Bool {
        guard let p = platformToDelete else { return false }
        return !p.onlineSessionsArray.isEmpty || !p.depositsArray.isEmpty ||
               !p.withdrawalsArray.isEmpty || !p.adjustmentsArray.isEmpty
    }

    func performRefresh() async {
        viewContext.refreshAllObjects()
        refreshPlatformsForList()
    }

    /// Updates list rows when balances / withdrawals change without recreating the entire view hierarchy (`refreshAllObjects` + `id()` caused severe lag).
    private func refreshPlatformsForList() {
        for p in platforms {
            viewContext.refresh(p, mergeChanges: true)
            p.objectWillChange.send()
        }
    }

    func handleCoordinatorTriggers() {
        if coordinator.shouldOpenAddPlatform {
            showAddPlatform = true
            coordinator.shouldOpenAddPlatform = false
        }
        if let id = coordinator.platformIDForDeposit,
           let platform = platforms.first(where: { $0.objectID == id }) {
            externalDepositPlatform = platform
            showExternalDeposit = true
            coordinator.platformIDForDeposit = nil
        }
        if let id = coordinator.platformIDForWithdrawal,
           let platform = platforms.first(where: { $0.objectID == id }) {
            externalWithdrawalPlatform = platform
            showExternalWithdrawal = true
            coordinator.platformIDForWithdrawal = nil
        }
    }

    var deleteAlertTitle: String {
        platformToDeleteHasRecords
            ? "Cannot Delete \(platformToDelete?.displayName ?? "Platform")"
            : "Delete \(platformToDelete?.displayName ?? "Platform")?"
    }

    var deleteAlertMessage: String {
        guard let p = platformToDelete else { return "This cannot be undone." }
        let sessions = p.onlineSessionsArray.count
        let deposits = p.depositsArray.count
        let withdrawals = p.withdrawalsArray.count
        let adjustments = p.adjustmentsArray.count
        var parts: [String] = []
        if sessions > 0 { parts.append("\(sessions) session\(sessions == 1 ? "" : "s")") }
        if deposits > 0 { parts.append("\(deposits) deposit\(deposits == 1 ? "" : "s")") }
        if withdrawals > 0 { parts.append("\(withdrawals) withdrawal\(withdrawals == 1 ? "" : "s")") }
        if adjustments > 0 { parts.append("\(adjustments) adjustment\(adjustments == 1 ? "" : "s")") }
        if parts.isEmpty { return "This cannot be undone." }
        return "This platform has \(parts.joined(separator: ", ")). Platforms with existing records cannot be deleted."
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard")
                .font(.system(size: 48))
                .foregroundColor(.appSecondary)
            Text("No Platforms")
                .font(.headline)
                .foregroundColor(.appPrimary)
            Text("Tap + to add your poker platforms")
                .font(.subheadline)
                .foregroundColor(.appSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PlatformRowView: View {
    @ObservedObject var platform: Platform
    let baseCurrency: String

    var isSameCurrency: Bool { platform.displayCurrency == baseCurrency }

    var netResultColor: Color {
        platform.netResult.profitColor
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(platform.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.appPrimary)
                Text(platform.displayCurrency)
                    .font(.system(size: 13))
                    .foregroundColor(.appSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(AppFormatter.currencySigned(platform.netResult, code: baseCurrency))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(netResultColor)
                Text(AppFormatter.currency(platform.currentBalance, code: platform.displayCurrency))
                    .font(.system(size: 13))
                    .foregroundColor(.appSecondary)
            }
        }
        .frame(minHeight: 72)
        .padding(.vertical, 6)
    }
}

#Preview {
    PlatformsListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .preferredColorScheme(.dark)
}
