import SwiftUI

/// 右側懸浮控制群組（圖層選擇、深淺色外觀切換、3D 視角、重新置中、指南針、語音靜音）
struct FloatingMapControlsView: View {
    @Bindable var viewModel: MapNavigatorViewModel

    var body: some View {
        VStack(spacing: 10) {
            // 動態指南針（非正北時顯示）
            if abs(viewModel.currentCameraHeading) > 2 {
                Button {
                    viewModel.resetCompassNorth()
                } label: {
                    Image(systemName: "location.north.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.red, .primary)
                        .rotationEffect(.degrees(-viewModel.currentCameraHeading))
                        .frame(width: 44, height: 44)
                }
                .appleMapsGlassCard(cornerRadius: 14)
                .transition(.scale.combined(with: .opacity))
            }

            // 主要懸浮玻璃控制條
            VStack(spacing: 0) {
                // 圖層切換選單（標準 3D / 衛星混合 / OSM 圖磚）
                Menu {
                    Picker("地圖圖層", selection: $viewModel.mapDisplayStyle) {
                        ForEach(MapDisplayStyle.allCases) { style in
                            Label(style.title, systemImage: style.symbolName)
                                .tag(style)
                        }
                    }
                } label: {
                    Image(systemName: viewModel.mapDisplayStyle.symbolName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppleMapsTheme.navBlue)
                        .frame(width: 44, height: 44)
                }

                Divider().frame(width: 28)

                // 深淺色模式快速切換
                Button {
                    viewModel.cycleThemeMode()
                } label: {
                    Image(systemName: viewModel.themeMode.symbolName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("切換外觀：\(viewModel.themeMode.title)")

                Divider().frame(width: 28)

                // 3D / 2D 視角切換
                Button {
                    viewModel.toggle3DPitch()
                } label: {
                    Text(viewModel.is3DPitchEnabled ? "3D" : "2D")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(viewModel.is3DPitchEnabled ? AppleMapsTheme.navBlue : .secondary)
                        .frame(width: 44, height: 44)
                }

                Divider().frame(width: 28)

                // 重新定位目前位置
                Button {
                    viewModel.recenterCamera()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppleMapsTheme.navBlue)
                        .frame(width: 44, height: 44)
                }
            }
            .appleMapsGlassCard(cornerRadius: 15)

            // 導航中顯示語音靜音切換按鈕
            if viewModel.appMode == .navigating {
                Button {
                    viewModel.voiceService.isMuted.toggle()
                } label: {
                    Image(systemName: viewModel.voiceService.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(viewModel.voiceService.isMuted ? .red : .primary)
                        .frame(width: 44, height: 44)
                }
                .appleMapsGlassCard(cornerRadius: 14)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: viewModel.appMode)
    }
}
