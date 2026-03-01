import SwiftUI
import CoreData

// MARK: - Filter Sheet

struct FilterSheetView: View {
    @ObservedObject var filterState: FilterState
    let showSessionsOnlyFilters: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Location.name, ascending: true)])
    private var locations: FetchedResults<Location>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)])
    private var platforms: FetchedResults<Platform>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \OnlineCash.startTime, ascending: false)])
    private var onlineSessions: FetchedResults<OnlineCash>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LiveCash.startTime, ascending: false)])
    private var liveSessions: FetchedResults<LiveCash>

    private var showLiveSections: Bool {
        filterState.sessionTypes.isEmpty || filterState.sessionTypes.contains(.live)
    }
    private var showOnlineSections: Bool {
        filterState.sessionTypes.isEmpty || filterState.sessionTypes.contains(.online)
    }

    var allGameTypes: [String] {
        var types = Set<String>()
        onlineSessions.compactMap { $0.gameType }.forEach { types.insert($0) }
        liveSessions.compactMap { $0.gameType }.forEach { types.insert($0) }
        return types.sorted()
    }

    var allBlindLevels: [String] {
        var levels = Set<String>()
        for s in onlineSessions where s.smallBlind > 0 && s.bigBlind > 0 {
            levels.insert("\(AppFormatter.blindValue(s.smallBlind))/\(AppFormatter.blindValue(s.bigBlind))")
        }
        for s in liveSessions where s.smallBlind > 0 && s.bigBlind > 0 {
            levels.insert("\(AppFormatter.blindValue(s.smallBlind))/\(AppFormatter.blindValue(s.bigBlind))")
        }
        return levels.sorted { a, b in
            let aBB = Double(a.split(separator: "/").last ?? "") ?? 0
            let bBB = Double(b.split(separator: "/").last ?? "") ?? 0
            return aBB < bBB
        }
    }

    var body: some View {
        NavigationStack {
            List {
                dateRangeSection
                if showSessionsOnlyFilters {
                    sessionTypeSection
                }
                if !locations.isEmpty && showLiveSections {
                    locationsSection
                }
                if !platforms.isEmpty && showOnlineSections {
                    platformsSection
                }
                if !allGameTypes.isEmpty {
                    gameTypeSection
                }
                if !allBlindLevels.isEmpty {
                    blindLevelSection
                }
                if showSessionsOnlyFilters {
                    resultSection
                    verificationSection
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") { filterState.reset() }
                        .foregroundColor(filterState.activeFilterCount > 0 ? .appGold : .appSecondary)
                        .disabled(filterState.activeFilterCount == 0)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.appGold)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    // MARK: - Section: Date Range

    private var dateRangeSection: some View {
        Section {
            ForEach(DateRangeFilter.allCases, id: \.self) { option in
                Button {
                    filterState.dateRange = option
                } label: {
                    HStack {
                        Text(option.rawValue)
                            .foregroundColor(.appPrimary)
                        Spacer()
                        if filterState.dateRange == option {
                            Image(systemName: "checkmark").foregroundColor(.appGold)
                        }
                    }
                }
                .listRowBackground(Color.appSurface)
            }

            if filterState.dateRange == .custom {
                DatePicker("Start Date", selection: $filterState.customStartDate, displayedComponents: .date)
                    .foregroundColor(.appPrimary)
                    .tint(.appGold)
                    .listRowBackground(Color.appSurface)
                DatePicker("End Date", selection: $filterState.customEndDate, displayedComponents: .date)
                    .foregroundColor(.appPrimary)
                    .tint(.appGold)
                    .listRowBackground(Color.appSurface)
            }
        } header: {
            filterSectionHeader("Date Range", isActive: filterState.isDateSectionActive)
        }
    }

    // MARK: - Section: Session Type

    private var sessionTypeSection: some View {
        Section {
            ForEach(SessionTypeOption.allCases, id: \.self) { type in
                Button {
                    if filterState.sessionTypes.contains(type) {
                        filterState.sessionTypes.remove(type)
                    } else {
                        filterState.sessionTypes.insert(type)
                    }
                } label: {
                    HStack {
                        Text(type.rawValue).foregroundColor(.appPrimary)
                        Spacer()
                        if filterState.sessionTypes.contains(type) {
                            Image(systemName: "checkmark").foregroundColor(.appGold)
                        }
                    }
                }
                .listRowBackground(Color.appSurface)
            }
        } header: {
            filterSectionHeader("Session Type", isActive: filterState.isTypeSectionActive)
        }
    }

    // MARK: - Section: Locations

    private var locationsSection: some View {
        Section {
            selectAllRow(
                allSelected: filterState.selectedLocationIDs.count == locations.count,
                onSelectAll: { filterState.selectedLocationIDs = Set(locations.compactMap { $0.id }) },
                onDeselectAll: { filterState.selectedLocationIDs = [] }
            )
            ForEach(locations) { loc in
                Button {
                    guard let id = loc.id else { return }
                    if filterState.selectedLocationIDs.contains(id) {
                        filterState.selectedLocationIDs.remove(id)
                    } else {
                        filterState.selectedLocationIDs.insert(id)
                    }
                } label: {
                    HStack {
                        Text(loc.displayName).foregroundColor(.appPrimary)
                        Spacer()
                        if let id = loc.id, filterState.selectedLocationIDs.contains(id) {
                            Image(systemName: "checkmark").foregroundColor(.appGold)
                        }
                    }
                }
                .listRowBackground(Color.appSurface)
            }
        } header: {
            filterSectionHeader("Locations", isActive: filterState.isLocationSectionActive)
        }
    }

    // MARK: - Section: Platforms

    private var platformsSection: some View {
        Section {
            selectAllRow(
                allSelected: filterState.selectedPlatformIDs.count == platforms.count,
                onSelectAll: { filterState.selectedPlatformIDs = Set(platforms.compactMap { $0.id }) },
                onDeselectAll: { filterState.selectedPlatformIDs = [] }
            )
            ForEach(platforms) { platform in
                Button {
                    guard let id = platform.id else { return }
                    if filterState.selectedPlatformIDs.contains(id) {
                        filterState.selectedPlatformIDs.remove(id)
                    } else {
                        filterState.selectedPlatformIDs.insert(id)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(platform.displayName).foregroundColor(.appPrimary)
                            Text(platform.displayCurrency)
                                .font(.caption).foregroundColor(.appSecondary)
                        }
                        Spacer()
                        if let id = platform.id, filterState.selectedPlatformIDs.contains(id) {
                            Image(systemName: "checkmark").foregroundColor(.appGold)
                        }
                    }
                }
                .listRowBackground(Color.appSurface)
            }
        } header: {
            filterSectionHeader("Platforms", isActive: filterState.isPlatformSectionActive)
        }
    }

    // MARK: - Section: Game Type

    private var gameTypeSection: some View {
        Section {
            selectAllRow(
                allSelected: filterState.selectedGameTypes.count == allGameTypes.count,
                onSelectAll: { filterState.selectedGameTypes = Set(allGameTypes) },
                onDeselectAll: { filterState.selectedGameTypes = [] }
            )
            ForEach(allGameTypes, id: \.self) { gt in
                Button {
                    if filterState.selectedGameTypes.contains(gt) {
                        filterState.selectedGameTypes.remove(gt)
                    } else {
                        filterState.selectedGameTypes.insert(gt)
                    }
                } label: {
                    HStack {
                        Text(gt).foregroundColor(.appPrimary)
                        Spacer()
                        if filterState.selectedGameTypes.contains(gt) {
                            Image(systemName: "checkmark").foregroundColor(.appGold)
                        }
                    }
                }
                .listRowBackground(Color.appSurface)
            }
        } header: {
            filterSectionHeader("Game Type", isActive: filterState.isGameTypeSectionActive)
        }
    }

    // MARK: - Section: Blind Levels

    private var blindLevelSection: some View {
        Section {
            selectAllRow(
                allSelected: filterState.selectedBlindLevels.count == allBlindLevels.count,
                onSelectAll: { filterState.selectedBlindLevels = Set(allBlindLevels) },
                onDeselectAll: { filterState.selectedBlindLevels = [] }
            )
            ForEach(allBlindLevels, id: \.self) { level in
                Button {
                    if filterState.selectedBlindLevels.contains(level) {
                        filterState.selectedBlindLevels.remove(level)
                    } else {
                        filterState.selectedBlindLevels.insert(level)
                    }
                } label: {
                    HStack {
                        Text(level).foregroundColor(.appPrimary)
                        Spacer()
                        if filterState.selectedBlindLevels.contains(level) {
                            Image(systemName: "checkmark").foregroundColor(.appGold)
                        }
                    }
                }
                .listRowBackground(Color.appSurface)
            }
        } header: {
            filterSectionHeader("Blind Levels", isActive: filterState.isBlindLevelSectionActive)
        }
    }

    // MARK: - Section: Result

    private var resultSection: some View {
        Section {
            ForEach(ResultFilter.allCases, id: \.self) { option in
                Button {
                    filterState.resultFilter = option
                } label: {
                    HStack {
                        Text(option.rawValue).foregroundColor(.appPrimary)
                        Spacer()
                        if filterState.resultFilter == option {
                            Image(systemName: "checkmark").foregroundColor(.appGold)
                        }
                    }
                }
                .listRowBackground(Color.appSurface)
            }
        } header: {
            filterSectionHeader("Result", isActive: filterState.isResultSectionActive)
        }
    }

    // MARK: - Section: Verification

    private var verificationSection: some View {
        Section {
            ForEach(VerificationFilter.allCases, id: \.self) { option in
                Button {
                    filterState.verificationFilter = option
                } label: {
                    HStack {
                        Text(option.rawValue).foregroundColor(.appPrimary)
                        Spacer()
                        if filterState.verificationFilter == option {
                            Image(systemName: "checkmark").foregroundColor(.appGold)
                        }
                    }
                }
                .listRowBackground(Color.appSurface)
            }
        } header: {
            filterSectionHeader("Verification Status", isActive: filterState.isVerificationSectionActive)
        }
    }

    // MARK: - Helpers

    private func filterSectionHeader(_ title: String, isActive: Bool) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundColor(.appGold)
                .textCase(nil)
            if isActive {
                Circle()
                    .fill(Color.appGold)
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func selectAllRow(allSelected: Bool, onSelectAll: @escaping () -> Void, onDeselectAll: @escaping () -> Void) -> some View {
        HStack {
            Button("Select All") { onSelectAll() }
                .font(.caption)
                .foregroundColor(.appGold)
            Spacer()
            Button("Deselect All") { onDeselectAll() }
                .font(.caption)
                .foregroundColor(.appSecondary)
        }
        .listRowBackground(Color.appSurface2)
    }
}

// MARK: - Filter Nav Bar Button

struct FilterNavBarButton: View {
    let activeCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.appGold)
                    .font(.system(size: 20))
                if activeCount > 0 {
                    Text("\(activeCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Color.appGold)
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
            }
        }
    }
}
