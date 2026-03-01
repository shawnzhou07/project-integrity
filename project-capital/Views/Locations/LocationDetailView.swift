import SwiftUI
import MapKit
import CoreLocation

struct LocationDetailView: View {
    @ObservedObject var location: Location

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }

    var mapPosition: MapCameraPosition {
        .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    // Map
                    Map(position: .constant(mapPosition), interactionModes: []) {
                        Marker(location.displayName, coordinate: coordinate)
                            .tint(Color(hex: "#C9B47A"))
                    }
                    .frame(height: 260)
                    .cornerRadius(12)
                    .padding(.horizontal)

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
