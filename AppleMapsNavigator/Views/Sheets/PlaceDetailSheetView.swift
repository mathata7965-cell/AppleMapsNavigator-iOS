import SwiftUI
import MapKit

/// 地點詳情面板（含 Look Around 街景預覽、收藏按鈕、快速動作與路線/導航入口）
struct PlaceDetailSheetView: View {
    @Bindable var viewModel: MapNavigatorViewModel
    let place: PlaceItem

    @State private var lookAroundScene: MKLookAroundScene?
    @State private var didCheckLookAround = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                headerSection

                primaryActionButtons

                quickUtilityStrip

                lookAroundCard

                metadataInfoCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .task(id: place.id) {
            await loadLookAroundScene()
        }
    }

    // MARK: - 標題與關閉按鈕

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: place.category.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: place.category.symbolName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(place.category.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(place.category.accentColor)

                    Text("・")
                        .foregroundStyle(.secondary)

                    Text(place.formattedDistance(from: viewModel.locationManager.effectiveCoordinate))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    if let rating = place.rating {
                        Text("・")
                            .foregroundStyle(.secondary)
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            Button {
                viewModel.dismissToExplore()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.secondary.opacity(0.75))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - 路線規劃主行動按鈕

    private var primaryActionButtons: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.openRoutePlanning(to: place)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 16, weight: .semibold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("路線規劃")
                            .font(.subheadline.weight(.bold))
                        Text("開車・步行・單車")
                            .font(.caption2)
                            .opacity(0.88)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppleMapsTheme.navBlue, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                viewModel.toggleFavorite(place)
            } label: {
                let saved = viewModel.isFavorite(place)
                let favColor: Color = saved ? Color.pink : Color.primary
                HStack(spacing: 6) {
                    Image(systemName: saved ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold))
                    Text(saved ? "已收藏" : "收藏")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(favColor)
                .frame(width: 112)
                .padding(.vertical, 17)
                .background(Color(.secondarySystemGroupedBackground).opacity(0.9), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 快捷動作列

    private var quickUtilityStrip: some View {
        HStack(spacing: 10) {
            if let phone = place.phoneNumber,
               let telURL = URL(string: "tel://\(phone.filter { $0.isNumber })") {
                Link(destination: telURL) {
                    Label("致電", systemImage: "phone.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemGroupedBackground).opacity(0.85), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            ShareLink(item: "\(place.name)\n\(place.address)\n座標：\(place.latitude), \(place.longitude)") {
                Label("分享地點", systemImage: "square.and.arrow.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground).opacity(0.85), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button {
                viewModel.focusCamera(on: place.coordinate, distance: 650)
            } label: {
                Label("拉近 3D", systemImage: "view.3d")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground).opacity(0.85), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - iOS 17 Look Around 街景預覽卡片

    @ViewBuilder
    private var lookAroundCard: some View {
        if let scene = lookAroundScene {
            VStack(alignment: .leading, spacing: 6) {
                Text("街景環視 Look Around")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                LookAroundPreview(initialScene: scene)
                    .frame(height: 145)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        } else if didCheckLookAround {
            HStack(spacing: 12) {
                Image(systemName: "binoculars.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppleMapsTheme.navBlue)
                    .frame(width: 40, height: 40)
                    .background(AppleMapsTheme.navBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("3D 衛星與街區視圖")
                        .font(.subheadline.weight(.semibold))
                    Text("點選上方「拉近 3D」或右側切換衛星混合圖層查看立體地標")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground).opacity(0.75), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - 詳細資訊卡片

    private var metadataInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("詳細資訊")
                .font(.headline)

            VStack(spacing: 10) {
                infoRow(title: "地址", value: place.address, icon: "mappin.and.ellipse")
                Divider()
                infoRow(
                    title: "經緯度座標",
                    value: String(format: "%.5f, %.5f", place.latitude, place.longitude),
                    icon: "location.viewfinder"
                )
                if let phone = place.phoneNumber {
                    Divider()
                    infoRow(title: "聯絡電話", value: phone, icon: "phone")
                }
                Divider()
                infoRow(title: "資料來源", value: place.sourceLabel, icon: "network")
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground).opacity(0.8), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func infoRow(title: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
    }

    private func loadLookAroundScene() async {
        didCheckLookAround = false
        lookAroundScene = nil
        let request = MKLookAroundSceneRequest(coordinate: place.coordinate)
        let scene = try? await request.scene
        lookAroundScene = scene
        didCheckLookAround = true
    }
}
