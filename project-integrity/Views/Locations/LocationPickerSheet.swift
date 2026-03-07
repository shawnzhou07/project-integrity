import SwiftUI
import CoreData

struct LocationPickerSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedLocation: Location?
    var onSelectNone: () -> Void

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Location.name, ascending: true)],
        animation: .default
    ) private var allLocations: FetchedResults<Location>

    @State private var searchText = ""
    @State private var showAddLocation = false

    var filteredLocations: [Location] {
        if searchText.isEmpty { return Array(allLocations) }
        return allLocations.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
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
