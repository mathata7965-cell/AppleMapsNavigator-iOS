import SwiftUI
import CoreLocation

/// 探索與搜尋面板（搜尋列、分類快選膠囊、常用收藏橫向列表、近期搜尋與即時結果）
struct ExploreSearchSheetView: View {
    @Bindable var viewModel: MapNavigatorViewModel
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
            searchBarHeader

            categoryPillsRow

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || viewModel.selectedCategory != nil {
                        searchResultsSection
                    } else {
                        favoritesSection
                        recentSearchesSection
                        nearbyCuratedSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .onChange(of: isSearchFieldFocused) { _, focused in
            if focused && viewModel.sheetDetent == .collapsed {
                viewModel.sheetDetent = .expanded
            }
        }
    }

    // MARK: - 頂部搜尋列

    private var searchBarHeader: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("搜尋地點、餐廳、加油站或地址", text: $viewModel.searchQuery)
                    .focused($isSearchFieldFocused)
                    .submitLabel(.search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit {
                        Task {
                            await viewModel.executeSearch(query: viewModel.searchQuery)
                        }
                    }

                if viewModel.isSearching {
                    ProgressView()
                        .controlSize(.small)
                } else if !viewModel.searchQuery.isEmpty || viewModel.selectedCategory != nil {
                    Button {
                        viewModel.clearSearch()
                        isSearchFieldFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground).opacity(0.85), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            // 使用者快捷頭像 / 主題提示按鈕
            Button {
                viewModel.cycleThemeMode()
            } label: {
                Image(systemName: viewModel.themeMode.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppleMapsTheme.navBlue)
                    .frame(width: 40, height: 40)
                    .background(Color(.secondarySystemGroupedBackground).opacity(0.85), in: Circle())
            }
            .accessibilityLabel("切換深淺色模式")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - 分類快選膠囊

    private var categoryPillsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PlaceCategory.allCases) { category in
                    categoryPillButton(for: category)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func categoryPillButton(for category: PlaceCategory) -> some View {
        let isActive = viewModel.selectedCategory == category
        let iconColor: Color = isActive ? Color.white : category.accentColor
        let textColor: Color = isActive ? Color.white : Color.primary
        let bgStyle: AnyShapeStyle = isActive
            ? AnyShapeStyle(category.accentColor)
            : AnyShapeStyle(Color(.secondarySystemGroupedBackground).opacity(0.9))
        let borderColor: Color = isActive ? Color.white.opacity(0.35) : Color.primary.opacity(0.06)

        return Button {
            viewModel.selectCategory(category)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.symbolName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(iconColor)
                Text(category.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(textColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(bgStyle, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(borderColor, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 常用地點收藏區

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("常用地點")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.favorites.count) 個已收藏")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.favorites) { place in
                        favoritePlaceItem(for: place)
                    }
                }
            }
        }
    }

    private func favoritePlaceItem(for place: PlaceItem) -> some View {
        let tintColor: Color = place.favoriteSlot?.badgeColor ?? place.category.accentColor
        let symbolName: String = place.favoriteSlot?.badgeSymbol ?? place.category.symbolName
        let distText: String = place.formattedDistance(from: viewModel.locationManager.effectiveCoordinate)

        return Button {
            viewModel.selectPlace(place)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(tintColor.opacity(0.16))
                        .frame(width: 52, height: 52)

                    Image(systemName: symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(tintColor)
                }

                Text(place.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(distText)
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }
            .frame(width: 82)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(Color(.secondarySystemGroupedBackground).opacity(0.75), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 近期搜尋

    private var recentSearchesSection: some View {
        Group {
            if !viewModel.recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("近期瀏覽")
                        .font(.headline)

                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.recentSearches.prefix(4).enumerated()), id: \.element.id) { index, place in
                            PlaceResultRow(
                                place: place,
                                userCoordinate: viewModel.locationManager.effectiveCoordinate,
                                onSelect: { viewModel.selectPlace(place) },
                                onDirections: { viewModel.openRoutePlanning(to: place) }
                            )
                            if index < min(3, viewModel.recentSearches.count - 1) {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    // MARK: - 附近精選推薦

    private var nearbyCuratedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("探索台北信義周邊")
                    .font(.headline)
                Spacer()
                Text("OSM + MapKit")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(PlaceItem.curatedTaipeiPOIs.prefix(6).enumerated()), id: \.element.id) { index, place in
                    PlaceResultRow(
                        place: place,
                        userCoordinate: viewModel.locationManager.effectiveCoordinate,
                        onSelect: { viewModel.selectPlace(place) },
                        onDirections: { viewModel.openRoutePlanning(to: place) }
                    )
                    if index < 5 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: - 即時搜尋結果

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let category = viewModel.selectedCategory {
                    Text("附近「\(category.title)」")
                        .font(.headline)
                } else {
                    Text("搜尋結果")
                        .font(.headline)
                }
                Spacer()
                if !viewModel.isSearching {
                    Text("\(viewModel.searchResults.count) 筆地點")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.isSearching && viewModel.searchResults.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("正在查詢 OpenStreetMap 與附近地點...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemGroupedBackground).opacity(0.75), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else if viewModel.searchResults.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "mappin.slash.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("找不到符合的地點")
                        .font(.subheadline.weight(.semibold))
                    Text("試試看其他關鍵字，或點選上方分類膠囊快速瀏覽。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color(.secondarySystemGroupedBackground).opacity(0.75), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, place in
                        PlaceResultRow(
                            place: place,
                            userCoordinate: viewModel.locationManager.effectiveCoordinate,
                            onSelect: {
                                isSearchFieldFocused = false
                                viewModel.selectPlace(place)
                            },
                            onDirections: {
                                isSearchFieldFocused = false
                                viewModel.openRoutePlanning(to: place)
                            }
                        )
                        if index < viewModel.searchResults.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground).opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

// MARK: - 單一地點列

private struct PlaceResultRow: View {
    let place: PlaceItem
    let userCoordinate: CLLocationCoordinate2D
    let onSelect: () -> Void
    let onDirections: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(place.category.accentColor.opacity(0.16))
                            .frame(width: 40, height: 40)
                        Image(systemName: place.category.symbolName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(place.category.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(place.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(place.address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(place.formattedDistance(from: userCoordinate))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(AppleMapsTheme.navBlue)
                            Text("・")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(place.sourceLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onDirections) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppleMapsTheme.navBlue)
                    .frame(width: 36, height: 36)
                    .background(AppleMapsTheme.navBlue.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("規劃前往 \(place.name) 的路線")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
