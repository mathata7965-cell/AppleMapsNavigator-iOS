import SwiftUI

// MARK: - 1. 高德風格 3D 立體車標模型

struct Vehicle3DMeshMarkerView: View {
    let style: Vehicle3DModelStyle
    let headingDegrees: Double
    let speedKMH: Double

    @State private var pulseActive = false

    var body: some View {
        let ringColor: Color = beamColor.opacity(pulseActive ? 0.15 : 0.45)
        let ringSize: CGFloat = pulseActive ? 62 : 44

        ZStack {
            // 前方視角導引光錐
            VehicleHeadlightBeam()
                .fill(
                    LinearGradient(
                        colors: [
                            beamColor.opacity(0.45),
                            beamColor.opacity(0.0)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 68, height: 64)
                .offset(y: -30)

            // 地面環境陰影 + 能量光環
            Circle()
                .strokeBorder(ringColor, lineWidth: 2)
                .frame(width: ringSize, height: ringSize)

            Ellipse()
                .fill(Color.black.opacity(0.32))
                .frame(width: 34, height: 48)
                .blur(radius: 4)
                .offset(y: 4)

            // 3D 立體載具主體
            vehicleBody
                .rotation3DEffect(.degrees(16), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
        }
        .rotationEffect(.degrees(headingDegrees))
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulseActive = true
            }
        }
    }

    private var beamColor: Color {
        switch style {
        case .cyberSportsCar: return Color(red: 0.15, green: 0.65, blue: 1.0)
        case .aeroSUV: return AppleMapsTheme.navBlue
        case .mechaWing: return Color(red: 0.0, green: 0.92, blue: 0.85)
        case .classic3DArrow: return AppleMapsTheme.navBlue
        }
    }

    @ViewBuilder
    private var vehicleBody: some View {
        switch style {
        case .cyberSportsCar:
            cyberSportsCarView
        case .aeroSUV:
            aeroSUVView
        case .mechaWing:
            mechaWingView
        case .classic3DArrow:
            classic3DArrowView
        }
    }

    private var cyberSportsCarView: some View {
        ZStack {
            // 雙尾燈速度光暈
            if speedKMH > 1 {
                HStack(spacing: 10) {
                    Circle().fill(Color.red.opacity(0.85)).frame(width: 6, height: 6)
                    Circle().fill(Color.red.opacity(0.85)).frame(width: 6, height: 6)
                }
                .blur(radius: 2)
                .offset(y: 22)
            }

            // 超跑流線車身
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.56, blue: 1.0),
                            Color(red: 0.03, green: 0.24, blue: 0.62)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 26, height: 46)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.65), lineWidth: 1)
                )

            // 引擎蓋立體高光條
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.28))
                .frame(width: 8, height: 14)
                .offset(y: -12)

            // 全景擋風玻璃與車頂
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.85), Color(red: 0.12, green: 0.25, blue: 0.38)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 19, height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.cyan.opacity(0.45), lineWidth: 0.7)
                )
                .offset(y: 2)

            // 雙 LED 頭燈
            HStack(spacing: 12) {
                Capsule().fill(Color.white).frame(width: 4, height: 3)
                Capsule().fill(Color.white).frame(width: 4, height: 3)
            }
            .offset(y: -20)
        }
    }

    private var aeroSUVView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.96), Color(white: 0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 28, height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.white, lineWidth: 1.2)
                )

            // 車頂行李架雙軌
            HStack(spacing: 16) {
                Capsule().fill(Color.gray.opacity(0.7)).frame(width: 2, height: 28)
                Capsule().fill(Color.gray.opacity(0.7)).frame(width: 2, height: 28)
            }
            .offset(y: 4)

            // 全景黑化天窗
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.black.opacity(0.82))
                .frame(width: 18, height: 24)
                .offset(y: 3)

            // 前保險桿與 LED 燈組
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 1).fill(Color.cyan).frame(width: 5, height: 3)
                RoundedRectangle(cornerRadius: 1).fill(Color.cyan).frame(width: 5, height: 3)
            }
            .offset(y: -21)
        }
    }

    private var mechaWingView: some View {
        ZStack {
            // 雙側尾焰推進器
            if speedKMH > 1 {
                HStack(spacing: 10) {
                    Capsule()
                        .fill(LinearGradient(colors: [.cyan, .clear], startPoint: .top, endPoint: .bottom))
                        .frame(width: 5, height: 14)
                    Capsule()
                        .fill(LinearGradient(colors: [.cyan, .clear], startPoint: .top, endPoint: .bottom))
                        .frame(width: 5, height: 14)
                }
                .offset(y: 23)
            }

            MechaCraftShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.92, blue: 0.88),
                            Color(red: 0.08, green: 0.35, blue: 0.78)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 40, height: 44)
                .overlay(
                    MechaCraftShape()
                        .stroke(Color.white.opacity(0.85), lineWidth: 1.2)
                )

            // 駕駛艙核心發光體
            Capsule()
                .fill(Color.white)
                .frame(width: 7, height: 15)
                .shadow(color: .cyan, radius: 5)
                .offset(y: -2)
        }
    }

    private var classic3DArrowView: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.3), radius: 6, y: 2)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppleMapsTheme.navBlue, AppleMapsTheme.routeCasingBlue],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 29, height: 29)

            Image(systemName: "location.north.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .offset(y: -1)
        }
    }
}

private struct VehicleHeadlightBeam: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.minY - 8)
        )
        path.closeSubpath()
        return path
    }
}

private struct MechaCraftShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.78))
        p.addLine(to: CGPoint(x: rect.midX + 6, y: rect.maxY * 0.68))
        p.addLine(to: CGPoint(x: rect.midX + 5, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY * 0.86))
        p.addLine(to: CGPoint(x: rect.midX - 5, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX - 6, y: rect.maxY * 0.68))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.78))
        p.closeSubpath()
        return p
    }
}

// MARK: - 2. 高德風格 3D 城市地標立體建築標記

struct Landmark3DExtrudedPinView: View {
    let place: PlaceItem
    let isSelected: Bool

    private var isTaipei101: Bool {
        place.name.contains("101")
    }

    var body: some View {
        let scaleFactor: CGFloat = isSelected ? 1.12 : 1.0
        VStack(spacing: 3) {
            if isTaipei101 {
                taipei101TowerModel
            } else {
                isometricPedestalModel
            }

            nameBadgePill
        }
        .scaleEffect(scaleFactor)
        .animation(.spring(response: 0.34, dampingFraction: 0.72), value: isSelected)
    }

    private var nameBadgePill: some View {
        let fontSize: CGFloat = isSelected ? 12 : 10
        let fontWeight: Font.Weight = isSelected ? .bold : .semibold
        let borderColor: Color = isSelected ? place.category.accentColor : Color.white.opacity(0.45)
        let borderWidth: CGFloat = isSelected ? 1.4 : 0.6

        return Text(place.name)
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundStyle(Color.primary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 4, y: 2)
    }

    /// 台北 101 八節竹節 3D 立體模型
    private var taipei101TowerModel: some View {
        let towerShadow: Color = Color.cyan.opacity(isSelected ? 0.55 : 0.25)

        return VStack(spacing: 0) {
            // 避雷針尖塔
            Rectangle()
                .fill(LinearGradient(colors: [Color.cyan, Color.white], startPoint: .top, endPoint: .bottom))
                .frame(width: 2.5, height: 12)

            // 漸縮上層觀景塔身
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [Color.cyan.opacity(0.9), AppleMapsTheme.navBlue], startPoint: .top, endPoint: .bottom))
                .frame(width: 11, height: 8)

            // 竹節狀立體樓層堆疊
            ForEach(0..<4, id: \.self) { idx in
                taipei101Segment(index: idx)
            }

            // 底座群樓
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 0.08, green: 0.34, blue: 0.56))
                .frame(width: 26, height: 9)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.7)
                )
        }
        .shadow(color: towerShadow, radius: 8, y: 4)
    }

    private func taipei101Segment(index idx: Int) -> some View {
        let segGradient = LinearGradient(
            colors: [
                Color(red: 0.25, green: 0.85, blue: 0.82),
                Color(red: 0.05, green: 0.45, blue: 0.68)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        let segWidth = CGFloat(16 + idx)
        return TrapezoidSegment()
            .fill(segGradient)
            .frame(width: segWidth, height: 7.5)
            .overlay(
                TrapezoidSegment()
                    .stroke(Color.white.opacity(0.55), lineWidth: 0.6)
            )
    }

    /// 立體 3D 浮空圖騰地標底座
    private var isometricPedestalModel: some View {
        let ellipseColor: Color = place.category.accentColor.opacity(isSelected ? 0.4 : 0.22)
        let cubeSize: CGFloat = isSelected ? 36 : 30
        let iconSize: CGFloat = isSelected ? 16 : 13
        let symbolName: String = place.favoriteSlot?.badgeSymbol ?? place.category.symbolName
        let pedestalGradient = LinearGradient(
            colors: place.category.gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let stemGradient = LinearGradient(
            colors: [place.category.accentColor, place.category.accentColor.opacity(0.1)],
            startPoint: .top,
            endPoint: .bottom
        )

        return ZStack {
            // 底座發光環
            Ellipse()
                .fill(ellipseColor)
                .frame(width: 34, height: 14)
                .offset(y: 14)

            // 立體建築柱體
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(pedestalGradient)
                        .frame(width: cubeSize, height: cubeSize)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                        )
                        .rotation3DEffect(.degrees(18), axis: (x: 1, y: 0, z: 0))

                    Image(systemName: symbolName)
                        .font(.system(size: iconSize, weight: .bold))
                        .foregroundStyle(Color.white)
                }

                Rectangle()
                    .fill(stemGradient)
                    .frame(width: 3, height: 10)
            }
        }
        .shadow(color: Color.black.opacity(0.25), radius: 6, y: 3)
    }
}

private struct TrapezoidSegment: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - 2.5, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + 2.5, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - 3. 高德「車道級引導條」

struct LaneGuidanceStripView: View {
    let maneuverType: ManeuverType

    var body: some View {
        let lanes: [LaneItem] = maneuverType.laneGuidanceItems
        let containerShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        HStack(spacing: 8) {
            ForEach(lanes) { lane in
                laneBadgeView(for: lane)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.82), in: containerShape)
        .overlay(
            containerShape
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.7)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 10, y: 4)
    }

    private func laneBadgeView(for lane: LaneItem) -> some View {
        let fgColor: Color = lane.isRecommended ? Color.white : Color.white.opacity(0.32)
        let bgColor: Color = lane.isRecommended ? AppleMapsTheme.navGreen.opacity(0.92) : Color.white.opacity(0.08)
        let borderColor: Color = lane.isRecommended ? Color.white.opacity(0.55) : Color.clear
        let badgeShape = RoundedRectangle(cornerRadius: 7, style: .continuous)

        return Image(systemName: lane.direction.symbolName)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(fgColor)
            .frame(width: 32, height: 30)
            .background(bgColor, in: badgeShape)
            .overlay(
                badgeShape
                    .strokeBorder(borderColor, lineWidth: 0.8)
            )
    }
}

// MARK: - 4. 高德「3D 路口實景放大圖」

struct Junction3DCrossroadView: View {
    let step: RouteStep
    let distanceMeters: Double
    let onToggleClose: () -> Void

    @State private var glowOffset: CGFloat = 0

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        ZStack(alignment: .top) {
            skylineGradientLayer
            horizonBuildingsLayer
            roadSurfaceLayer
            dashedLaneDividerLayer
            floatingDirectionArrowLayer
            headerOverlayBar
        }
        .frame(height: 158)
        .clipShape(cardShape)
        .overlay(
            cardShape
                .strokeBorder(Color.cyan.opacity(0.42), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 14, y: 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                glowOffset = -6
            }
        }
    }

    private var skylineGradientLayer: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.14, blue: 0.28),
                Color(red: 0.15, green: 0.24, blue: 0.42),
                Color(red: 0.12, green: 0.14, blue: 0.19)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var horizonBuildingsLayer: some View {
        HStack(alignment: .bottom, spacing: 6) {
            buildingBlock(w: 22, h: 48)
            buildingBlock(w: 18, h: 72)
            buildingBlock(w: 26, h: 56)
            Spacer()
            buildingBlock(w: 24, h: 64)
            buildingBlock(w: 20, h: 82)
            buildingBlock(w: 28, h: 44)
        }
        .padding(.horizontal, 12)
        .padding(.top, 26)
        .opacity(0.85)
    }

    private var roadSurfaceLayer: some View {
        let roadGradient = LinearGradient(
            colors: [Color(white: 0.26), Color(white: 0.16)],
            startPoint: .top,
            endPoint: .bottom
        )
        return ZStack {
            PerspectiveRoadSurface()
                .fill(roadGradient)
            PerspectiveRoadSurface()
                .stroke(Color.white.opacity(0.55), lineWidth: 2)
        }
        .padding(.top, 56)
    }

    private var dashedLaneDividerLayer: some View {
        VStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { idx in
                Capsule()
                    .fill(Color.white.opacity(0.65))
                    .frame(width: CGFloat(2 + idx), height: CGFloat(7 + idx * 3))
            }
        }
        .padding(.top, 64)
    }

    private var floatingDirectionArrowLayer: some View {
        let arrowGradient = LinearGradient(
            colors: [Color(red: 0.35, green: 1.0, blue: 0.72), AppleMapsTheme.navBlue],
            startPoint: .top,
            endPoint: .bottom
        )
        return Image(systemName: step.maneuverType.symbolName)
            .font(.system(size: 52, weight: .black))
            .foregroundStyle(arrowGradient)
            .shadow(color: Color.cyan.opacity(0.75), radius: 10)
            .rotation3DEffect(.degrees(44), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .offset(y: 74 + glowOffset)
    }

    private var headerOverlayBar: some View {
        let progress = max(0, min(1, 1.0 - (distanceMeters / 180.0)))
        return VStack(spacing: 6) {
            HStack {
                Label("3D 路口實景引導", systemImage: "view.3d")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.cyan)
                Spacer()
                Text(RouteFormatting.formatDistance(meters: distanceMeters))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Color.white)
                    .monospacedDigit()

                Button(action: onToggleClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }

            ProgressView(value: progress)
                .tint(Color(red: 0.35, green: 1.0, blue: 0.72))
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    private func buildingBlock(w: CGFloat, h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.25, green: 0.38, blue: 0.62), Color(red: 0.12, green: 0.18, blue: 0.32)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: w, height: h)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.cyan.opacity(0.22), lineWidth: 0.6)
            )
    }
}

private struct PerspectiveRoadSurface: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX - 34, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX + 34, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - 10, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + 10, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - 5. 高德「紅綠燈倒數讀秒」與「限速牌 / 測速照相預警」

struct TrafficLightCountdownPillView: View {
    let phase: TrafficLightPhase
    let seconds: Int

    var body: some View {
        HStack(spacing: 8) {
            VStack(spacing: 3) {
                signalBulb(isActive: phase == .red, color: Color.red)
                signalBulb(isActive: phase == .yellow, color: Color.yellow)
                signalBulb(isActive: phase == .green, color: Color.green)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .background(Color.black.opacity(0.78), in: Capsule())

            VStack(alignment: .leading, spacing: 1) {
                Text(phase.label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(phaseColor)
                Text("\(seconds)s")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .appleMapsGlassCard(cornerRadius: 16)
    }

    private func signalBulb(isActive: Bool, color: Color) -> some View {
        let bulbColor: Color = isActive ? color : color.opacity(0.22)
        return Circle()
            .fill(bulbColor)
            .frame(width: 8, height: 8)
    }

    private var phaseColor: Color {
        switch phase {
        case .red: return .red
        case .yellow: return .orange
        case .green: return AppleMapsTheme.navGreen
        }
    }
}

struct SpeedLimitSignView: View {
    let currentSpeedKMH: Double
    let speedLimitKMH: Int
    let isOverSpeed: Bool

    var body: some View {
        let bgStyle: AnyShapeStyle = isOverSpeed ? AnyShapeStyle(Color.red.opacity(0.18)) : AnyShapeStyle(.ultraThinMaterial)
        let borderColor: Color = isOverSpeed ? Color.red : Color.white.opacity(0.35)
        let borderWidth: CGFloat = isOverSpeed ? 1.5 : 0.8
        let cardShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        HStack(spacing: 8) {
            speedLimitRoundel
            digitalSpeedReadout
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(bgStyle, in: cardShape)
        .overlay(
            cardShape
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
    }

    private var speedLimitRoundel: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 38, height: 38)
            Circle()
                .strokeBorder(Color.red, lineWidth: 4)
                .frame(width: 38, height: 38)
            Text("\(speedLimitKMH)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color.black)
                .monospacedDigit()
        }
    }

    private var digitalSpeedReadout: some View {
        let speedColor: Color = isOverSpeed ? Color.red : Color.primary
        let unitColor: Color = isOverSpeed ? Color.red : Color.secondary
        let speedValue = Int(currentSpeedKMH.rounded())

        return VStack(alignment: .leading, spacing: 0) {
            Text("\(speedValue)")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(speedColor)
                .monospacedDigit()
            Text("km/h")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(unitColor)
        }
    }
}

struct SpeedCameraAlertBannerView: View {
    let alert: SpeedCameraAlert

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "camera.metering.center.weighted")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.red, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("前方 \(RouteFormatting.formatDistance(meters: alert.distanceAheadMeters)) 有\(alert.camera.name)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                Text("速限 \(alert.camera.speedLimitKMH) 公里・請注意車速")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red)
            }

            Spacer()

            Text("\(alert.camera.speedLimitKMH)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .frame(width: 30, height: 30)
                .background(Color.white, in: Circle())
                .overlay(Circle().strokeBorder(Color.red, lineWidth: 3))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .appleMapsGlassCard(cornerRadius: 18)
    }
}

struct SpeedCameraMapPinView: View {
    let camera: SpeedCameraPoint

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "video.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
            Text("\(camera.speedLimitKMH)")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color.red, in: Capsule())
        .overlay(Capsule().strokeBorder(.white, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.28), radius: 4, y: 2)
    }
}
