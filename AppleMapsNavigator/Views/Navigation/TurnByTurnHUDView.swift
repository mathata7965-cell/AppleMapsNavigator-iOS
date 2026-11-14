import SwiftUI

/// Turn-by-Turn 導航模式 HUD（整合高德級 3D 車道引導、3D 路口實景放大、紅綠燈讀秒、測速照相警示與順路加點）
struct TurnByTurnHUDView: View {
    @Bindable var viewModel: MapNavigatorViewModel
    let safeAreaTop: CGFloat
    let safeAreaBottom: CGFloat

    private var engine: NavigationSimulationEngine { viewModel.navigationEngine }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 8) {
                topGuidanceCard

                if !engine.hasArrived, let step = engine.currentStep {
                    LaneGuidanceStripView(maneuverType: step.maneuverType)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if engine.isJunctionViewActive, let step = engine.currentStep {
                    Junction3DCrossroadView(
                        step: step,
                        distanceMeters: engine.distanceToNextManeuver,
                        onToggleClose: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                engine.showJunctionPreviewOverride = false
                            }
                        }
                    )
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                }

                if let cameraAlert = engine.activeSpeedCameraAlert, !engine.hasArrived {
                    SpeedCameraAlertBannerView(alert: cameraAlert)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, max(8, safeAreaTop))
            .padding(.horizontal, 14)

            Spacer()

            // 左側紅綠燈讀秒 + 速限牌與即時時速儀表
            if !engine.hasArrived {
                HStack(alignment: .bottom, spacing: 10) {
                    TrafficLightCountdownPillView(
                        phase: engine.trafficLightPhase,
                        seconds: engine.trafficLightSeconds
                    )

                    SpeedLimitSignView(
                        currentSpeedKMH: engine.currentSpeedKMH,
                        speedLimitKMH: engine.currentSpeedLimitKMH,
                        isOverSpeed: engine.isOverSpeed
                    )

                    Spacer()
                }
                .padding(.horizontal, 14)
            }

            bottomTelemetryBar
                .padding(.bottom, max(12, safeAreaBottom))
                .padding(.horizontal, 14)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: engine.isJunctionViewActive)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: engine.activeSpeedCameraAlert != nil)
    }

    // MARK: - 頂部轉彎指示卡

    private var topGuidanceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if engine.isRerouting || engine.isOffRouteBannerVisible {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text(engine.isRerouting ? "偵測到偏離路線，OSRM 正在重新規劃..." : "已切換至最新最佳路線")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppleMapsTheme.warningAmber)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if engine.hasArrived {
                HStack(spacing: 14) {
                    Image(systemName: "flag.checkered.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("已抵達目的地")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text(engine.destinationName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                }
                .padding(18)
                .background(
                    LinearGradient(
                        colors: [AppleMapsTheme.navGreen, AppleMapsTheme.navGreenDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            } else {
                HStack(spacing: 16) {
                    Image(systemName: engine.currentStep?.maneuverType.symbolName ?? "arrow.up")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .contentTransition(.symbolEffect(.replace))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(RouteFormatting.formatDistance(meters: engine.distanceToNextManeuver))
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()

                        Text(engine.currentStep?.instruction ?? "依路線直行")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(2)
                    }

                    Spacer()

                    // 手動預覽 3D 路口實景按鈕
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            engine.showJunctionPreviewOverride.toggle()
                        }
                    } label: {
                        Image(systemName: "view.3d")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(engine.showJunctionPreviewOverride ? 0.35 : 0.16), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("切換 3D 路口預覽")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [AppleMapsTheme.navGreenDark, AppleMapsTheme.navGreen],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                // 次要「接著」轉彎子條
                if let next = engine.nextStep {
                    HStack(spacing: 8) {
                        Text("接著")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.85))
                        Image(systemName: next.maneuverType.symbolName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                        Text(next.instruction)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.9)
        )
        .shadow(color: Color.black.opacity(0.32), radius: 18, y: 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: engine.isRerouting)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: engine.hasArrived)
    }

    // MARK: - 底部遙測與高德級模擬控制面板

    private var bottomTelemetryBar: some View {
        VStack(spacing: 10) {
            // 第一列：橫向可捲動控制膠囊（暫停、倍速、偏離重算、3D 車標、沿途順路搜）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        engine.togglePause()
                    } label: {
                        Label(engine.isPaused ? "繼續" : "暫停", systemImage: engine.isPaused ? "play.fill" : "pause.fill")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Color(.secondarySystemGroupedBackground).opacity(0.85), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        engine.cycleSpeedMultiplier()
                    } label: {
                        Text("模擬 \(Int(engine.speedMultiplier))x")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(AppleMapsTheme.navBlue.opacity(0.16), in: Capsule())
                            .foregroundStyle(AppleMapsTheme.navBlue)
                    }
                    .buttonStyle(.plain)

                    Button {
                        engine.simulateOffRouteDeviation()
                    } label: {
                        Label("模擬偏離重算", systemImage: "arrow.triangle.branch")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(AppleMapsTheme.warningAmber.opacity(0.18), in: Capsule())
                            .foregroundStyle(AppleMapsTheme.warningAmber)
                    }
                    .buttonStyle(.plain)
                    .disabled(engine.isRerouting || engine.hasArrived)

                    // 3D 車標模型選擇 Menu
                    Menu {
                        Picker("3D 車標模型", selection: $viewModel.vehicleModelStyle) {
                            ForEach(Vehicle3DModelStyle.allCases) { style in
                                Label(style.title, systemImage: style.symbolName).tag(style)
                            }
                        }
                    } label: {
                        Label(viewModel.vehicleModelStyle.title, systemImage: viewModel.vehicleModelStyle.symbolName)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Color.cyan.opacity(0.18), in: Capsule())
                            .foregroundStyle(AppleMapsTheme.navBlue)
                    }

                    // 沿途順路加點 Menu
                    Menu {
                        Button {
                            viewModel.addAlongRouteWaypoint(category: .gasStation)
                        } label: {
                            Label("順路去加油站", systemImage: PlaceCategory.gasStation.symbolName)
                        }
                        Button {
                            viewModel.addAlongRouteWaypoint(category: .evCharger)
                        } label: {
                            Label("順路找充電站", systemImage: PlaceCategory.evCharger.symbolName)
                        }
                        Button {
                            viewModel.addAlongRouteWaypoint(category: .cafe)
                        } label: {
                            Label("順路買咖啡", systemImage: PlaceCategory.cafe.symbolName)
                        }
                        Button {
                            viewModel.addAlongRouteWaypoint(category: .parking)
                        } label: {
                            Label("順路找停車場", systemImage: PlaceCategory.parking.symbolName)
                        }
                        if viewModel.waypointPlace != nil {
                            Divider()
                            Button(role: .destructive) {
                                viewModel.clearWaypoint()
                            } label: {
                                Label("移除途經點", systemImage: "trash")
                            }
                        }
                    } label: {
                        Label(viewModel.waypointPlace == nil ? "順路搜" : "已加途經點", systemImage: "plus.circle.fill")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(AppleMapsTheme.navGreen.opacity(0.18), in: Capsule())
                            .foregroundStyle(AppleMapsTheme.navGreen)
                    }
                }
            }

            Divider()

            // 第二列：ETA、剩餘時間距離與結束按鈕
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(RouteFormatting.formatDuration(seconds: engine.remainingDurationSeconds))
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(AppleMapsTheme.navGreen)
                        .monospacedDigit()

                    HStack(spacing: 6) {
                        Text("\(RouteFormatting.formatDistance(meters: engine.remainingDistanceMeters))")
                        Text("・")
                        Text("預計 \(RouteFormatting.formatClockTime(engine.estimatedArrivalDate)) 抵達")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }

                Spacer()

                Button {
                    viewModel.stopNavigation()
                } label: {
                    Text("結束")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .appleMapsGlassCard(cornerRadius: 24)
    }
}
