// Refer to UI_MASTER.md at project root before making UI changes.
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
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteLocation(loc)
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
