import Foundation
import CoreLocation
import Combine

@MainActor
class LocationManager: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation? = nil
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocating: Bool = false

    private let manager = CLLocationManager()
    private var fixCompletion: ((CLLocation?) -> Void)? = nil
    private var timeoutTask: Task<Void, Never>? = nil

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermissionIfNeeded() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func startLocating(completion: ((CLLocation?) -> Void)? = nil) {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            if status == .notDetermined {
                fixCompletion = completion
                manager.requestWhenInUseAuthorization()
            } else {
                completion?(nil)
            }
            return
        }
        fixCompletion = completion
        isLocating = true
        manager.startUpdatingLocation()

        timeoutTask?.cancel()
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            if !Task.isCancelled {
                await MainActor.run {
                    self.stopLocating(with: nil)
                }
            }
        }
    }

    func stopLocating(with location: CLLocation?) {
        manager.stopUpdatingLocation()
        isLocating = false
        timeoutTask?.cancel()
        timeoutTask = nil
        if let location {
            currentLocation = location
        }
        let cb = fixCompletion
        fixCompletion = nil
        cb?(location)
    }

    func stop() {
        manager.stopUpdatingLocation()
        isLocating = false
        timeoutTask?.cancel()
        timeoutTask = nil
        fixCompletion = nil
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if (status == .authorizedWhenInUse || status == .authorizedAlways) && self.fixCompletion != nil {
                manager.startUpdatingLocation()
                self.isLocating = true
            } else if status == .denied || status == .restricted {
                self.stopLocating(with: nil)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        Task { @MainActor in
            self.stopLocating(with: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.stopLocating(with: nil)
        }
    }
}
