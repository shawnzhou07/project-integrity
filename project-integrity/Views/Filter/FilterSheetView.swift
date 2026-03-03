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

    @State private var openSection: String? = nil

    private var liveEnabled: Bool {
        filterState.sessionTypes.isEmpty || filterState.sessionTypes.contains(.live)
    }

    private var onlineEnabled: Bool {
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
            ScrollView {
                VStack(spacing: 8) {
                    dateRangeAccordion
                    sessionTypeAccordion
                    locationsAccordion
                    platformsAccordion
                    gameTypeAccordion
                    blindLevelAccordion
                    if showSessionsOnlyFilters {
                        resultAccordion
                        verificationAccordion
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.appBackground)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        filterState.reset()
                        openSection = nil
                    }
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
        .onAppear { openSection = nil }
    }

    // MARK: - Accordion Header

    @ViewBuilder
    func accordionHeader(id: String, title: String, activeCount: Int, disabled: Bool = false) -> some View {
        Button {
            guard !disabled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                openSection = openSection == id ? nil : id
            }
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(disabled ? .appSecondary : .appGold)
                if activeCount > 0 && !disabled {
                    Text("\(activeCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Color.appGold)
                        .clipShape(Circle())
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(disabled ? Color.appSecondary.opacity(0.4) : .appGold)
                    .rotationEffect(.degrees(openSection == id ? 90 : 0))
                    .animation(.easeInOut(duration: 0.2), value: openSection)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date Range

    var dateRangeAccordion: some View {
        VStack(spacing: 0) {
            accordionHeader(id: "date", title: "Date Range", activeCount: filterState.isDateSectionActive ? 1 : 0)
            if openSection == "date" {
                Divider().background(Color.appBorder)
                VStack(spacing: 0) {
                    ForEach(DateRangeFilter.allCases, id: \.self) { option in
                        Button {
                            filterState.dateRange = option
                        } label: {
                            HStack {
                                Text(option.rawValue).foregroundColor(.appPrimary)
                                Spacer()
                                if filterState.dateRange == option {
                                    Image(systemName: "checkmark").foregroundColor(.appGold)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().background(Color.appBorder).padding(.leading, 16)
                    }
                    if filterState.dateRange == .custom {
                        DatePicker("Start Date", selection: $filterState.customStartDate, displayedComponents: .date)
                            .foregroundColor(.appPrimary)
                            .tint(.appGold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        Divider().background(Color.appBorder).padding(.leading, 16)
                        DatePicker("End Date", selection: $filterState.customEndDate, displayedComponents: .date)
                            .foregroundColor(.appPrimary)
                            .tint(.appGold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        Divider().background(Color.appBorder).padding(.leading, 16)
                    }
                }
            }
        }
        .background(Color.appSurface)
        .cornerRadius(10)
    }

    // MARK: - Session Type

    var sessionTypeAccordion: some View {
        VStack(spacing: 0) {
            accordionHeader(id: "type", title: "Session Type", activeCount: filterState.isTypeSectionActive ? 1 : 0)
            if openSection == "type" {
                Divider().background(Color.appBorder)
                VStack(spacing: 0) {
                    Button { toggleLive() } label: {
                        HStack {
                            Text("Live Sessions").foregroundColor(.appPrimary)
                            Spacer()
                            Toggle("", isOn: .constant(liveEnabled))
                                .labelsHidden()
                                .tint(.appGold)
                                .allowsHitTesting(false)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().background(Color.appBorder).padding(.leading, 16)
                    Button { toggleOnline() } label: {
                        HStack {
                            Text("Online Sessions").foregroundColor(.appPrimary)
                            Spacer()
                            Toggle("", isOn: .constant(onlineEnabled))
                                .labelsHidden()
                                .tint(.appGold)
                                .allowsHitTesting(false)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color.appSurface)
        .cornerRadius(10)
    }

    // MARK: - Locations

    @ViewBuilder
    var locationsAccordion: some View {
        let disabled = !liveEnabled
        VStack(spacing: 0) {
            accordionHeader(
                id: "locations",
                title: "Locations",
                activeCount: filterState.selectedLocationIDs.count,
                disabled: disabled
            )
            if openSection == "locations" && !disabled {
                Divider().background(Color.appBorder)
                if locations.isEmpty {
                    Text("No locations added yet.")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)
                } else {
                    VStack(spacing: 0) {
                        selectAllRow(
                            allSelected: filterState.selectedLocationIDs.count == locations.count,
                            onSelectAll: { filterState.selectedLocationIDs = Set(locations.compactMap { $0.id }) },
                            onDeselectAll: { filterState.selectedLocationIDs = [] }
                        )
                        Divider().background(Color.appBorder).padding(.leading, 16)
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
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().background(Color.appBorder).padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .background(Color.appSurface)
        .cornerRadius(10)
    }

    // MARK: - Platforms

    @ViewBuilder
    var platformsAccordion: some View {
        let disabled = !onlineEnabled
        VStack(spacing: 0) {
            accordionHeader(
                id: "platforms",
                title: "Platforms",
                activeCount: filterState.selectedPlatformIDs.count,
                disabled: disabled
            )
            if openSection == "platforms" && !disabled {
                Divider().background(Color.appBorder)
                if platforms.isEmpty {
                    Text("No platforms added yet.")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)
                } else {
                    VStack(spacing: 0) {
                        selectAllRow(
                            allSelected: filterState.selectedPlatformIDs.count == platforms.count,
                            onSelectAll: { filterState.selectedPlatformIDs = Set(platforms.compactMap { $0.id }) },
                            onDeselectAll: { filterState.selectedPlatformIDs = [] }
                        )
                        Divider().background(Color.appBorder).padding(.leading, 16)
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
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().background(Color.appBorder).padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .background(Color.appSurface)
        .cornerRadius(10)
    }

    // MARK: - Game Type

    var gameTypeAccordion: some View {
        VStack(spacing: 0) {
            accordionHeader(id: "gameType", title: "Game Type", activeCount: filterState.selectedGameTypes.count)
            if openSection == "gameType" {
                Divider().background(Color.appBorder)
                if allGameTypes.isEmpty {
                    Text("No game types recorded yet.")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)
                } else {
                    VStack(spacing: 0) {
                        selectAllRow(
                            allSelected: filterState.selectedGameTypes.count == allGameTypes.count,
                            onSelectAll: { filterState.selectedGameTypes = Set(allGameTypes) },
                            onDeselectAll: { filterState.selectedGameTypes = [] }
                        )
                        Divider().background(Color.appBorder).padding(.leading, 16)
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
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().background(Color.appBorder).padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .background(Color.appSurface)
        .cornerRadius(10)
    }

    // MARK: - Blind Levels

    var blindLevelAccordion: some View {
        VStack(spacing: 0) {
            accordionHeader(id: "blinds", title: "Blind Levels", activeCount: filterState.selectedBlindLevels.count)
            if openSection == "blinds" {
                Divider().background(Color.appBorder)
                if allBlindLevels.isEmpty {
                    Text("No blind levels recorded yet.")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)
                } else {
                    VStack(spacing: 0) {
                        selectAllRow(
                            allSelected: filterState.selectedBlindLevels.count == allBlindLevels.count,
                            onSelectAll: { filterState.selectedBlindLevels = Set(allBlindLevels) },
                            onDeselectAll: { filterState.selectedBlindLevels = [] }
                        )
                        Divider().background(Color.appBorder).padding(.leading, 16)
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
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().background(Color.appBorder).padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .background(Color.appSurface)
        .cornerRadius(10)
    }

    // MARK: - Result (sessions only)

    var resultAccordion: some View {
        VStack(spacing: 0) {
            accordionHeader(id: "result", title: "Result", activeCount: filterState.isResultSectionActive ? 1 : 0)
            if openSection == "result" {
                Divider().background(Color.appBorder)
                VStack(spacing: 0) {
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().background(Color.appBorder).padding(.leading, 16)
                    }
                }
            }
        }
        .background(Color.appSurface)
        .cornerRadius(10)
    }

    // MARK: - Verification Status (sessions only)

    var verificationAccordion: some View {
        VStack(spacing: 0) {
            accordionHeader(id: "verification", title: "Verification Status", activeCount: filterState.isVerificationSectionActive ? 1 : 0)
            if openSection == "verification" {
                Divider().background(Color.appBorder)
                VStack(spacing: 0) {
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().background(Color.appBorder).padding(.leading, 16)
                    }
                }
            }
        }
        .background(Color.appSurface)
        .cornerRadius(10)
    }

    // MARK: - Helpers

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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.appSurface2)
    }

    private func toggleLive() {
        if liveEnabled {
            filterState.sessionTypes = [.online]
        } else {
            filterState.sessionTypes = []
        }
    }

    private func toggleOnline() {
        if onlineEnabled {
            filterState.sessionTypes = [.live]
        } else {
            filterState.sessionTypes = []
        }
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
