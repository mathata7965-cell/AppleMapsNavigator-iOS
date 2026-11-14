import Foundation
import SwiftUI
import CoreLocation

/// 地點分類（對應 iOS 地圖快選膠囊與 OpenStreetMap / MapKit 搜尋標籤）
enum PlaceCategory: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case restaurant
    case cafe
    case gasStation
    case parking
    case evCharger
    case convenience
    case hospital
    case attraction

    var id: String { rawValue }

    var title: String {
        switch self {
        case .restaurant: return "餐廳"
        case .cafe: return "咖啡廳"
        case .gasStation: return "加油站"
        case .parking: return "停車場"
        case .evCharger: return "充電站"
        case .convenience: return "便利商店"
        case .hospital: return "醫療院所"
        case .attraction: return "熱門景點"
        }
    }

    var symbolName: String {
        switch self {
        case .restaurant: return "fork.knife"
        case .cafe: return "cup.and.saucer.fill"
        case .gasStation: return "fuelpump.fill"
        case .parking: return "parkingsign"
        case .evCharger: return "bolt.car.fill"
        case .convenience: return "bag.fill"
        case .hospital: return "cross.case.fill"
        case .attraction: return "star.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .restaurant: return Color(red: 1.0, green: 0.45, blue: 0.22)
        case .cafe: return Color(red: 0.65, green: 0.42, blue: 0.24)
        case .gasStation: return Color(red: 0.16, green: 0.56, blue: 0.98)
        case .parking: return Color(red: 0.25, green: 0.47, blue: 0.96)
        case .evCharger: return Color(red: 0.18, green: 0.78, blue: 0.45)
        case .convenience: return Color(red: 0.95, green: 0.62, blue: 0.12)
        case .hospital: return Color(red: 0.96, green: 0.24, blue: 0.30)
        case .attraction: return Color(red: 0.98, green: 0.35, blue: 0.52)
        }
    }

    var gradientColors: [Color] {
        [accentColor, accentColor.opacity(0.75)]
    }

    /// 用於 OpenStreetMap Nominatim 查詢的關鍵字
    var osmSearchQuery: String {
        switch self {
        case .restaurant: return "restaurant 餐廳"
        case .cafe: return "cafe coffee 咖啡"
        case .gasStation: return "fuel gas station 加油站"
        case .parking: return "parking 停車場"
        case .evCharger: return "charging station 充電站"
        case .convenience: return "convenience store 便利商店"
        case .hospital: return "hospital clinic 醫院"
        case .attraction: return "attraction landmark 景點"
        }
    }
}

/// 常用收藏類型（住家、公司、自訂收藏）
enum FavoriteSlot: String, Codable, Hashable, Sendable {
    case home
    case work
    case custom

    var badgeSymbol: String {
        switch self {
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .custom: return "heart.fill"
        }
    }

    var badgeColor: Color {
        switch self {
        case .home: return Color(red: 0.14, green: 0.68, blue: 0.98)
        case .work: return Color(red: 0.58, green: 0.45, blue: 0.96)
        case .custom: return Color(red: 0.98, green: 0.30, blue: 0.45)
        }
    }
}

/// 地點資料模型
struct PlaceItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var subtitle: String
    var address: String
    var latitude: Double
    var longitude: Double
    var category: PlaceCategory
    var rating: Double?
    var phoneNumber: String?
    var isFavorite: Bool
    var favoriteSlot: FavoriteSlot?
    var sourceLabel: String

    init(
        id: UUID = UUID(),
        name: String,
        subtitle: String,
        address: String,
        latitude: Double,
        longitude: Double,
        category: PlaceCategory,
        rating: Double? = nil,
        phoneNumber: String? = nil,
        isFavorite: Bool = false,
        favoriteSlot: FavoriteSlot? = nil,
        sourceLabel: String = "OpenStreetMap"
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
        self.rating = rating
        self.phoneNumber = phoneNumber
        self.isFavorite = isFavorite
        self.favoriteSlot = favoriteSlot
        self.sourceLabel = sourceLabel
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distanceMeters(from origin: CLLocationCoordinate2D) -> Double {
        let a = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let b = CLLocation(latitude: latitude, longitude: longitude)
        return a.distance(from: b)
    }

    func formattedDistance(from origin: CLLocationCoordinate2D) -> String {
        let meters = distanceMeters(from: origin)
        if meters < 1000 {
            return String(format: "%.0f 公尺", meters)
        } else {
            return String(format: "%.1f 公里", meters / 1000.0)
        }
    }
}

extension PlaceItem {
    /// 台北信義區 / 市中心預設精選地點（確保離線與首次啟動立即具備完整互動體驗）
    static let curatedTaipeiPOIs: [PlaceItem] = [
        PlaceItem(
            name: "台北 101 觀景台",
            subtitle: "地標建築・信義區",
            address: "台北市信義區信義路五段7號",
            latitude: 25.033964,
            longitude: 121.564468,
            category: .attraction,
            rating: 4.8,
            phoneNumber: "02-8101-8898",
            isFavorite: true,
            favoriteSlot: .custom,
            sourceLabel: "精選地標"
        ),
        PlaceItem(
            name: "鼎泰豐 信義店",
            subtitle: "經典台式料理・餐廳",
            address: "台北市大安區信義路二段194號",
            latitude: 25.033493,
            longitude: 121.529950,
            category: .restaurant,
            rating: 4.9,
            phoneNumber: "02-2321-8928",
            sourceLabel: "精選餐廳"
        ),
        PlaceItem(
            name: "Simple Kaffa 興波咖啡",
            subtitle: "冠軍精品咖啡・華山",
            address: "台北市中正區忠孝東路二段27號",
            latitude: 25.044225,
            longitude: 121.527688,
            category: .cafe,
            rating: 4.8,
            phoneNumber: "02-3322-1888",
            sourceLabel: "精選咖啡"
        ),
        PlaceItem(
            name: "國父紀念館",
            subtitle: "文化園區・信義區",
            address: "台北市信義區仁愛路四段505號",
            latitude: 25.040255,
            longitude: 121.560187,
            category: .attraction,
            rating: 4.7,
            phoneNumber: "02-2758-8008",
            sourceLabel: "精選地標"
        ),
        PlaceItem(
            name: "台灣中油 信義加油站",
            subtitle: "24 小時營業・自助加油",
            address: "台北市信義區松仁路91號旁",
            latitude: 25.035820,
            longitude: 121.568340,
            category: .gasStation,
            rating: 4.3,
            sourceLabel: "OSM"
        ),
        PlaceItem(
            name: "信義廣場地下停車場",
            subtitle: "24 小時・含電動車充電樁",
            address: "台北市信義區信義路五段11號B1",
            latitude: 25.032420,
            longitude: 121.564890,
            category: .parking,
            rating: 4.4,
            sourceLabel: "OSM"
        ),
        PlaceItem(
            name: "Tesla 超級充電站・台北 101",
            subtitle: "V3 超充 250kW・8 席",
            address: "台北市信義區市府路45號 B3",
            latitude: 25.034250,
            longitude: 121.563920,
            category: .evCharger,
            rating: 4.7,
            sourceLabel: "OSM"
        ),
        PlaceItem(
            name: "7-ELEVEN 信義威秀門市",
            subtitle: "24 小時・便利商店",
            address: "台北市信義區松壽路20號",
            latitude: 25.035512,
            longitude: 121.566912,
            category: .convenience,
            rating: 4.5,
            sourceLabel: "OSM"
        ),
        PlaceItem(
            name: "臺北醫學大學附設醫院",
            subtitle: "急診中心・醫療院所",
            address: "台北市信義區吳興街252號",
            latitude: 25.026850,
            longitude: 121.563320,
            category: .hospital,
            rating: 4.4,
            phoneNumber: "02-2737-2181",
            sourceLabel: "OSM"
        ),
        PlaceItem(
            name: "象山親山步道入口",
            subtitle: "夜景步道・信義區",
            address: "台北市信義區信義路五段150巷22弄",
            latitude: 25.027380,
            longitude: 121.571040,
            category: .attraction,
            rating: 4.8,
            sourceLabel: "精選地標"
        ),
        PlaceItem(
            name: "松山文創園區",
            subtitle: "藝文展覽・信義區",
            address: "台北市信義區光復南路133號",
            latitude: 25.043910,
            longitude: 121.560510,
            category: .attraction,
            rating: 4.7,
            sourceLabel: "精選地標"
        ),
        PlaceItem(
            name: "欣葉台菜 信義新天地 A9",
            subtitle: "精緻台菜・餐廳",
            address: "台北市信義區松壽路9號8樓",
            latitude: 25.036380,
            longitude: 121.566840,
            category: .restaurant,
            rating: 4.6,
            phoneNumber: "02-8786-1234",
            sourceLabel: "精選餐廳"
        )
    ]

    static let defaultFavorites: [PlaceItem] = [
        PlaceItem(
            name: "住家",
            subtitle: "大安區・大安森林公園旁",
            address: "台北市大安區新生南路二段1號",
            latitude: 25.029750,
            longitude: 121.535610,
            category: .attraction,
            isFavorite: true,
            favoriteSlot: .home,
            sourceLabel: "我的地點"
        ),
        PlaceItem(
            name: "公司",
            subtitle: "南港軟體園區",
            address: "台北市南港區三重路19-10號",
            latitude: 25.057420,
            longitude: 121.612640,
            category: .attraction,
            isFavorite: true,
            favoriteSlot: .work,
            sourceLabel: "我的地點"
        ),
        curatedTaipeiPOIs[0]
    ]
}
