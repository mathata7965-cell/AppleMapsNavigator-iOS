import Foundation
import CoreLocation
import Observation

/// 3D 即時導航模擬引擎：負責沿路網平滑插值移動、轉彎倒數、語音播報、加速模擬與偏離重算
@Observable
@MainActor
final class NavigationSimulationEngine {
    private let routingService: OSRMRoutingService
    private let voiceService: VoiceGuidanceService

    private(set) var activeRoute: RouteOption?
    private(set) var destinationName: String = ""

    private(set) var currentCoordinate: CLLocationCoordinate2D = LocationManager.defaultCoordinate
    private(set) var currentHeading: CLLocationDirection = 0
    private(set) var currentSpeedKMH: Double = 0

    private(set) var traversedCoordinates: [CLLocationCoordinate2D] = []
    private(set) var remainingCoordinates: [CLLocationCoordinate2D] = []

    private(set) var currentStep: RouteStep?
    private(set) var nextStep: RouteStep?
    private(set) var distanceToNextManeuver: Double = 0
    private(set) var remainingDistanceMeters: Double = 0
    private(set) var remainingDurationSeconds: Double = 0
    private(set) var progressFraction: Double = 0

    var speedMultiplier: Double = 1.0
    var isPaused: Bool = false
    private(set) var isRerouting: Bool = false
    private(set) var isOffRouteBannerVisible: Bool = false
    private(set) var hasArrived: Bool = false

    var estimatedArrivalDate: Date {
        Date().addingTimeInterval(remainingDurationSeconds)
    }

    var onCameraTick: ((CLLocationCoordinate2D, CLLocationDirection) -> Void)?
    var onRouteReplaced: ((RouteOption) -> Void)?

    // 內部路徑進度狀態
    private var cumulativeDistances: [Double] = []
    private var totalPathMeters: Double = 0
    private var traveledMeters: Double = 0
    private var stepDistanceMarkers: [Double] = []
    private var announcedStepApproaches: Set<UUID> = []
    private var announcedStepTurns: Set<UUID> = []
    private var simulationTask: Task<Void, Never>?

    init(routingService: OSRMRoutingService, voiceService: VoiceGuidanceService) {
        self.routingService = routingService
        self.voiceService = voiceService
    }

    func startNavigation(with route: RouteOption, destinationName: String) {
        stopNavigation()

        self.destinationName = destinationName
        self.hasArrived = false
        self.isPaused = false
        self.isRerouting = false
        self.isOffRouteBannerVisible = false
        self.speedMultiplier = 1.0

        configureRouteGeometry(route)

        let firstInstruction = route.steps.first?.instruction ?? "開始導航"
        voiceService.speak("開始前往 \(destinationName)。\(firstInstruction)", interruptCurrent: true)

        launchSimulationLoop()
    }

    func stopNavigation() {
        simulationTask?.cancel()
        simulationTask = nil
        voiceService.stopSpeaking()
        activeRoute = nil
        traversedCoordinates = []
        remainingCoordinates = []
        currentStep = nil
        nextStep = nil
        hasArrived = false
        isRerouting = false
        isOffRouteBannerVisible = false
    }

    func togglePause() {
        isPaused.toggle()
        if !isPaused && hasArrived {
            isPaused = true
        }
    }

    func cycleSpeedMultiplier() {
        switch speedMultiplier {
        case 1.0: speedMultiplier = 2.0
        case 2.0: speedMultiplier = 5.0
        default: speedMultiplier = 1.0
        }
    }

    /// 模擬車輛偏離路線（橫向偏移約 180 公尺並觸發 OSRM 自動重新規劃）
    func simulateOffRouteDeviation() {
        guard let route = activeRoute,
              let destination = route.coordinates.last,
              !isRerouting,
              !hasArrived else { return }

        isRerouting = true
        isOffRouteBannerVisible = true
        let wasPaused = isPaused
        isPaused = true

        // 計算垂直目前航向約 180 公尺的偏離座標
        let perpHeadingRad = (currentHeading + 90.0) * .pi / 180.0
        let offsetMeters = 180.0
        let dLat = (offsetMeters * cos(perpHeadingRad)) / 111_320.0
        let dLon = (offsetMeters * sin(perpHeadingRad)) / (111_320.0 * max(0.2, cos(currentCoordinate.latitude * .pi / 180.0)))

        let deflectedCoord = CLLocationCoordinate2D(
            latitude: currentCoordinate.latitude + dLat,
            longitude: currentCoordinate.longitude + dLon
        )

        currentCoordinate = deflectedCoord
        onCameraTick?(deflectedCoord, currentHeading)

        voiceService.speak("您已偏離路線，正在重新規劃路線。", interruptCurrent: true)

        Task {
            try? await Task.sleep(for: .milliseconds(900))
            let newRoutes = await routingService.calculateRoutes(
                from: deflectedCoord,
                to: destination,
                mode: route.transportMode
            )

            guard !Task.isCancelled else { return }

            if let newPrimary = newRoutes.first {
                configureRouteGeometry(newPrimary)
                onRouteReplaced?(newPrimary)
                voiceService.speak("已重新規劃路線，\(newPrimary.steps.first?.instruction ?? "請依路線繼續前進")")
            }

            isRerouting = false
            isPaused = wasPaused

            try? await Task.sleep(for: .seconds(2.5))
            if !Task.isCancelled {
                isOffRouteBannerVisible = false
            }
        }
    }

    // MARK: - 幾何與步驟計算

    private func configureRouteGeometry(_ route: RouteOption) {
        self.activeRoute = route
        let coords = route.coordinates
        guard coords.count >= 2 else { return }

        var cum: [Double] = [0]
        var total: Double = 0
        for i in 1..<coords.count {
            let a = CLLocation(latitude: coords[i - 1].latitude, longitude: coords[i - 1].longitude)
            let b = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            total += a.distance(from: b)
            cum.append(total)
        }

        self.cumulativeDistances = cum
        self.totalPathMeters = max(1, total)
        self.traveledMeters = 0

        // 對齊每一個 RouteStep 的累積距離里程碑
        var markers: [Double] = []
        var running: Double = 0
        for step in route.steps {
            markers.append(running)
            running += step.distanceMeters
        }
        // 比例校正，使步驟距離與幾何總長一致
        if running > 0 {
            let scale = total / running
            markers = markers.map { $0 * scale }
        }
        self.stepDistanceMarkers = markers

        self.announcedStepApproaches = []
        self.announcedStepTurns = []

        updateTelemetryAtDistance(0)
    }

    private func launchSimulationLoop() {
        simulationTask?.cancel()
        simulationTask = Task { [weak self] in
            let tickIntervalSeconds = 0.05 // 20 FPS 流暢跟隨
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled, let self else { break }
                if !self.isPaused && !self.isRerouting && !self.hasArrived {
                    self.advanceSimulation(deltaSeconds: tickIntervalSeconds)
                }
            }
        }
    }

    private func advanceSimulation(deltaSeconds: Double) {
        guard let route = activeRoute else { return }

        let baseSpeed = route.transportMode.defaultSimulationSpeedMPS
        let effectiveSpeed = baseSpeed * speedMultiplier
        traveledMeters = min(totalPathMeters, traveledMeters + effectiveSpeed * deltaSeconds)
        currentSpeedKMH = effectiveSpeed * 3.6

        updateTelemetryAtDistance(traveledMeters)
        onCameraTick?(currentCoordinate, currentHeading)

        if traveledMeters >= totalPathMeters - 2.0 {
            handleArrival()
        }
    }

    private func updateTelemetryAtDistance(_ meters: Double) {
        guard let route = activeRoute else { return }
        let coords = route.coordinates
        guard coords.count >= 2, cumulativeDistances.count == coords.count else { return }

        // 尋找所在線段
        var segIndex = 0
        for i in 1..<cumulativeDistances.count {
            if meters <= cumulativeDistances[i] {
                segIndex = i - 1
                break
            }
            segIndex = coords.count - 2
        }

        let startDist = cumulativeDistances[segIndex]
        let endDist = cumulativeDistances[segIndex + 1]
        let segLength = max(0.001, endDist - startDist)
        let t = min(1, max(0, (meters - startDist) / segLength))

        let p0 = coords[segIndex]
        let p1 = coords[segIndex + 1]

        currentCoordinate = CLLocationCoordinate2D(
            latitude: p0.latitude + (p1.latitude - p0.latitude) * t,
            longitude: p0.longitude + (p1.longitude - p0.longitude) * t
        )
        currentHeading = bearingBetween(p0, p1)

        traversedCoordinates = Array(coords.prefix(segIndex + 1)) + [currentCoordinate]
        remainingCoordinates = [currentCoordinate] + Array(coords.suffix(from: segIndex + 1))

        progressFraction = min(1, max(0, meters / totalPathMeters))
        remainingDistanceMeters = max(0, totalPathMeters - meters)

        let ratioRemaining = 1.0 - progressFraction
        remainingDurationSeconds = max(0, route.durationSeconds * ratioRemaining)

        updateStepGuidance(at: meters, steps: route.steps)
    }

    private func updateStepGuidance(at meters: Double, steps: [RouteStep]) {
        guard !steps.isEmpty, stepDistanceMarkers.count == steps.count else { return }

        var activeIdx = 0
        for i in 0..<stepDistanceMarkers.count {
            if meters >= stepDistanceMarkers[i] {
                activeIdx = i
            }
        }

        let nextIdx = min(steps.count - 1, activeIdx + 1)
        let upcomingStep = steps[nextIdx]
        let upcomingMarker = nextIdx < stepDistanceMarkers.count ? stepDistanceMarkers[nextIdx] : totalPathMeters

        // 若已到最後一步，呈現當前步驟與終點距離
        if activeIdx == steps.count - 1 {
            currentStep = steps[activeIdx]
            nextStep = nil
            distanceToNextManeuver = max(0, totalPathMeters - meters)
        } else {
            currentStep = upcomingStep
            nextStep = (nextIdx + 1 < steps.count) ? steps[nextIdx + 1] : nil
            distanceToNextManeuver = max(0, upcomingMarker - meters)

            // 語音觸發：200 公尺前提醒 + 40 公尺內即將轉彎
            if distanceToNextManeuver <= 200 && distanceToNextManeuver > 60 && !announcedStepApproaches.contains(upcomingStep.id) {
                announcedStepApproaches.insert(upcomingStep.id)
                let distText = RouteFormatting.formatDistance(meters: distanceToNextManeuver)
                voiceService.speak("前方 \(distText)，\(upcomingStep.instruction)")
            } else if distanceToNextManeuver <= 40 && !announcedStepTurns.contains(upcomingStep.id) {
                announcedStepTurns.insert(upcomingStep.id)
                voiceService.speak(upcomingStep.instruction)
            }
        }
    }

    private func handleArrival() {
        guard !hasArrived else { return }
        hasArrived = true
        isPaused = true
        currentSpeedKMH = 0
        remainingDistanceMeters = 0
        remainingDurationSeconds = 0
        distanceToNextManeuver = 0
        if let lastStep = activeRoute?.steps.last {
            currentStep = lastStep
        }
        nextStep = nil
        voiceService.speak("您已抵達目的地 \(destinationName)。", interruptCurrent: true)
    }

    private func bearingBetween(_ start: CLLocationCoordinate2D, _ end: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = start.latitude * .pi / 180.0
        let lon1 = start.longitude * .pi / 180.0
        let lat2 = end.latitude * .pi / 180.0
        let lon2 = end.longitude * .pi / 180.0

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)
        let degrees = radians * 180.0 / .pi
        return (degrees + 360.0).truncatingRemainder(dividingBy: 360.0)
    }
}
