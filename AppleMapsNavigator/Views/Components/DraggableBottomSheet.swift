import SwiftUI

/// 仿 Apple Maps iOS 原生三段式可拖拽毛玻璃底部面板 (.collapsed / .medium / .expanded)
struct DraggableBottomSheet<Content: View>: View {
    @Binding var detent: SheetDetent
    let containerHeight: CGFloat
    let safeAreaBottom: CGFloat
    @ViewBuilder let content: () -> Content

    @GestureState private var dragTranslation: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    private var collapsedHeight: CGFloat { 112 + safeAreaBottom }
    private var mediumHeight: CGFloat { max(320, containerHeight * 0.44) }
    private var expandedHeight: CGFloat { max(480, containerHeight * 0.87) }

    private var targetHeight: CGFloat {
        switch detent {
        case .collapsed: return collapsedHeight
        case .medium: return mediumHeight
        case .expanded: return expandedHeight
        }
    }

    private var currentHeight: CGFloat {
        let proposed = targetHeight - dragTranslation
        if proposed < collapsedHeight {
            let excess = collapsedHeight - proposed
            return collapsedHeight - excess * 0.25
        } else if proposed > expandedHeight {
            let excess = proposed - expandedHeight
            return expandedHeight + excess * 0.22
        }
        return proposed
    }

    var body: some View {
        VStack(spacing: 0) {
            // 頂部拖曳把手區域
            VStack(spacing: 8) {
                Capsule()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 38, height: 5)
                    .padding(.top, 9)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(sheetDragGesture)

            // 內容區
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: max(96, currentHeight), alignment: .top)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: UnevenRoundedRectangle(
            topLeadingRadius: 26,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 26,
            style: .continuous
        ))
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 26,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 26,
                style: .continuous
            )
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.24 : 0.7),
                        Color.white.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.9
            )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.16), radius: 22, x: 0, y: -6)
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: detent)
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.88), value: dragTranslation == 0)
    }

    private var sheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let predictedHeight = targetHeight - value.predictedEndTranslation.height
                let candidates: [(SheetDetent, CGFloat)] = [
                    (.collapsed, collapsedHeight),
                    (.medium, mediumHeight),
                    (.expanded, expandedHeight)
                ]
                if let closest = candidates.min(by: { abs($0.1 - predictedHeight) < abs($1.1 - predictedHeight) }) {
                    detent = closest.0
                }
            }
    }

    /// 供右側懸浮控制按鈕對齊目前面板頂部高度
    static func visualHeight(for detent: SheetDetent, containerHeight: CGFloat, safeAreaBottom: CGFloat) -> CGFloat {
        switch detent {
        case .collapsed: return 112 + safeAreaBottom
        case .medium: return max(320, containerHeight * 0.44)
        case .expanded: return max(480, containerHeight * 0.87)
        }
    }
}
