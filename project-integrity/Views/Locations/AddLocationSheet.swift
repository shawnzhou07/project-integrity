import SwiftUI
import CoreData

struct AddLocationSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    var onSave: ((Location) -> Void)? = nil

    @State private var locationName = ""

    var isValid: Bool { !locationName.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Location name", text: $locationName)
                        .foregroundColor(.appPrimary)
                } header: {
                    Text("Name").foregroundColor(.appGold).textCase(nil)
                }
                .listRowBackground(Color.appSurface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.appSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveLocation() }
                        .foregroundColor(isValid ? .appGold : .appSecondary)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func saveLocation() {
        guard isValid else { return }
        let loc = Location(context: viewContext)
        loc.id = UUID()
        loc.name = locationName.trimmingCharacters(in: .whitespaces)
        loc.createdAt = Date()
        do {
            try viewContext.save()
            onSave?(loc)
            dismiss()
        } catch {
            print("Save location error: \(error)")
        }
    }
}
