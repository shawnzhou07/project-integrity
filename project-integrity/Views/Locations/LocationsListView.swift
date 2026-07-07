// 📖 Refer to UI_MASTER.md, ARCHITECTURE.md, and BUSINESS_RULES.md before making UI or logic changes.
// 📝 Update relevant .md docs after making changes (except CHANGELOG.md which updates per build). See README.md Documentation Maintenance section.
import SwiftUI
import CoreData

struct LocationsListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Location.name, ascending: true)],
        animation: .default
    ) private var locations: FetchedResults<Location>

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

    @State private var showAddLocation = false
    @State private var locationToDelete: Location? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Group {
                if locations.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(locations) { loc in
                            NavigationLink {
                                LocationDetailView(location: loc)
                            } label: {
                                locationRow(loc)
                            }
                            .listRowBackground(Color.appSurface)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    locationToDelete = loc
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
                }
            }
        }
        .navigationTitle("Locations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddLocation = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.appGold)
                }
            }
        }
        .sheet(isPresented: $showAddLocation) {
            AddLocationSheet()
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete \(locationToDelete?.displayName ?? "Location")?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let loc = locationToDelete { deleteLocation(loc) }
                locationToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                locationToDelete = nil
            }
        } message: {
            Text("Past sessions will keep the location name. This cannot be undone.")
        }
    }

    private func locationRow(_ loc: Location) -> some View {
        Text(loc.displayName)
            .foregroundColor(.appPrimary)
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 48))
                .foregroundColor(.appSecondary)
            Text("No Locations Yet")
                .font(.headline)
                .foregroundColor(.appPrimary)
            Text("Tap + to add your first location")
                .font(.subheadline)
                .foregroundColor(.appSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deleteLocation(_ loc: Location) {
        PersistenceController.shared.deleteLocation(loc, context: viewContext)
    }
}
