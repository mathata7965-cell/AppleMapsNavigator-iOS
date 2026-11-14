import Foundation
import MapKit
import CoreLocation

/// 雙引擎地點搜尋服務：OpenStreetMap Nominatim + Apple MKLocalSearch + 本地精選 POI
actor PlaceSearchService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 關鍵字即時搜尋
    func searchPlaces(
        query: String,
        near center: CLLocationCoordinate2D,
        categoryHint: PlaceCategory? = nil
    ) async -> [PlaceItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return PlaceItem.curatedTaipeiPOIs
        }

        // 先從本地精選地點做即時模糊比對
        let localMatches = PlaceItem.curatedTaipeiPOIs.filter { item in
            item.name.localizedCaseInsensitiveContains(trimmed)
            || item.address.localizedCaseInsensitiveContains(trimmed)
            || item.subtitle.localizedCaseInsensitiveContains(trimmed)
            || item.category.title.localizedCaseInsensitiveContains(trimmed)
        }

        async let nominatimTask = fetchNominatim(query: trimmed, near: center, categoryHint: categoryHint)
        async let mapKitTask = fetchMKLocalSearch(query: trimmed, near: center, categoryHint: categoryHint)

        let (osmResults, mkResults) = await (nominatimTask, mapKitTask)
        return deduplicatePlaces(localMatches + osmResults + mkResults)
    }

    /// 分類快選搜尋（餐廳、加油站、咖啡廳、停車場等）
    func searchCategory(
        _ category: PlaceCategory,
        near center: CLLocationCoordinate2D
    ) async -> [PlaceItem] {
        let localCategoryMatches = PlaceItem.curatedTaipeiPOIs.filter { $0.category == category }

        async let osmTask = fetchNominatim(
            query: category.title,
            near: center,
            categoryHint: category
        )
        async let mkTask = fetchMKLocalSearch(
            query: category.title,
            near: center,
            categoryHint: category
        )

        let (osmResults, mkResults) = await (osmTask, mkTask)
        let merged = deduplicatePlaces(localCategoryMatches + osmResults + mkResults)
        return merged.sorted {
            $0.distanceMeters(from: center) < $1.distanceMeters(from: center)
        }
    }

    // MARK: - OpenStreetMap Nominatim API

    private func fetchNominatim(
        query: String,
        near center: CLLocationCoordinate2D,
        categoryHint: PlaceCategory?
    ) async -> [PlaceItem] {
        var components = URLComponents(string: "https://nominatim.openstreetmap.org/search")
        let lonDelta = 0.08
        let latDelta = 0.08
        let viewbox = "\(center.longitude - lonDelta),\(center.latitude + latDelta),\(center.longitude + lonDelta),\(center.latitude - latDelta)"

        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "jsonv2"),
            URLQueryItem(name: "addressdetails", value: "1"),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "accept-language", value: "zh-TW,zh,en"),
            URLQueryItem(name: "viewbox", value: viewbox),
            URLQueryItem(name: "bounded", value: "0")
        ]

        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url, timeoutInterval: 8.0)
        request.setValue("AppleMapsNavigator-iOS/1.0 (SwiftUI MapKit Client)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return []
            }

            let decoded = try JSONDecoder().decode([NominatimResult].self, from: data)
            return decoded.compactMap { item in
                guard let lat = Double(item.lat), let lon = Double(item.lon) else { return nil }
                let resolvedName = item.name?.isEmpty == false ? item.name! : shortName(from: item.displayName)
                let resolvedAddress = formatNominatimAddress(item)
                let category = categoryHint ?? inferCategory(osmType: item.type, osmCategory: item.category, name: resolvedName)
                return PlaceItem(
                    name: resolvedName,
                    subtitle: "\(category.title)・OpenStreetMap",
                    address: resolvedAddress,
                    latitude: lat,
                    longitude: lon,
                    category: category,
                    rating: nil,
                    sourceLabel: "OpenStreetMap"
                )
            }
        } catch {
            return []
        }
    }

    // MARK: - Apple MapKit Local Search 備援/融合

    @MainActor
    private func fetchMKLocalSearch(
        query: String,
        near center: CLLocationCoordinate2D,
        categoryHint: PlaceCategory?
    ) async -> [PlaceItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 8000,
            longitudinalMeters: 8000
        )

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.prefix(8).map { mapItem in
                let coord = mapItem.placemark.coordinate
                let name = mapItem.name ?? "未知地點"
                let addressParts = [
                    mapItem.placemark.administrativeArea,
                    mapItem.placemark.locality,
                    mapItem.placemark.thoroughfare,
                    mapItem.placemark.subThoroughfare
                ].compactMap { $0 }
                let address = addressParts.isEmpty ? (mapItem.placemark.title ?? "台灣") : addressParts.joined()
                let category = categoryHint ?? inferCategoryFromMK(mapItem.pointOfInterestCategory, name: name)

                return PlaceItem(
                    name: name,
                    subtitle: "\(category.title)・MapKit",
                    address: address,
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    category: category,
                    phoneNumber: mapItem.phoneNumber,
                    sourceLabel: "MapKit"
                )
            }
        } catch {
            return []
        }
    }

    // MARK: - Helpers

    private func deduplicatePlaces(_ items: [PlaceItem]) -> [PlaceItem] {
        var result: [PlaceItem] = []
        for item in items {
            let isDuplicate = result.contains { existing in
                let sameName = existing.name.lowercased() == item.name.lowercased()
                let closeBy = existing.distanceMeters(from: item.coordinate) < 60
                return sameName || closeBy
            }
            if !isDuplicate {
                result.append(item)
            }
        }
        return result
    }

    private func shortName(from displayName: String) -> String {
        displayName.split(separator: ",").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? displayName
    }

    private func formatNominatimAddress(_ item: NominatimResult) -> String {
        if let addr = item.address {
            let parts = [addr.city ?? addr.county, addr.suburb ?? addr.district, addr.road, addr.houseNumber]
                .compactMap { $0 }
            if !parts.isEmpty {
                return parts.joined()
            }
        }
        return item.displayName
    }

    private func inferCategory(osmType: String?, osmCategory: String?, name: String) -> PlaceCategory {
        let joined = "\(osmType ?? "") \(osmCategory ?? "") \(name)".lowercased()
        if joined.contains("cafe") || joined.contains("coffee") || joined.contains("咖啡") {
            return .cafe
        } else if joined.contains("restaurant") || joined.contains("food") || joined.contains("餐廳") || joined.contains("麵") || joined.contains("食") {
            return .restaurant
        } else if joined.contains("fuel") || joined.contains("gas") || joined.contains("加油") {
            return .gasStation
        } else if joined.contains("charging") || joined.contains("充電") {
            return .evCharger
        } else if joined.contains("parking") || joined.contains("停車") {
            return .parking
        } else if joined.contains("convenience") || joined.contains("7-eleven") || joined.contains("familymart") || joined.contains("便利") {
            return .convenience
        } else if joined.contains("hospital") || joined.contains("clinic") || joined.contains("醫") {
            return .hospital
        }
        return .attraction
    }

    private func inferCategoryFromMK(_ mkCategory: MKPointOfInterestCategory?, name: String) -> PlaceCategory {
        switch mkCategory {
        case .restaurant, .bakery: return .restaurant
        case .cafe: return .cafe
        case .gasStation: return .gasStation
        case .parking: return .parking
        case .evCharger: return .evCharger
        case .hospital, .pharmacy: return .hospital
        case .store: return .convenience
        default: return inferCategory(osmType: nil, osmCategory: nil, name: name)
        }
    }
}

// MARK: - Nominatim DTO

private struct NominatimResult: Decodable {
    let name: String?
    let displayName: String
    let lat: String
    let lon: String
    let category: String?
    let type: String?
    let address: NominatimAddress?

    enum CodingKeys: String, CodingKey {
        case name
        case displayName = "display_name"
        case lat
        case lon
        case category
        case type
        case address
    }
}

private struct NominatimAddress: Decodable {
    let city: String?
    let county: String?
    let suburb: String?
    let district: String?
    let road: String?
    let houseNumber: String?

    enum CodingKeys: String, CodingKey {
        case city
        case county
        case suburb
        case district = "city_district"
        case road
        case houseNumber = "house_number"
    }
}
