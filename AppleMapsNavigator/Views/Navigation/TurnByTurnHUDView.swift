import SwiftUI

/// Turn-by-Turn 導航模式 HUD（頂部高對比轉彎提示卡 + 接著次一步提示 + 底部遙測與模擬重算控制列）
struct TurnByTurnHUDView: View {
    @Bindable var viewModel: MapNavigatorViewModel
    let safeAreaTop: CGFloat
    let safeAreaBottom: CGFloat

    private var engine: NavigationSimulationEngine { viewModel.navigationEngine }

    var body: some View {
        VStack {
            topGuidanceCard
                .padding(.top, max(8, safeAreaTop))
                .padding(.horizontal, 14)

            Spacer()

            bottomTelemetryBar
                .padding(.bottom, max(12, safeAreaBottom))
                .padding(.horizontal, 14)
        }
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
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
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
                    .padding(.vertical, 9)
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

    // MARK: - 底部遙測與控制面板

    private var bottomTelemetryBar: some View {
        VStack(spacing: 12) {
            // 第一列：模擬控制按鈕列（暫停、倍速、模擬偏離重算）
            HStack(spacing: 8) {
                Button {
                    engine.togglePause()
                } label: {
                    Label(engine.isPaused ? "繼續" : "暫停", systemImage: engine.isPaused ? "play.fill" : "pause.fill")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemGroupedBackground).opacity(0.85), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    engine.cycleSpeedMultiplier()
                } label: {
                    Text("模擬 \(Int(engine.speedMultiplier))x")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppleMapsTheme.navBlue.opacity(0.16), in: Capsule())
                        .foregroundStyle(AppleMapsTheme.navBlue)
                }
                .buttonStyle(.plain)

                Button {
                    engine.simulateOffRouteDeviation()
                } label: {
                    Label("模擬偏離重算", systemImage: "arrow.triangle.branch")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppleMapsTheme.warningAmber.opacity(0.18), in: Capsule())
                        .foregroundStyle(AppleMapsTheme.warningAmber)
                }
                .buttonStyle(.plain)
                .disabled(engine.isRerouting || engine.hasArrived)

                Spacer()

                Text("\(Int(engine.currentSpeedKMH.rounded())) km/h")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
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
