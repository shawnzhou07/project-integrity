import SwiftUI
import CoreData
import CoreLocation

struct LocationPickerSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedLocation: Location?
    let gpsLocation: CLLocation?
    var onSelectNone: () -> Void

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Location.name, ascending: true)],
        animation: .default
    ) private var allLocations: FetchedResults<Location>

    @State private var searchText = ""
    @State private var showAddLocation = false

    private let nearbyThreshold: CLLocationDistance = 500

    var nearbyLocations: [Location] {
        guard let gps = gpsLocation else { return [] }
        return allLocations.filter { loc in
            let c = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
            return gps.distance(from: c) <= nearbyThreshold
        }.sorted { a, b in
            let ca = CLLocation(latitude: a.latitude, longitude: a.longitude)
            let cb = CLLocation(latitude: b.latitude, longitude: b.longitude)
            return gps.distance(from: ca) < gps.distance(from: cb)
        }
    }

    var filteredLocations: [Location] {
        if searchText.isEmpty { return Array(allLocations) }
        return allLocations.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredNearby: [Location] {
        if searchText.isEmpty { return nearbyLocations }
        return nearbyLocations.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                List {
                    // None option
                    Section {
                        Button {
                            onSelectNone()
                            dismiss()
                        } label: {
                            HStack {
                                Text("None")
                                    .foregroundColor(.appPrimary)
                                Spacer()
                                if selectedLocation == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.appGold)
                                }
                            }
                        }
                        .listRowBackground(Color.appSurface)
                    }

                    // Nearby
                    if !filteredNearby.isEmpty {
                        Section {
                            ForEach(filteredNearby) { loc in
                                locationRow(loc)
                            }
                        } header: {
                            sectionHeader("Nearby", isActive: false)
                        }
                    }

                    // All Locations
                    Section {
                        ForEach(filteredLocations) { loc in
                            locationRow(loc)
                        }
                    } header: {
                        sectionHeader("All Locations", isActive: false)
                    }

                    // Create New
                    Section {
                        Button {
                            showAddLocation = true
                        } label: {
                            Label("Create New Location", systemImage: "plus.circle.fill")
                                .foregroundColor(.appGold)
                        }
                        .listRowBackground(Color.appSurface)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
                .searchable(text: $searchText, prompt: "Search locations")
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.appGold)
                }
            }
            .sheet(isPresented: $showAddLocation) {
                AddLocationSheet { newLoc in
                    selectedLocation = newLoc
                }
                .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    private func locationRow(_ loc: Location) -> some View {
        Button {
            selectedLocation = loc
            dismiss()
        } label: {
            HStack {
                Text(loc.displayName)
                    .foregroundColor(.appPrimary)
                    .font(.subheadline)
                Spacer()
                if selectedLocation?.id == loc.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(.appGold)
                }
            }
        }
        .listRowBackground(Color.appSurface)
    }

    private func sectionHeader(_ title: String, isActive: Bool) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.appGold)
            .textCase(nil)
    }
}
