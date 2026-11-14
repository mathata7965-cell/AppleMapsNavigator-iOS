import SwiftUI
import MapKit

/// 開源 OpenStreetMap 圖磚覆蓋橋接視圖（切換至「OSM 圖磚」圖層時啟用）
struct OSMTileOverlayView: UIViewRepresentable {
    let centerCoordinate: CLLocationCoordinate2D
    let places: [PlaceItem]
    let selectedRoute: RouteOption?
    let alternativeRoutes: [RouteOption]
    let vehicleCoordinate: CLLocationCoordinate2D?
    let onSelectPlace: (PlaceItem) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectPlace: onSelectPlace)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = false

        let osmOverlay = MKTileOverlay(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
        osmOverlay.canReplaceMapContent = true
        osmOverlay.maximumZ = 19
        mapView.addOverlay(osmOverlay, level: .aboveLabels)

        let region = MKCoordinateRegion(
            center: centerCoordinate,
            latitudinalMeters: 2600,
            longitudinalMeters: 2600
        )
        mapView.setRegion(region, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onSelectPlace = onSelectPlace
        context.coordinator.placesByTitle = Dictionary(
            uniqueKeysWithValues: places.map { ($0.name, $0) }
        )

        // 更新非圖磚的路線覆蓋層
        let nonTileOverlays = mapView.overlays.filter { !($0 is MKTileOverlay) }
        mapView.removeOverlays(nonTileOverlays)

        for altRoute in alternativeRoutes where altRoute.id != selectedRoute?.id {
            if altRoute.coordinates.count >= 2 {
                let poly = TaggedPolyline(coordinates: altRoute.coordinates, count: altRoute.coordinates.count)
                poly.isPrimary = false
                mapView.addOverlay(poly, level: .aboveRoads)
            }
        }

        if let selectedRoute, selectedRoute.coordinates.count >= 2 {
            let poly = TaggedPolyline(coordinates: selectedRoute.coordinates, count: selectedRoute.coordinates.count)
            poly.isPrimary = true
            mapView.addOverlay(poly, level: .aboveRoads)
        }

        // 更新地標標記
        let existingNonUser = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(existingNonUser)

        let placeAnnotations: [MKPointAnnotation] = places.map { place in
            let ann = MKPointAnnotation()
            ann.title = place.name
            ann.subtitle = place.subtitle
            ann.coordinate = place.coordinate
            return ann
        }
        mapView.addAnnotations(placeAnnotations)

        if let vehicleCoordinate {
            let carAnn = MKPointAnnotation()
            carAnn.title = "導航車輛"
            carAnn.coordinate = vehicleCoordinate
            mapView.addAnnotation(carAnn)
        }

        // 若中心點有明顯移動則平滑跟隨
        let currentCenter = mapView.centerCoordinate
        let deltaLat = abs(currentCenter.latitude - centerCoordinate.latitude)
        let deltaLon = abs(currentCenter.longitude - centerCoordinate.longitude)
        if deltaLat > 0.0025 || deltaLon > 0.0025 {
            mapView.setCenter(centerCoordinate, animated: true)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onSelectPlace: (PlaceItem) -> Void
        var placesByTitle: [String: PlaceItem] = [:]

        init(onSelectPlace: @escaping (PlaceItem) -> Void) {
            self.onSelectPlace = onSelectPlace
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            if let polyline = overlay as? TaggedPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = polyline.isPrimary
                    ? UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)
                    : UIColor.systemBlue.withAlphaComponent(0.35)
                renderer.lineWidth = polyline.isPrimary ? 7 : 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: any MKAnnotation) {
            guard let title = annotation.title ?? nil, let place = placesByTitle[title] else { return }
            onSelectPlace(place)
        }
    }
}

private final class TaggedPolyline: MKPolyline {
    var isPrimary: Bool = true
}
