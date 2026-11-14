import SwiftUI
import MapKit

/// 主地圖畫布視圖：整合 3D MapKit / OSM 圖層、雙層路網外框描邊、動態地標、懸浮控制列、導航 HUD 與可拖拽底部面板
struct MainMapCanvasView: View {
    @Bindable var viewModel: MapNavigatorViewModel

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let safeBottom = proxy.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                // 1. 底層地圖畫布（Apple 3D MapKit 或 OpenStreetMap 圖磚）
                mapLayerContent
                    .ignoresSafeArea()

                // 2. 頂部狀態標籤（探索 / 規劃模式顯示目前圖層與定位狀態）
                if viewModel.appMode != .navigating {
                    VStack {
                        HStack {
                            statusTopPill
                            Spacer()
                        }
                        .padding(.top, max(8, safeTop))
                        .padding(.horizontal, 14)

                        Spacer()
                    }
                    .transition(.opacity)
                }

                // 3. 右側懸浮控制列（依模式自動調整垂直位置，避免遮擋面板或 HUD）
                VStack {
                    if viewModel.appMode == .navigating {
                        Spacer()
                        HStack {
                            Spacer()
                            FloatingMapControlsView(viewModel: viewModel)
                                .padding(.trailing, 14)
                                .padding(.bottom, safeBottom + 166)
                        }
                    } else {
                        HStack {
                            Spacer()
                            FloatingMapControlsView(viewModel: viewModel)
                                .padding(.top, max(8, safeTop))
                                .padding(.trailing, 14)
                        }
                        Spacer()
                    }
                }
                .allowsHitTesting(true)

                // 4. 導航模式 HUD 或 可拖拽底部面板
                if viewModel.appMode == .navigating {
                    TurnByTurnHUDView(
                        viewModel: viewModel,
                        safeAreaTop: safeTop,
                        safeAreaBottom: safeBottom
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    DraggableBottomSheet(
                        detent: $viewModel.sheetDetent,
                        containerHeight: proxy.size.height,
                        safeAreaBottom: safeBottom
                    ) {
                        activeSheetContent
                    }
                    .transition(.move(edge: .bottom))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.86), value: viewModel.appMode)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - 地圖圖層切換

    @ViewBuilder
    private var mapLayerContent: some View {
        if viewModel.mapDisplayStyle == .openStreetMap {
            OSMTileOverlayView(
                centerCoordinate: viewModel.appMode == .navigating
                    ? viewModel.navigationEngine.currentCoordinate
                    : viewModel.currentMapCenter,
                places: viewModel.displayedMapPlaces,
                selectedRoute: viewModel.selectedRoute,
                alternativeRoutes: viewModel.availableRoutes,
                vehicleCoordinate: viewModel.appMode == .navigating
                    ? viewModel.navigationEngine.currentCoordinate
                    : nil,
                onSelectPlace: { place in
                    viewModel.selectPlace(place)
                }
            )
        } else {
            apple3DMapKitView
        }
    }

    // MARK: - 原生 iOS 17+ MapKit 3D 視圖

    private var apple3DMapKitView: some View {
        Map(position: $viewModel.cameraPosition) {
            userLocationContent

            switch viewModel.appMode {
            case .navigating:
                navigatingMapContent
            case .routePlanning:
                routePlanningMapContent
            case .explore, .placeDetail:
                exploreMapContent
            }
        }
        .mapStyle(viewModel.mapDisplayStyle.mapKitStyle)
        .mapControls {
            MapScaleView()
        }
        .onMapCameraChange(frequency: .continuous) { context in
            viewModel.currentMapCenter = context.camera.centerCoordinate
            viewModel.currentCameraHeading = context.camera.heading
            viewModel.currentCameraDistance = context.camera.distance
        }
    }

    @MapContentBuilder
    private var userLocationContent: some MapContent {
        if viewModel.appMode != .navigating {
            UserAnnotation()

            if viewModel.locationManager.isUsingSimulatedDefault {
                Annotation("我的位置", coordinate: viewModel.locationManager.effectiveCoordinate) {
                    UserLocationPulseMarkerView()
                }
                .annotationTitles(.hidden)
            }
        }
    }

    @MapContentBuilder
    private var navigatingMapContent: some MapContent {
        // 已走過的路段以霧面灰呈現
        if viewModel.navigationEngine.traversedCoordinates.count >= 2 {
            MapPolyline(coordinates: viewModel.navigationEngine.traversedCoordinates)
                .stroke(
                    Color.gray.opacity(0.48),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                )
        }

        // 剩餘路線雙層 Apple Maps Navigation Blue 描邊
        if viewModel.navigationEngine.remainingCoordinates.count >= 2 {
            MapPolyline(coordinates: viewModel.navigationEngine.remainingCoordinates)
                .stroke(
                    AppleMapsTheme.routeCasingBlue,
                    style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round)
                )
            MapPolyline(coordinates: viewModel.navigationEngine.remainingCoordinates)
                .stroke(
                    AppleMapsTheme.navBlue,
                    style: StrokeStyle(lineWidth: 8.5, lineCap: .round, lineJoin: .round)
                )
        }

        // 目的地旗幟
        if let dest = viewModel.destinationPlace {
            Annotation(dest.name, coordinate: dest.coordinate) {
                RouteEndpointBadgeView(isDestination: true, title: dest.name)
            }
            .annotationTitles(.hidden)
        }

        // 3D 導航箭頭車輛標記
        Annotation("導航車輛", coordinate: viewModel.navigationEngine.currentCoordinate) {
            NavigationVehicleMarkerView(
                headingDegrees: viewModel.navigationEngine.currentHeading - viewModel.currentCameraHeading
            )
        }
        .annotationTitles(.hidden)
    }

    @MapContentBuilder
    private var routePlanningMapContent: some MapContent {
        let altRoutes = viewModel.availableRoutes.filter {
            $0.id != viewModel.selectedRoute?.id && $0.coordinates.count >= 2
        }

        // 替代路線（半透明淡藍）
        ForEach(altRoutes) { altRoute in
            MapPolyline(coordinates: altRoute.coordinates)
                .stroke(
                    AppleMapsTheme.routeAlternative.opacity(0.45),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
                )
        }

        // 主要選中路線（雙層深藍外框 + iOS 導航藍）
        if let selected = viewModel.selectedRoute, selected.coordinates.count >= 2 {
            MapPolyline(coordinates: selected.coordinates)
                .stroke(
                    AppleMapsTheme.routeCasingBlue,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round)
                )
            MapPolyline(coordinates: selected.coordinates)
                .stroke(
                    AppleMapsTheme.navBlue,
                    style: StrokeStyle(lineWidth: 7.5, lineCap: .round, lineJoin: .round)
                )
        }

        // 起點與終點徽章
        Annotation(viewModel.originPlace.name, coordinate: viewModel.originPlace.coordinate) {
            RouteEndpointBadgeView(isDestination: false, title: viewModel.originPlace.name)
        }
        .annotationTitles(.hidden)

        if let dest = viewModel.destinationPlace {
            Annotation(dest.name, coordinate: dest.coordinate) {
                RouteEndpointBadgeView(isDestination: true, title: dest.name)
            }
            .annotationTitles(.hidden)
        }
    }

    @MapContentBuilder
    private var exploreMapContent: some MapContent {
        ForEach(viewModel.displayedMapPlaces) { place in
            let isSelected = isSelectedPlace(place)
            Annotation(place.name, coordinate: place.coordinate) {
                Button {
                    viewModel.selectPlace(place)
                } label: {
                    PlaceAnnotationPinView(place: place, isSelected: isSelected)
                }
                .buttonStyle(.plain)
            }
            .annotationTitles(.hidden)
        }
    }

    private func isSelectedPlace(_ place: PlaceItem) -> Bool {
        if case .placeDetail(let active) = viewModel.appMode {
            return active.id == place.id
        }
        return false
    }

    // MARK: - 頂部左上角狀態膠囊

    private var statusTopPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.locationManager.isUsingSimulatedDefault ? AppleMapsTheme.navBlue : AppleMapsTheme.navGreen)
                .frame(width: 8, height: 8)
            Text(viewModel.mapDisplayStyle.title)
                .font(.caption.weight(.bold))
            Text("・")
                .foregroundStyle(.secondary)
            Text(viewModel.locationManager.isUsingSimulatedDefault ? "信義區模擬" : "GPS 定位")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .appleMapsGlassCard(cornerRadius: 16)
    }

    // MARK: - 底部面板內容路由

    @ViewBuilder
    private var activeSheetContent: some View {
        switch viewModel.appMode {
        case .explore:
            ExploreSearchSheetView(viewModel: viewModel)
        case .placeDetail(let place):
            PlaceDetailSheetView(viewModel: viewModel, place: place)
        case .routePlanning:
            RoutePlanningSheetView(viewModel: viewModel)
        case .navigating:
            EmptyView()
        }
    }
}
