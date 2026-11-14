import Foundation
import CoreLocation
import Observation

/// 位置管理器：整合 CoreLocation 即時定位與模擬器預設座標（台北 101 信義區）
@Observable
@MainActor
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    /// 預設基準位置：台北 101 / 信義商圈
    static let defaultCoordinate = CLLocationCoordinate2D(latitude: 25.033964, longitude: 121.564468)

    private(set) var currentLocation: CLLocation?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var isUsingSimulatedDefault: Bool = true

    var effectiveCoordinate: CLLocationCoordinate2D {
        currentLocation?.coordinate ?? Self.defaultCoordinate
    }

    var effectivePlaceItem: PlaceItem {
        PlaceItem(
            name: "目前位置",
            subtitle: isUsingSimulatedDefault ? "信義區・模擬位置" : "GPS 即時定位",
            address: "台北市信義區信義路五段",
            latitude: effectiveCoordinate.latitude,
            longitude: effectiveCoordinate.longitude,
            category: .attraction,
            sourceLabel: "GPS"
        )
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermissionAndStartUpdating() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func refreshOneShotLocation() {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else {
            requestPermissionAndStartUpdating()
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.currentLocation = latest
            self.isUsingSimulatedDefault = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.currentLocation == nil {
                self.isUsingSimulatedDefault = true
            }
        }
    }
}
