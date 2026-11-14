import SwiftUI
import CoreLocation

/// Apple Maps 高質感設計系統 Tokens 與毛玻璃元件
enum AppleMapsTheme {
    static let navBlue = Color(red: 0.0, green: 0.478, blue: 1.0)            // #007AFF
    static let routeCasingBlue = Color(red: 0.0, green: 0.31, blue: 0.68)    // #004FAD
    static let routeAlternative = Color(red: 0.42, green: 0.68, blue: 0.98)
    static let navGreen = Color(red: 0.14, green: 0.78, blue: 0.42)          // #24C76B
    static let navGreenDark = Color(red: 0.07, green: 0.58, blue: 0.31)
    static let warningAmber = Color(red: 1.0, green: 0.62, blue: 0.04)
}

// MARK: - 毛玻璃卡片修飾器

struct AppleMapsGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.24 : 0.65),
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.42 : 0.14),
                radius: 18,
                x: 0,
                y: 8
            )
    }
}

extension View {
    func appleMapsGlassCard(cornerRadius: CGFloat = 22) -> some View {
        modifier(AppleMapsGlassCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - 使用者藍色脈衝定位點

struct UserLocationPulseMarkerView: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(AppleMapsTheme.navBlue.opacity(0.22))
                .frame(width: 44, height: 44)
                .scaleEffect(isPulsing ? 1.35 : 0.75)
                .opacity(isPulsing ? 0.0 : 0.85)

            Circle()
                .fill(Color.white)
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.24), radius: 4, y: 2)

            Circle()
                .fill(AppleMapsTheme.navBlue)
                .frame(width: 15, height: 15)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.9).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - 3D 導航箭頭與視野錐形光束

struct NavigationVehicleMarkerView: View {
    let headingDegrees: Double

    var body: some View {
        ZStack {
            // 前方視野光束扇形
            NavigationBeamCone()
                .fill(
                    LinearGradient(
                        colors: [
                            AppleMapsTheme.navBlue.opacity(0.45),
                            AppleMapsTheme.navBlue.opacity(0.0)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 58, height: 54)
                .offset(y: -24)

            // 外層白邊陰影圓盤
            Circle()
                .fill(Color.white)
                .frame(width: 34, height: 34)
                .shadow(color: Color.black.opacity(0.32), radius: 8, y: 3)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppleMapsTheme.navBlue, AppleMapsTheme.routeCasingBlue],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 27, height: 27)

            Image(systemName: "location.north.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .offset(y: -1)
        }
        .rotationEffect(.degrees(headingDegrees))
    }
}

private struct NavigationBeamCone: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.minY - 6)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - iOS 風格精選地點圖釘

struct PlaceAnnotationPinView: View {
    let place: PlaceItem
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(place.category.accentColor.opacity(0.28))
                        .frame(width: 52, height: 52)
                }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: place.category.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isSelected ? 40 : 32, height: isSelected ? 40 : 32)
                    .overlay(
                        Circle()
                            .strokeBorder(.white, lineWidth: isSelected ? 2.5 : 1.8)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: isSelected ? 8 : 4, y: 3)

                Image(systemName: place.favoriteSlot?.badgeSymbol ?? place.category.symbolName)
                    .font(.system(size: isSelected ? 17 : 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isSelected ? 1.08 : 1.0)

            Text(place.name)
                .font(.system(size: isSelected ? 12 : 11, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.72), value: isSelected)
    }
}

// MARK: - 起點與終點標記

struct RouteEndpointBadgeView: View {
    let isDestination: Bool
    let title: String

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isDestination ? Color.red : AppleMapsTheme.navBlue)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.28), radius: 6, y: 3)

                Image(systemName: isDestination ? "flag.checkered" : "circle.inset.filled")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(title)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}
