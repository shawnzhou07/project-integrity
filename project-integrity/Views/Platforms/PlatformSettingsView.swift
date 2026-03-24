// Refer to UI_MASTER.md at project root before making UI changes.
import SwiftUI
import CoreData

struct PlatformSettingsView: View {
    @ObservedObject var platform: Platform
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    private var tableSize: Int {
        let raw = Int(platform.defaultTableSize)
        return (raw >= 2 && raw <= 10) ? raw : 6
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Form {
                    Section {
                        HStack {
                            Text("Default Table Size")
                                .foregroundColor(.appPrimary)
                            Spacer()
                            Stepper(
                                "\(tableSize)",
                                value: Binding(
                                    get: { tableSize },
                                    set: {
                                        platform.defaultTableSize = Int16($0)
                                        try? viewContext.save()
                                    }
                                ),
                                in: 2...10
                            )
                            .foregroundColor(.appPrimary)
                        }
                        .listRowBackground(Color.appSurface)
                    } header: {
                        Text("New Session Defaults").foregroundColor(.appGold).textCase(nil)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
            }
            .navigationTitle("Platform Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if platform.defaultTableSize == 0 {
                    platform.defaultTableSize = 6
                    try? viewContext.save()
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.appGold)
                }
            }
        }
    }
}
