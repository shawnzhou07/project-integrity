import SwiftUI

struct LocationDetailView: View {
    @ObservedObject var location: Location

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    // Info card
                    VStack(spacing: 0) {
                        infoRow(label: "Sessions", value: "\(location.sessionsArray.count)")
                    }
                    .background(Color.appSurface)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(location.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.appSecondary)
            Spacer()
            Text(value)
                .foregroundColor(.appPrimary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}
