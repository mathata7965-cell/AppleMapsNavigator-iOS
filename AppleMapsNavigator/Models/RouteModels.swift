import Foundation
import MapKit
import CoreLocation

/// 交通方式（支援 OSRM 多模式與 MapKit 備援）
enum TransportMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case driving
    case walking
    case cycling

    var id: String { rawValue }

    var title: String {
        switch self {
        case .driving: return "開車"
        case .walking: return "步行"
        case .cycling: return "單車"
        }
    }

    var symbolName: String {
        switch self {
        case .driving: return "car.fill"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        }
    }

    /// OSRM REST API profile 路徑參數
    var osrmProfile: String {
        switch self {
        case .driving: return "driving"
        case .walking: return "foot"
        case .cycling: return "bike"
        }
    }

    var mkTransportType: MKDirectionsTransportType {
        switch self {
        case .driving: return .automobile
        case .walking: return .walking
        case .cycling: return .walking
        }
    }

    /// 模擬導航基準速度（公尺/秒）
    var defaultSimulationSpeedMPS: Double {
        switch self {
        case .driving: return 13.5   // 約 48 km/h
        case .walking: return 1.45   // 約 5.2 km/h
        case .cycling: return 5.2    // 約 18.7 km/h
        }
    }

    /// 預估時間微調係數（公共 OSRM demo server 步行/單車常共用路網，做合理擬真校正）
    var fallbackAverageSpeedMPS: Double {
        switch self {
        case .driving: return 10.5
        case .walking: return 1.35
        case .cycling: return 4.4
        }
    }
}

/// 轉彎指示類型
enum ManeuverType: String, Codable, Hashable, Sendable {
    case straight
    case turnLeft
    case turnRight
    case slightLeft
    case slightRight
    case sharpLeft
    case sharpRight
    case uTurn
    case roundabout
    case depart
    case arrive

    var symbolName: String {
        switch self {
        case .straight: return "arrow.up"
        case .turnLeft: return "arrow.turn.up.left"
        case .turnRight: return "arrow.turn.up.right"
        case .slightLeft: return "arrow.up.left"
        case .slightRight: return "arrow.up.right"
        case .sharpLeft: return "arrow.turn.down.left"
        case .sharpRight: return "arrow.turn.down.right"
        case .uTurn: return "arrow.uturn.left"
        case .roundabout: return "arrow.triangle.turn.up.right.circle"
        case .depart: return "location.north.fill"
        case .arrive: return "flag.checkered"
        }
    }

    var shortActionText: String {
        switch self {
        case .straight: return "直行"
        case .turnLeft: return "左轉"
        case .turnRight: return "右轉"
        case .slightLeft: return "靠左行駛"
        case .slightRight: return "靠右行駛"
        case .sharpLeft: return "急左轉"
        case .sharpRight: return "急右轉"
        case .uTurn: return "迴轉"
        case .roundabout: return "進入圓環"
        case .depart: return "出發"
        case .arrive: return "抵達目的地"
        }
    }

    /// 依目前轉彎指示產生高德風格「車道級導航」配置
    var laneGuidanceItems: [LaneItem] {
        switch self {
        case .turnLeft, .sharpLeft:
            return [
                LaneItem(direction: .left, isRecommended: true),
                LaneItem(direction: .left, isRecommended: true),
                LaneItem(direction: .straight, isRecommended: false),
                LaneItem(direction: .right, isRecommended: false)
            ]
        case .slightLeft:
            return [
                LaneItem(direction: .left, isRecommended: true),
                LaneItem(direction: .slightLeft, isRecommended: true),
                LaneItem(direction: .straight, isRecommended: false),
                LaneItem(direction: .right, isRecommended: false)
            ]
        case .turnRight, .sharpRight:
            return [
                LaneItem(direction: .left, isRecommended: false),
                LaneItem(direction: .straight, isRecommended: false),
                LaneItem(direction: .right, isRecommended: true),
                LaneItem(direction: .right, isRecommended: true)
            ]
        case .slightRight:
            return [
                LaneItem(direction: .left, isRecommended: false),
                LaneItem(direction: .straight, isRecommended: false),
                LaneItem(direction: .slightRight, isRecommended: true),
                LaneItem(direction: .right, isRecommended: true)
            ]
        case .uTurn:
            return [
                LaneItem(direction: .uTurn, isRecommended: true),
                LaneItem(direction: .straight, isRecommended: false),
                LaneItem(direction: .straight, isRecommended: false),
                LaneItem(direction: .right, isRecommended: false)
            ]
        case .roundabout:
            return [
                LaneItem(direction: .slightLeft, isRecommended: false),
                LaneItem(direction: .straight, isRecommended: true),
                LaneItem(direction: .slightRight, isRecommended: true)
            ]
        case .straight, .depart, .arrive:
            return [
                LaneItem(direction: .left, isRecommended: false),
                LaneItem(direction: .straight, isRecommended: true),
                LaneItem(direction: .straight, isRecommended: true),
                LaneItem(direction: .right, isRecommended: false)
            ]
        }
    }
}

/// 車道方向類型
enum LaneDirection: String, Sendable, Hashable {
    case left
    case slightLeft
    case straight
    case slightRight
    case right
    case uTurn

    var symbolName: String {
        switch self {
        case .left: return "arrow.turn.up.left"
        case .slightLeft: return "arrow.up.left"
        case .straight: return "arrow.up"
        case .slightRight: return "arrow.up.right"
        case .right: return "arrow.turn.up.right"
        case .uTurn: return "arrow.uturn.left"
        }
    }
}

/// 車道級引導單一車道項目
struct LaneItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    let direction: LaneDirection
    let isRecommended: Bool
}

/// 紅綠燈讀秒階段
enum TrafficLightPhase: String, Sendable {
    case red
    case green
    case yellow

    var label: String {
        switch self {
        case .red: return "紅燈"
        case .green: return "綠燈"
        case .yellow: return "黃燈"
        }
    }
}

/// 沿途測速照相 / 電子眼點位
struct SpeedCameraPoint: Identifiable, Hashable, @unchecked Sendable {
    let id: UUID
    let name: String
    let speedLimitKMH: Int
    let distanceAlongRouteMeters: Double
    let coordinate: CLLocationCoordinate2D

    init(
        id: UUID = UUID(),
        name: String,
        speedLimitKMH: Int,
        distanceAlongRouteMeters: Double,
        coordinate: CLLocationCoordinate2D
    ) {
        self.id = id
        self.name = name
        self.speedLimitKMH = speedLimitKMH
        self.distanceAlongRouteMeters = distanceAlongRouteMeters
        self.coordinate = coordinate
    }

    static func == (lhs: SpeedCameraPoint, rhs: SpeedCameraPoint) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// 測速照相即時預警資訊
struct SpeedCameraAlert: @unchecked Sendable {
    let camera: SpeedCameraPoint
    let distanceAheadMeters: Double
}

/// 單步導航指引
struct RouteStep: Identifiable, Hashable, @unchecked Sendable {
    let id: UUID
    let instruction: String
    let roadName: String
    let distanceMeters: Double
    let durationSeconds: Double
    let maneuverType: ManeuverType
    let maneuverCoordinate: CLLocationCoordinate2D

    init(
        id: UUID = UUID(),
        instruction: String,
        roadName: String,
        distanceMeters: Double,
        durationSeconds: Double,
        maneuverType: ManeuverType,
        maneuverCoordinate: CLLocationCoordinate2D
    ) {
        self.id = id
        self.instruction = instruction
        self.roadName = roadName
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.maneuverType = maneuverType
        self.maneuverCoordinate = maneuverCoordinate
    }

    static func == (lhs: RouteStep, rhs: RouteStep) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// 完整規劃路線方案
struct RouteOption: Identifiable, Hashable, @unchecked Sendable {
    let id: UUID
    let summaryTitle: String
    let detailTag: String
    let transportMode: TransportMode
    let distanceMeters: Double
    let durationSeconds: Double
    let coordinates: [CLLocationCoordinate2D]
    let steps: [RouteStep]
    let isRecommended: Bool
    let engineSource: String

    init(
        id: UUID = UUID(),
        summaryTitle: String,
        detailTag: String,
        transportMode: TransportMode,
        distanceMeters: Double,
        durationSeconds: Double,
        coordinates: [CLLocationCoordinate2D],
        steps: [RouteStep],
        isRecommended: Bool,
        engineSource: String
    ) {
        self.id = id
        self.summaryTitle = summaryTitle
        self.detailTag = detailTag
        self.transportMode = transportMode
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.coordinates = coordinates
        self.steps = steps
        self.isRecommended = isRecommended
        self.engineSource = engineSource
    }

    var formattedDuration: String {
        RouteFormatting.formatDuration(seconds: durationSeconds)
    }

    var formattedDistance: String {
        RouteFormatting.formatDistance(meters: distanceMeters)
    }

    var estimatedArrivalTimeText: String {
        let eta = Date().addingTimeInterval(durationSeconds)
        return RouteFormatting.formatClockTime(eta)
    }

    static func == (lhs: RouteOption, rhs: RouteOption) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum RouteFormatting {
    static func formatDistance(meters: Double) -> String {
        if meters < 50 {
            return String(format: "%.0f 公尺", max(0, meters))
        } else if meters < 1000 {
            let rounded = (meters / 10.0).rounded() * 10.0
            return String(format: "%.0f 公尺", rounded)
        } else if meters < 10000 {
            return String(format: "%.1f 公里", meters / 1000.0)
        } else {
            return String(format: "%.0f 公里", meters / 1000.0)
        }
    }

    static func formatCompactDistance(meters: Double) -> String {
        if meters < 1000 {
            let rounded = max(10, (meters / 10.0).rounded() * 10.0)
            return String(format: "%.0f m", rounded)
        } else {
            return String(format: "%.1f km", meters / 1000.0)
        }
    }

    static func formatDuration(seconds: Double) -> String {
        let totalMinutes = max(1, Int((seconds / 60.0).rounded()))
        if totalMinutes < 60 {
            return "\(totalMinutes) 分鐘"
        } else {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            return mins == 0 ? "\(hours) 小時" : "\(hours) 小時 \(mins) 分"
        }
    }

    static func formatClockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
