import CoreLocation

@MainActor
@Observable
final class LocationService: NSObject {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private(set) var isAuthorized = false
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        updateAuthorizationStatus()
    }

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "locationEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "locationEnabled") }
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func currentLocation() async -> CLLocation? {
        guard isEnabled, isAuthorized, continuation == nil else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func reverseGeocode(_ location: CLLocation) async -> String? {
        let placemarks = try? await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks?.first else { return nil }

        var parts: [String] = []
        if let name = placemark.name { parts.append(name) }
        if let locality = placemark.locality, !parts.contains(locality) {
            parts.append(locality)
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private func updateAuthorizationStatus() {
        let status = manager.authorizationStatus
        isAuthorized = status == .authorizedWhenInUse || status == .authorizedAlways
    }
}

extension LocationService: @preconcurrency CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.first)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in updateAuthorizationStatus() }
    }
}
