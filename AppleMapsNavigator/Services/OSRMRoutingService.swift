import Foundation
import MapKit
import CoreLocation

/// 路線規劃服務：優先使用開源 OSRM (Open Source Routing Machine)，並自動備援 MapKit 與離線幾何路線
actor OSRMRoutingService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 計算多模式與多方案路線（含替代路線與詳細步驟）
    func calculateRoutes(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        mode: TransportMode
    ) async -> [RouteOption] {
        // 1. 嘗試 OSRM 開源免費 API
        if let osrmRoutes = await fetchOSRMRoutes(from: origin, to: destination, mode: mode),
           !osrmRoutes.isEmpty {
            return osrmRoutes
        }

        // 2. 備援：Apple MKDirections
        if let mkRoutes = await fetchMKDirectionsRoutes(from: origin, to: destination, mode: mode),
           !mkRoutes.isEmpty {
            return mkRoutes
        }

        // 3. 最終離線保底：平滑分段幾何模擬路線，確保任何網路環境皆可完整體驗導航
        return [buildOfflineFallbackRoute(from: origin, to: destination, mode: mode)]
    }

    // MARK: - OSRM REST API

    private func fetchOSRMRoutes(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        mode: TransportMode
    ) async -> [RouteOption]? {
        let coordPair = "\(origin.longitude),\(origin.latitude);\(destination.longitude),\(destination.latitude)"
        var components = URLComponents(string: "https://router.project-osrm.org/route/v1/\(mode.osrmProfile)/\(coordPair)")
        components?.queryItems = [
            URLQueryItem(name: "alternatives", value: "true"),
            URLQueryItem(name: "steps", value: "true"),
            URLQueryItem(name: "geometries", value: "geojson"),
            URLQueryItem(name: "overview", value: "full")
        ]

        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 9.0)
        request.setValue("AppleMapsNavigator-iOS/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }

            let decoded = try JSONDecoder().decode(OSRMRouteResponse.self, from: data)
            guard decoded.code.lowercased() == "ok" else { return nil }

            return decoded.routes.enumerated().compactMap { index, route in
                convertOSRMRoute(route, index: index, mode: mode)
            }
        } catch {
            return nil
        }
    }

    private func convertOSRMRoute(
        _ osrmRoute: OSRMRoute,
        index: Int,
        mode: TransportMode
    ) -> RouteOption? {
        let coordinates = osrmRoute.geometry.coordinates.compactMap { pair -> CLLocationCoordinate2D? in
            guard pair.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }

        guard coordinates.count >= 2 else { return nil }

        let rawSteps = osrmRoute.legs.flatMap { $0.steps }
        let steps: [RouteStep] = rawSteps.map { step in
            let maneuverCoord: CLLocationCoordinate2D
            if step.maneuver.location.count >= 2 {
                maneuverCoord = CLLocationCoordinate2D(
                    latitude: step.maneuver.location[1],
                    longitude: step.maneuver.location[0]
                )
            } else {
                maneuverCoord = coordinates[0]
            }

            let maneuverType = mapOSRMManeuver(
                type: step.maneuver.type,
                modifier: step.maneuver.modifier
            )
            let roadName = step.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let localizedInstruction = buildChineseInstruction(
                type: step.maneuver.type,
                modifier: step.maneuver.modifier,
                maneuverType: maneuverType,
                roadName: roadName,
                exitNumber: step.maneuver.exit
            )

            return RouteStep(
                instruction: localizedInstruction,
                roadName: roadName.isEmpty ? "前方道路" : roadName,
                distanceMeters: step.distance,
                durationSeconds: step.duration,
                maneuverType: maneuverType,
                maneuverCoordinate: maneuverCoord
            )
        }

        // 公共 OSRM server 對 foot/bike 有時會以預設路網速度估算，確保步行/單車預估時間合理
        let adjustedDuration = normalizeDuration(
            rawDuration: osrmRoute.duration,
            distance: osrmRoute.distance,
            mode: mode
        )

        let title = index == 0 ? "最快路線" : "替代路線 \(index)"
        let tag = index == 0 ? "建議・即時路網" : "順暢替代"

        return RouteOption(
            summaryTitle: title,
            detailTag: tag,
            transportMode: mode,
            distanceMeters: osrmRoute.distance,
            durationSeconds: adjustedDuration,
            coordinates: coordinates,
            steps: steps,
            isRecommended: index == 0,
            engineSource: "OSRM 開源導航"
        )
    }

    private func normalizeDuration(rawDuration: Double, distance: Double, mode: TransportMode) -> Double {
        guard distance > 0 else { return max(60, rawDuration) }
        let impliedSpeed = distance / max(1, rawDuration)
        switch mode {
        case .driving:
            return rawDuration
        case .walking:
            // 若 OSRM 回傳步行速度高於 2.2 m/s (約 8 km/h)，代表共用車道速度，改採步行均速
            return impliedSpeed > 2.2 ? (distance / mode.fallbackAverageSpeedMPS) : rawDuration
        case .cycling:
            return impliedSpeed > 7.5 ? (distance / mode.fallbackAverageSpeedMPS) : rawDuration
        }
    }

    private func mapOSRMManeuver(type: String, modifier: String?) -> ManeuverType {
        switch type {
        case "depart":
            return .depart
        case "arrive":
            return .arrive
        case "roundabout", "rotary", "exit roundabout":
            return .roundabout
        default:
            switch modifier {
            case "left": return .turnLeft
            case "right": return .turnRight
            case "slight left": return .slightLeft
            case "slight right": return .slightRight
            case "sharp left": return .sharpLeft
            case "sharp right": return .sharpRight
            case "uturn": return .uTurn
            default: return .straight
            }
        }
    }

    private func buildChineseInstruction(
        type: String,
        modifier: String?,
        maneuverType: ManeuverType,
        roadName: String,
        exitNumber: Int?
    ) -> String {
        let roadDisplay = roadName.isEmpty ? "" : "進入 \(roadName)"
        switch type {
        case "depart":
            return roadName.isEmpty ? "沿著目前道路出發" : "沿 \(roadName) 出發"
        case "arrive":
            return "抵達目的地"
        case "roundabout", "rotary":
            if let exit = exitNumber {
                return "進入圓環後由第 \(exit) 個出口駛出\(roadDisplay)"
            }
            return "進入圓環\(roadDisplay)"
        case "merge":
            return "匯入\(roadName.isEmpty ? "主線車道" : roadName)"
        case "fork":
            let side = (modifier?.contains("left") == true) ? "靠左" : "靠右"
            return "在前方岔路\(side)行駛\(roadDisplay)"
        default:
            if roadName.isEmpty {
                return maneuverType.shortActionText
            }
            return "\(maneuverType.shortActionText)\(roadDisplay)"
        }
    }

    // MARK: - Apple MKDirections 備援

    @MainActor
    private func fetchMKDirectionsRoutes(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        mode: TransportMode
    ) async -> [RouteOption]? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = mode.mkTransportType
        request.requestsAlternateRoutes = true

        do {
            let response = try await MKDirections(request: request).calculate()
            return response.routes.enumerated().map { index, mkRoute in
                let coords = mkRoute.polyline.coordinatesArray
                let steps = mkRoute.steps
                    .filter { !$0.instructions.isEmpty }
                    .map { mkStep in
                        let stepCoord = mkStep.polyline.coordinatesArray.first ?? origin
                        return RouteStep(
                            instruction: mkStep.instructions,
                            roadName: mkStep.instructions,
                            distanceMeters: mkStep.distance,
                            durationSeconds: mkStep.distance / mode.fallbackAverageSpeedMPS,
                            maneuverType: inferManeuverFromText(mkStep.instructions),
                            maneuverCoordinate: stepCoord
                        )
                    }

                let duration = mode == .cycling
                    ? (mkRoute.distance / mode.fallbackAverageSpeedMPS)
                    : mkRoute.expectedTravelTime

                return RouteOption(
                    summaryTitle: index == 0 ? "最快路線" : "替代路線 \(index)",
                    detailTag: mkRoute.name.isEmpty ? "MapKit 推薦" : mkRoute.name,
                    transportMode: mode,
                    distanceMeters: mkRoute.distance,
                    durationSeconds: duration,
                    coordinates: coords,
                    steps: steps,
                    isRecommended: index == 0,
                    engineSource: "MapKit 備援"
                )
            }
        } catch {
            return nil
        }
    }

    private func inferManeuverFromText(_ text: String) -> ManeuverType {
        let lower = text.lowercased()
        if lower.contains("左") || lower.contains("left") { return .turnLeft }
        if lower.contains("右") || lower.contains("right") { return .turnRight }
        if lower.contains("圓環") || lower.contains("roundabout") { return .roundabout }
        if lower.contains("抵達") || lower.contains("arrive") { return .arrive }
        return .straight
    }

    // MARK: - 離線幾何路線保底

    private func buildOfflineFallbackRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        mode: TransportMode
    ) -> RouteOption {
        let midPoint = CLLocationCoordinate2D(
            latitude: origin.latitude,
            longitude: destination.longitude
        )

        var points: [CLLocationCoordinate2D] = []
        let leg1Steps = 10
        for i in 0...leg1Steps {
            let t = Double(i) / Double(leg1Steps)
            points.append(CLLocationCoordinate2D(
                latitude: origin.latitude + (midPoint.latitude - origin.latitude) * t,
                longitude: origin.longitude + (midPoint.longitude - origin.longitude) * t
            ))
        }
        let leg2Steps = 10
        for i in 1...leg2Steps {
            let t = Double(i) / Double(leg2Steps)
            points.append(CLLocationCoordinate2D(
                latitude: midPoint.latitude + (destination.latitude - midPoint.latitude) * t,
                longitude: midPoint.longitude + (destination.longitude - midPoint.longitude) * t
            ))
        }

        let leg1Dist = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(from: CLLocation(latitude: midPoint.latitude, longitude: midPoint.longitude))
        let leg2Dist = CLLocation(latitude: midPoint.latitude, longitude: midPoint.longitude)
            .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
        let totalDist = max(200, leg1Dist + leg2Dist)
        let totalDuration = totalDist / mode.fallbackAverageSpeedMPS

        let steps = [
            RouteStep(
                instruction: "沿目前道路出發前往主要幹道",
                roadName: "目前道路",
                distanceMeters: leg1Dist,
                durationSeconds: leg1Dist / mode.fallbackAverageSpeedMPS,
                maneuverType: .depart,
                maneuverCoordinate: origin
            ),
            RouteStep(
                instruction: "向右轉進入前方大道",
                roadName: "前方大道",
                distanceMeters: leg2Dist,
                durationSeconds: leg2Dist / mode.fallbackAverageSpeedMPS,
                maneuverType: .turnRight,
                maneuverCoordinate: midPoint
            ),
            RouteStep(
                instruction: "抵達目的地",
                roadName: "目的地",
                distanceMeters: 0,
                durationSeconds: 0,
                maneuverType: .arrive,
                maneuverCoordinate: destination
            )
        ]

        return RouteOption(
            summaryTitle: "模擬建議路線",
            detailTag: "離線估算路網",
            transportMode: mode,
            distanceMeters: totalDist,
            durationSeconds: totalDuration,
            coordinates: points,
            steps: steps,
            isRecommended: true,
            engineSource: "離線模擬引擎"
        )
    }
}

// MARK: - MKPolyline Helper

private extension MKPolyline {
    var coordinatesArray: [CLLocationCoordinate2D] {
        var coords = Array(repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

// MARK: - OSRM JSON DTOs

private struct OSRMRouteResponse: Decodable {
    let code: String
    let routes: [OSRMRoute]
}

private struct OSRMRoute: Decodable {
    let distance: Double
    let duration: Double
    let geometry: OSRMGeometry
    let legs: [OSRMLeg]
}

private struct OSRMGeometry: Decodable {
    let coordinates: [[Double]]
}

private struct OSRMLeg: Decodable {
    let steps: [OSRMStep]
}

private struct OSRMStep: Decodable {
    let distance: Double
    let duration: Double
    let name: String
    let maneuver: OSRMManeuver
}

private struct OSRMManeuver: Decodable {
    let type: String
    let modifier: String?
    let location: [Double]
    let exit: Int?
}
