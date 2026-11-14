import Foundation
import SwiftUI
import MapKit
import CoreLocation
import Observation

/// 主導航協調器：管理地圖視角、POI 搜尋、分類篩選、收藏持久化、多模式路線規劃與導航狀態切換
@Observable
@MainActor
final class MapNavigatorViewModel {
    let locationManager: LocationManager
    let voiceService: VoiceGuidanceService
    let navigationEngine: NavigationSimulationEngine

    private let searchService = PlaceSearchService()
    private let routingService = OSRMRoutingService()

    // MARK: - 地圖與介面狀態

    var appMode: NavigatorAppMode = .explore
    var sheetDetent: SheetDetent = .medium
    var cameraPosition: MapCameraPosition
    var currentMapCenter: CLLocationCoordinate2D = LocationManager.defaultCoordinate
    var currentCameraHeading: CLLocationDirection = 0
    var currentCameraDistance: CLLocationDistance = 2600
    var is3DPitchEnabled: Bool = true
    var show3DLandmarks: Bool = true
    var vehicleModelStyle: Vehicle3DModelStyle = .cyberSportsCar
    var mapDisplayStyle: MapDisplayStyle = .appleStandard3D
    var themeMode: AppThemeMode = .system

    // MARK: - 搜尋、分類與收藏

    var searchQuery: String = "" {
        didSet {
            scheduleSearchDebounced()
        }
    }
    var selectedCategory: PlaceCategory?
    var searchResults: [PlaceItem] = []
    var isSearching: Bool = false

    private(set) var favorites: [PlaceItem] = []
    private(set) var recentSearches: [PlaceItem] = []

    // MARK: - 路線規劃狀態

    var originPlace: PlaceItem
    var waypointPlace: PlaceItem?
    var destinationPlace: PlaceItem?
    var selectedTransportMode: TransportMode = .driving
    var availableRoutes: [RouteOption] = []
    var selectedRoute: RouteOption?
    var modeComparisonSummaries: [TransportMode: RouteOption] = [:]
    var isCalculatingRoutes: Bool = false
    var routeErrorMessage: String?

    private var searchDebounceTask: Task<Void, Never>?
    private var routeCalculationTask: Task<Void, Never>?

    private let favoritesStorageKey = "AppleMapsNavigator.favorites.v1"
    private let recentsStorageKey = "AppleMapsNavigator.recents.v1"

    /// 地圖上顯示的所有地標（搜尋結果或精選地點 + 收藏）
    var displayedMapPlaces: [PlaceItem] {
        var base: [PlaceItem]
        if !searchResults.isEmpty {
            base = searchResults
        } else if let selectedCategory {
            base = PlaceItem.curatedTaipeiPOIs.filter { $0.category == selectedCategory }
        } else {
            base = PlaceItem.curatedTaipeiPOIs
        }

        if case .placeDetail(let selected) = appMode,
           !base.contains(where: { $0.id == selected.id }) {
            base.append(selected)
        }
        return base
    }

    init() {
        let locManager = LocationManager()
        let voice = VoiceGuidanceService()
        let engine = NavigationSimulationEngine(routingService: routingService, voiceService: voice)

        self.locationManager = locManager
        self.voiceService = voice
        self.navigationEngine = engine
        self.originPlace = locManager.effectivePlaceItem

        let initialCamera = MapCamera(
            centerCoordinate: LocationManager.defaultCoordinate,
            distance: 2400,
            heading: 0,
            pitch: 48
        )
        self.cameraPosition = .camera(initialCamera)

        loadPersistedPlaces()
        bindNavigationEngineCallbacks()
        locManager.requestPermissionAndStartUpdating()
    }

    private func bindNavigationEngineCallbacks() {
        navigationEngine.onCameraTick = { [weak self] coordinate, heading in
            guard let self, self.appMode == .navigating else { return }
            let pitch: Double = self.is3DPitchEnabled ? 62 : 0
            let camera = MapCamera(
                centerCoordinate: coordinate,
                distance: 520,
                heading: heading,
                pitch: pitch
            )
            withAnimation(.linear(duration: 0.12)) {
                self.cameraPosition = .camera(camera)
            }
        }

        navigationEngine.onRouteReplaced = { [weak self] newRoute in
            guard let self else { return }
            self.selectedRoute = newRoute
            self.availableRoutes = [newRoute]
        }
    }

    // MARK: - 搜尋與分類互動

    private func scheduleSearchDebounced() {
        searchDebounceTask?.cancel()
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        if query.isEmpty {
            if selectedCategory == nil {
                searchResults = []
                isSearching = false
            }
            return
        }

        searchDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            await executeSearch(query: query)
        }
    }

    func executeSearch(query: String) async {
        isSearching = true
        let center = currentMapCenter
        let results = await searchService.searchPlaces(
            query: query,
            near: center,
            categoryHint: selectedCategory
        )
        guard !Task.isCancelled else { return }
        searchResults = results
        isSearching = false

        if let first = results.first {
            focusCamera(on: first.coordinate, distance: 2600)
        }
    }

    func selectCategory(_ category: PlaceCategory?) {
        if selectedCategory == category {
            selectedCategory = nil
            searchResults = []
            return
        }

        selectedCategory = category
        guard let category else {
            searchResults = []
            return
        }

        isSearching = true
        sheetDetent = .medium
        searchDebounceTask?.cancel()

        Task {
            let results = await searchService.searchCategory(category, near: currentMapCenter)
            guard !Task.isCancelled else { return }
            searchResults = results
            isSearching = false

            if !results.isEmpty {
                fitCamera(around: results.prefix(6).map(\.coordinate))
            }
        }
    }

    func clearSearch() {
        searchQuery = ""
        selectedCategory = nil
        searchResults = []
        isSearching = false
    }

    // MARK: - 地點選擇與收藏管理

    func selectPlace(_ place: PlaceItem) {
        addToRecentSearches(place)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
            appMode = .placeDetail(place)
            sheetDetent = .medium
        }
        focusCamera(on: place.coordinate, distance: 1200)
    }

    func dismissToExplore() {
        routeCalculationTask?.cancel()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            appMode = .explore
            sheetDetent = .medium
            availableRoutes = []
            selectedRoute = nil
            waypointPlace = nil
            destinationPlace = nil
            routeErrorMessage = nil
        }
    }

    func isFavorite(_ place: PlaceItem) -> Bool {
        favorites.contains {
            $0.id == place.id ||
            ($0.name == place.name && $0.distanceMeters(from: place.coordinate) < 50)
        }
    }

    func toggleFavorite(_ place: PlaceItem) {
        if let idx = favorites.firstIndex(where: {
            $0.id == place.id ||
            ($0.name == place.name && $0.distanceMeters(from: place.coordinate) < 50)
        }) {
            favorites.remove(at: idx)
        } else {
            var copy = place
            copy.isFavorite = true
            if copy.favoriteSlot == nil {
                copy.favoriteSlot = .custom
            }
            favorites.insert(copy, at: 0)
        }
        persistPlaces()
    }

    private func addToRecentSearches(_ place: PlaceItem) {
        recentSearches.removeAll { $0.name == place.name }
        recentSearches.insert(place, at: 0)
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        persistPlaces()
    }

    // MARK: - 多模式路線規劃

    func openRoutePlanning(to destination: PlaceItem) {
        originPlace = locationManager.effectivePlaceItem
        waypointPlace = nil
        destinationPlace = destination
        addToRecentSearches(destination)

        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            appMode = .routePlanning
            sheetDetent = .medium
        }

        calculateAllModeRoutes()
    }

    /// 高德特色：沿途順路搜（自動搜尋起終點中間附近最近的加油站 / 咖啡廳 / 停車場 / 充電站並加入途經點）
    func addAlongRouteWaypoint(category: PlaceCategory) {
        guard let dest = destinationPlace else { return }
        let startCoord = (appMode == .navigating) ? navigationEngine.currentCoordinate : originPlace.coordinate
        let midCoord = CLLocationCoordinate2D(
            latitude: (startCoord.latitude + dest.latitude) / 2.0,
            longitude: (startCoord.longitude + dest.longitude) / 2.0
        )

        isCalculatingRoutes = true
        Task {
            let candidates = await searchService.searchCategory(category, near: midCoord)
            guard !Task.isCancelled else { return }
            guard let best = candidates.first(where: { $0.name != dest.name }) ?? candidates.first else {
                isCalculatingRoutes = false
                return
            }

            waypointPlace = best

            if appMode == .navigating {
                let updatedRoutes = await routingService.calculateRoutes(
                    from: startCoord,
                    to: dest.coordinate,
                    waypoint: best.coordinate,
                    mode: selectedTransportMode
                )
                guard !Task.isCancelled else { return }
                if let primary = updatedRoutes.first {
                    availableRoutes = updatedRoutes
                    selectedRoute = primary
                    navigationEngine.updateActiveRouteDuringNavigation(primary)
                }
                isCalculatingRoutes = false
            } else {
                calculateAllModeRoutes()
            }
        }
    }

    func clearWaypoint() {
        waypointPlace = nil
        if appMode == .navigating, let dest = destinationPlace {
            let startCoord = navigationEngine.currentCoordinate
            Task {
                let updatedRoutes = await routingService.calculateRoutes(
                    from: startCoord,
                    to: dest.coordinate,
                    waypoint: nil,
                    mode: selectedTransportMode
                )
                if let primary = updatedRoutes.first {
                    availableRoutes = updatedRoutes
                    selectedRoute = primary
                    navigationEngine.updateActiveRouteDuringNavigation(primary)
                }
            }
        } else {
            calculateAllModeRoutes()
        }
    }

    func switchTransportMode(_ mode: TransportMode) {
        guard selectedTransportMode != mode else { return }
        selectedTransportMode = mode

        // 若已經預算出該模式摘要，先即時切過去再同步完整替代方案
        calculateRoutesForSelectedMode()
    }

    func swapOriginAndDestination() {
        guard let dest = destinationPlace else { return }
        let oldOrigin = originPlace
        originPlace = dest
        destinationPlace = oldOrigin
        calculateAllModeRoutes()
    }

    func selectRouteOption(_ route: RouteOption) {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedRoute = route
        }
        fitCamera(around: route.coordinates)
    }

    private func calculateAllModeRoutes() {
        guard let dest = destinationPlace else { return }
        routeCalculationTask?.cancel()
        isCalculatingRoutes = true
        routeErrorMessage = nil
        modeComparisonSummaries = [:]

        let start = originPlace.coordinate
        let wp = waypointPlace?.coordinate
        let end = dest.coordinate
        let activeMode = selectedTransportMode

        routeCalculationTask = Task {
            async let drivingTask = routingService.calculateRoutes(from: start, to: end, waypoint: wp, mode: .driving)
            async let walkingTask = routingService.calculateRoutes(from: start, to: end, waypoint: wp, mode: .walking)
            async let cyclingTask = routingService.calculateRoutes(from: start, to: end, waypoint: wp, mode: .cycling)

            let (drivingRoutes, walkingRoutes, cyclingRoutes) = await (drivingTask, walkingTask, cyclingTask)
            guard !Task.isCancelled else { return }

            if let d = drivingRoutes.first { modeComparisonSummaries[.driving] = d }
            if let w = walkingRoutes.first { modeComparisonSummaries[.walking] = w }
            if let c = cyclingRoutes.first { modeComparisonSummaries[.cycling] = c }

            let chosenList: [RouteOption]
            switch activeMode {
            case .driving: chosenList = drivingRoutes
            case .walking: chosenList = walkingRoutes
            case .cycling: chosenList = cyclingRoutes
            }

            availableRoutes = chosenList
            selectedRoute = chosenList.first
            isCalculatingRoutes = false

            if let primary = chosenList.first {
                fitCamera(around: primary.coordinates)
            } else {
                routeErrorMessage = "無法規劃此路段路線，請重試。"
            }
        }
    }

    private func calculateRoutesForSelectedMode() {
        guard let dest = destinationPlace else { return }
        routeCalculationTask?.cancel()
        isCalculatingRoutes = true
        routeErrorMessage = nil

        let start = originPlace.coordinate
        let wp = waypointPlace?.coordinate
        let end = dest.coordinate
        let mode = selectedTransportMode

        routeCalculationTask = Task {
            let routes = await routingService.calculateRoutes(from: start, to: end, waypoint: wp, mode: mode)
            guard !Task.isCancelled else { return }

            if let first = routes.first {
                modeComparisonSummaries[mode] = first
            }
            availableRoutes = routes
            selectedRoute = routes.first
            isCalculatingRoutes = false

            if let primary = routes.first {
                fitCamera(around: primary.coordinates)
            }
        }
    }

    // MARK: - 進入與結束 3D 模擬導航

    func startTurnByTurnNavigation() {
        guard let route = selectedRoute, let dest = destinationPlace else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            appMode = .navigating
            is3DPitchEnabled = true
        }
        navigationEngine.startNavigation(with: route, destinationName: dest.name)
    }

    func stopNavigation() {
        navigationEngine.stopNavigation()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            if destinationPlace != nil {
                appMode = .routePlanning
                sheetDetent = .medium
            } else {
                appMode = .explore
                sheetDetent = .medium
            }
        }
        if let route = selectedRoute {
            fitCamera(around: route.coordinates)
        } else {
            recenterCamera()
        }
    }

    // MARK: - 地圖鏡頭控制

    func recenterCamera() {
        if appMode == .navigating {
            focusCamera(
                on: navigationEngine.currentCoordinate,
                distance: 520,
                heading: navigationEngine.currentHeading
            )
        } else {
            locationManager.refreshOneShotLocation()
            focusCamera(on: locationManager.effectiveCoordinate, distance: 2000, heading: 0)
        }
    }

    func resetCompassNorth() {
        let targetCenter = (appMode == .navigating)
            ? navigationEngine.currentCoordinate
            : currentMapCenter
        focusCamera(on: targetCenter, distance: currentCameraDistance, heading: 0)
    }

    func toggle3DPitch() {
        is3DPitchEnabled.toggle()
        let center = (appMode == .navigating) ? navigationEngine.currentCoordinate : currentMapCenter
        let distance = (appMode == .navigating) ? 520 : currentCameraDistance
        focusCamera(on: center, distance: distance, heading: currentCameraHeading)
    }

    func cycleThemeMode() {
        switch themeMode {
        case .system: themeMode = .light
        case .light: themeMode = .dark
        case .dark: themeMode = .system
        }
    }

    func focusCamera(
        on coordinate: CLLocationCoordinate2D,
        distance: CLLocationDistance = 1600,
        heading: CLLocationDirection = 0
    ) {
        let pitch: Double = is3DPitchEnabled ? (appMode == .navigating ? 62 : 46) : 0
        let camera = MapCamera(
            centerCoordinate: coordinate,
            distance: distance,
            heading: heading,
            pitch: pitch
        )
        withAnimation(.easeInOut(duration: 0.6)) {
            cameraPosition = .camera(camera)
        }
    }

    func fitCamera(around coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else { return }
        if coordinates.count == 1, let only = coordinates.first {
            focusCamera(on: only, distance: 1400)
            return
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2.0 - (maxLat - minLat) * 0.16, // 留出底部抽屜空間
            longitude: (minLon + maxLon) / 2.0
        )
        let latSpan = max(0.012, (maxLat - minLat) * 1.75)
        let lonSpan = max(0.012, (maxLon - minLon) * 1.55)

        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
        )

        withAnimation(.easeInOut(duration: 0.65)) {
            cameraPosition = .region(region)
        }
    }

    // MARK: - 持久化

    private func loadPersistedPlaces() {
        if let data = UserDefaults.standard.data(forKey: favoritesStorageKey),
           let decoded = try? JSONDecoder().decode([PlaceItem].self, from: data),
           !decoded.isEmpty {
            favorites = decoded
        } else {
            favorites = PlaceItem.defaultFavorites
        }

        if let data = UserDefaults.standard.data(forKey: recentsStorageKey),
           let decoded = try? JSONDecoder().decode([PlaceItem].self, from: data) {
            recentSearches = decoded
        } else {
            recentSearches = Array(PlaceItem.curatedTaipeiPOIs.prefix(4))
        }
    }

    private func persistPlaces() {
        if let favData = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(favData, forKey: favoritesStorageKey)
        }
        if let recentData = try? JSONEncoder().encode(recentSearches) {
            UserDefaults.standard.set(recentData, forKey: recentsStorageKey)
        }
    }
}
