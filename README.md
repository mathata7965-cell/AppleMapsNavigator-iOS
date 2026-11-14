# AppleMapsNavigator — iOS 高質感類 Apple Maps 導航軟體

基於 **SwiftUI + MapKit (iOS 17+)** 打造的原生 iOS 3D 地圖導航專案，結合 Apple Maps 的毛玻璃 Liquid Glass 互動體驗與 **開源免金鑰 OpenStreetMap (Nominatim) + OSRM 多模式路線規劃引擎**。

---

## 核心特色

1. **仿 iOS 原生毛玻璃 UI 與 3D 地圖畫布**
   - `.ultraThinMaterial` 半透明材質、頂部高光細邊框與柔和環境陰影。
   - 支援 **標準 3D**（含真實地形與立體建築）、**衛星混合**、**OSM 開源圖磚 (`MKTileOverlay`)** 三種圖層即時切換。
   - 支援 **跟隨系統 / 日間淺色 / 夜間深色** 外觀一鍵切換，以及 **3D/2D 視角傾斜** 與 **動態指南針回正**。

2. **三段式可拖拽底部面板 (`DraggableBottomSheet`)**
   - 支援 `.collapsed`（收合）、`.medium`（半開）、`.expanded`（全展開）三段彈性吸附手勢。
   - 整合即時地點搜尋（OpenStreetMap Nominatim + `MKLocalSearch` 雙引擎）、8 大分類快選膠囊（餐廳、咖啡廳、加油站、停車場、充電站、便利商店、醫療院所、熱門景點）、常用地點收藏與近期瀏覽持久化。

3. **地點詳情與 Look Around 預覽 (`PlaceDetailSheetView`)**
   - 整合 iOS 17 `LookAroundPreview` 街景環視、`ShareLink` 分享、電話撥打與收藏狀態切換。

4. **多模式路線規劃與方案比較 (`RoutePlanningSheetView`)**
   - 透過開源 **OSRM REST API**（並內建 `MKDirections` 與離線幾何備援）同時計算 **開車 / 步行 / 單車** 預估時間，支援多條替代路線在畫布上對比切換與起終點互換。
   - 路線採用雙層深藍外框 + iOS 導航藍 (`#007AFF`) 描邊，並提供完整繁體中文分段轉彎步驟預覽。

5. **3D Turn-by-Turn 模擬導航與偏離重算 (`TurnByTurnHUDView`)**
   - 頂部高對比轉彎指示卡、倒數距離、「接著」次一步預告與繁體中文 `AVSpeechSynthesizer` 語音播報。
   - 20 Hz 平滑 3D 鏡頭跟隨、方向光束錐形車標，已行駛路段自動轉為霧面灰。
   - 內建 **1x / 2x / 5x 模擬加速**、暫停/繼續，以及 **「模擬偏離重算」** 按鈕，可一鍵測試偏離路網 180 公尺後自動觸發語音提示並向 OSRM 重新請求路線。

---

## 如何在 Mac / Xcode 執行

1. 將整個 `AppleMapsNavigator_iOS` 資料夾複製至 macOS 環境。
2. 直接雙擊開啟 `AppleMapsNavigator.xcodeproj`（或若本機已安裝 XcodeGen，可在專案根目錄執行 `xcodegen generate`）。
3. 選擇任一 **iOS 17.0+** 模擬器（例如 `iPhone 15 Pro` / `iPhone 16 Pro`）或實機，按下 `Cmd + R` 編譯執行。
4. 首次啟動於模擬器若尚未設定定位點，系統將自動定位於 **台北 101 / 信義商圈 (`25.033964, 121.564468`)**，可立即測試搜尋、分類、多模式規劃與 Turn-by-Turn 模擬導航。

---

## 如何打包成 `.ipa` 並安裝到 iPhone

> **為什麼 Windows 本機無法直接離線編譯 `.ipa`？**  
> 本專案為原生 SwiftUI + MapKit 應用程式，編譯 iOS 原生 Mach-O 執行檔與連結 `UIKit` / `MapKit` / `SwiftUI` SDK 必須依賴 macOS 上的 `xcodebuild` 與 Apple iOS SDK，Windows 環境並未內建 iOS 編譯工具鏈。不過您可以透過下方的 **GitHub Actions 免費雲端 macOS 編譯**，直接在 Windows 取得可安裝的 `.ipa`。

### 方式一：Windows 一鍵雲端免費編譯並下載 `.ipa`（免安裝 Git 與 Xcode）

專案已內建針對側載（Sideloadly / AltStore / SideStore / Feather / ESign / TrollStore）優化的 **Ad-Hoc 簽章與 App 圖示資源目錄 (`Assets.xcassets`)**，以及純 PowerShell 雲端編譯腳本 [`Build-IPA-Cloud.ps1`](Build-IPA-Cloud.ps1)：

1. 申請一個免費 GitHub Personal Access Token（勾選 `repo` 與 `workflow` 權限）。
2. 在專案根目錄開啟 PowerShell 執行：
   ```powershell
   .\Build-IPA-Cloud.ps1
   ```
3. 腳本會自動透過 GitHub REST API 建立倉庫、上傳專案、觸發 GitHub 免費的 `macos-14`（Xcode 15.4）雲端編譯，並在約 2～3 分鐘後自動將 `AppleMapsNavigator.ipa` 下載回本資料夾。
4. **側載安裝到 iPhone**：
   - 使用 **Sideloadly**、**AltStore**、**SideStore** 或 **Feather / ESign / TrollStore** 直接匯入 `AppleMapsNavigator.ipa` 即可安裝（使用免費個人 Apple ID 側載時，初次安裝後至 iPhone「設定 → 一般 → VPN 與裝置管理」信任憑證即可開啟）。

也可以手動將專案推送到 GitHub 後，直接到倉庫的 **Actions → Build Sideload-Ready IPA → Artifacts** 下載 `AppleMapsNavigator-ipa`。

### 方式二：在 macOS 本機一鍵打包 `.ipa`

若您手邊有 Mac 且已安裝 Xcode 15+，可在專案根目錄執行：

```bash
chmod +x scripts/build_ipa.sh
./scripts/build_ipa.sh
```

執行完成後會在專案根目錄產生 `AppleMapsNavigator.ipa`（未簽章之 Release 套件，可直接以 Sideloadly / AltStore 安裝，或於 Xcode 中設定開發者團隊進行簽章匯出）。
