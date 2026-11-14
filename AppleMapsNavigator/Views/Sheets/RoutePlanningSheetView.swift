import SwiftUI

/// 多模式路線規劃與方案比較面板（支援開車 / 步行 / 單車即時切換與步驟預覽）
struct RoutePlanningSheetView: View {
    @Bindable var viewModel: MapNavigatorViewModel
    @State private var showAllSteps = false

    var body: some View {
        VStack(spacing: 14) {
            headerBar

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    originDestinationCard

                    alongRouteWaypointBar

                    transportModeSelector

                    routesComparisonSection

                    if let selected = viewModel.selectedRoute, !selected.steps.isEmpty {
                        routeStepsPreviewSection(route: selected)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - 頂部標題列

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("路線規劃")
                    .font(.title3.weight(.bold))
                if let dest = viewModel.destinationPlace {
                    Text("前往 \(dest.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                viewModel.dismissToExplore()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary.opacity(0.75))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - 起終點交換卡片

    private var originDestinationCard: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Circle()
                    .fill(AppleMapsTheme.navBlue)
                    .frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 2, height: 18)
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.originPlace.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                if let waypoint = viewModel.waypointPlace {
                    Divider()
                    HStack(spacing: 6) {
                        Text("途經：\(waypoint.name)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppleMapsTheme.navGreen)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            viewModel.clearWaypoint()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                Text(viewModel.destinationPlace?.name ?? "未選擇目的地")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                viewModel.swapOriginAndDestination()
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppleMapsTheme.navBlue)
                    .frame(width: 36, height: 36)
                    .background(AppleMapsTheme.navBlue.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("交換起點與終點")
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 高德特色：沿途順路搜途經點

    private var alongRouteWaypointBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("順路加點")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                ForEach([PlaceCategory.gasStation, .evCharger, .cafe, .parking], id: \.self) { cat in
                    Button {
                        viewModel.addAlongRouteWaypoint(category: cat)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: cat.symbolName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(cat.accentColor)
                            Text(cat.title)
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemGroupedBackground).opacity(0.85), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 多交通模式切換列 (開車 / 步行 / 單車)

    private var transportModeSelector: some View {
        HStack(spacing: 8) {
            ForEach(TransportMode.allCases) { mode in
                let isSelected = viewModel.selectedTransportMode == mode
                let summary = viewModel.modeComparisonSummaries[mode]

                Button {
                    viewModel.switchTransportMode(mode)
                } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 5) {
                            Image(systemName: mode.symbolName)
                                .font(.system(size: 14, weight: .semibold))
                            Text(mode.title)
                                .font(.subheadline.weight(.semibold))
                        }

                        if let summary {
                            Text(summary.formattedDuration)
                                .font(.caption2.weight(.medium))
                                .opacity(isSelected ? 0.92 : 0.75)
                        } else {
                            Text(viewModel.isCalculatingRoutes ? "計算中" : "--")
                                .font(.caption2)
                                .opacity(0.65)
                        }
                    }
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        isSelected
                        ? AnyShapeStyle(AppleMapsTheme.navBlue)
                        : AnyShapeStyle(Color(.secondarySystemGroupedBackground).opacity(0.82)),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 路線方案比較列表

    @ViewBuilder
    private var routesComparisonSection: some View {
        if viewModel.isCalculatingRoutes && viewModel.availableRoutes.isEmpty {
            HStack(spacing: 12) {
                ProgressView()
                Text("正在透過 OSRM 計算最佳與替代路線...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground).opacity(0.8), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else if let error = viewModel.routeErrorMessage, viewModel.availableRoutes.isEmpty {
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.red)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground).opacity(0.8), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            VStack(spacing: 10) {
                ForEach(viewModel.availableRoutes) { route in
                    let isSelected = viewModel.selectedRoute?.id == route.id

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(route.formattedDuration)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.primary)

                                Text(route.summaryTitle)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(route.isRecommended ? AppleMapsTheme.navGreen : .secondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(
                                        (route.isRecommended ? AppleMapsTheme.navGreen : Color.secondary).opacity(0.14),
                                        in: Capsule()
                                    )
                            }

                            Text("\(route.formattedDistance)・預計 \(route.estimatedArrivalTimeText) 抵達")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("\(route.detailTag) (\(route.engineSource))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if isSelected {
                            Button {
                                viewModel.startTurnByTurnNavigation()
                            } label: {
                                Text("出發")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(AppleMapsTheme.navGreen, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .shadow(color: AppleMapsTheme.navGreen.opacity(0.35), radius: 8, y: 3)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("選擇")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppleMapsTheme.navBlue)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(AppleMapsTheme.navBlue.opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground).opacity(isSelected ? 0.96 : 0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(isSelected ? AppleMapsTheme.navBlue : Color.clear, lineWidth: 1.8)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectRouteOption(route)
                    }
                }
            }
        }
    }

    // MARK: - 轉彎步驟預覽

    private func routeStepsPreviewSection(route: RouteOption) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showAllSteps.toggle()
                }
            } label: {
                HStack {
                    Text("分段導航指引 (\(route.steps.count) 步)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: showAllSteps ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            let visibleSteps = showAllSteps ? route.steps : Array(route.steps.prefix(3))
            VStack(spacing: 0) {
                ForEach(Array(visibleSteps.enumerated()), id: \.element.id) { index, step in
                    HStack(spacing: 12) {
                        Image(systemName: step.maneuverType.symbolName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppleMapsTheme.navBlue)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.instruction)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            if step.distanceMeters > 0 {
                                Text(RouteFormatting.formatDistance(meters: step.distanceMeters))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    if index < visibleSteps.count - 1 {
                        Divider().padding(.leading, 54)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground).opacity(0.75), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
