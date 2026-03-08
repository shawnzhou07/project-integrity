import SwiftUI
import CoreData

struct MoreView: View {
    @EnvironmentObject var coordinator: ActiveSessionCoordinator
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showDirectAdjustment = false
    @State private var directAdjustmentPlatform: Platform? = nil
    @StateObject private var chartsFilterState = FilterState()

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            List {
                NavigationLink {
                    LocationsListView()
                } label: {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.appGold)
                        Text("Locations")
                            .foregroundColor(.white)
                    }
                }
                .listRowBackground(Color.appSurface)

                NavigationLink {
                    ChartsView(filterState: chartsFilterState)
                } label: {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.appGold)
                        Text("Charts")
                            .foregroundColor(.white)
                    }
                }
                .listRowBackground(Color.appSurface)

                NavigationLink {
                    CalendarView()
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.appGold)
                        Text("Calendar")
                            .foregroundColor(.white)
                    }
                }
                .listRowBackground(Color.appSurface)

                NavigationLink {
                    AdjustmentsListView()
                } label: {
                    HStack {
                        Image(systemName: "plusminus.circle.fill")
                            .foregroundColor(.appGold)
                        Text("Adjustments")
                            .foregroundColor(.white)
                    }
                }
                .listRowBackground(Color.appSurface)

                NavigationLink {
                    SettingsView()
                } label: {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.appGold)
                        Text("Settings")
                            .foregroundColor(.white)
                    }
                }
                .listRowBackground(Color.appSurface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
        }
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { handleAdjustmentTrigger() }
        .onChange(of: coordinator.adjustmentPlatformID) { _, _ in handleAdjustmentTrigger() }
        .sheet(isPresented: $showDirectAdjustment) {
            if let p = directAdjustmentPlatform {
                AddAdjustmentView(initialPlatform: p)
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(coordinator)
            }
        }
    }

    func handleAdjustmentTrigger() {
        guard let id = coordinator.adjustmentPlatformID else { return }
        if let platform = try? viewContext.existingObject(with: id) as? Platform {
            directAdjustmentPlatform = platform
            showDirectAdjustment = true
            coordinator.adjustmentPlatformID = nil
        }
    }
}

#Preview {
    NavigationStack {
        MoreView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(ActiveSessionCoordinator())
    .preferredColorScheme(.dark)
}
