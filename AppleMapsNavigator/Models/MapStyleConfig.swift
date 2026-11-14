import Foundation
import SwiftUI
import MapKit

/// App 深淺色外觀模式
enum AppThemeMode: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟隨系統"
        case .light: return "日間淺色"
        case .dark: return "夜間深色"
        }
    }

    var symbolName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// 地圖圖層顯示風格
enum MapDisplayStyle: String, CaseIterable, Identifiable, Codable {
    case appleStandard3D
    case appleHybrid
    case openStreetMap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleStandard3D: return "標準 3D"
        case .appleHybrid: return "衛星混合"
        case .openStreetMap: return "OSM 圖磚"
        }
    }

    var subtitle: String {
        switch self {
        case .appleStandard3D: return "Apple 3D 建築與真實地形"
        case .appleHybrid: return "高解析空拍影像與路網"
        case .openStreetMap: return "開源 OpenStreetMap 街道圖層"
        }
    }

    var symbolName: String {
        switch self {
        case .appleStandard3D: return "map.fill"
        case .appleHybrid: return "globe.asia.australia.fill"
        case .openStreetMap: return "square.stack.3d.up.fill"
        }
    }

    var mapKitStyle: MapStyle {
        switch self {
        case .appleStandard3D:
            return .standard(
                elevation: .realistic,
                emphasis: .automatic,
                pointsOfInterest: .including([
                    .restaurant, .cafe, .gasStation, .parking,
                    .evCharger, .hospital, .park, .publicTransport
                ]),
                showsTraffic: true
            )
        case .appleHybrid:
            return .hybrid(elevation: .realistic, showsTraffic: true)
        case .openStreetMap:
            return .standard(elevation: .flat)
        }
    }
}

/// 畫面主模式狀態
enum NavigatorAppMode: Equatable {
    case explore
    case placeDetail(PlaceItem)
    case routePlanning
    case navigating

    static func == (lhs: NavigatorAppMode, rhs: NavigatorAppMode) -> Bool {
        switch (lhs, rhs) {
        case (.explore, .explore):
            return true
        case (.placeDetail(let a), .placeDetail(let b)):
            return a.id == b.id
        case (.routePlanning, .routePlanning):
            return true
        case (.navigating, .navigating):
            return true
        default:
            return false
        }
    }
}

/// 底部抽屜高度吸附點
enum SheetDetent: CaseIterable, Equatable {
    case collapsed
    case medium
    case expanded
}
