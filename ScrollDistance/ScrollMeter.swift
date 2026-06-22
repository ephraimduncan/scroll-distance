import AppKit
import Combine
import CoreGraphics

enum DistanceUnit: String {
    case metric
    case imperial
}

final class ScrollMeter: ObservableObject {
    @Published var label: String = ""
    @Published var unit: DistanceUnit {
        didSet {
            defaults.set(unit.rawValue, forKey: Keys.unit)
            label = makeLabel()
        }
    }

    private let defaults = UserDefaults.standard
    private var accumulatedMeters: Double
    private var lastPersistedMeters: Double
    private var monitor: Any?
    private var timer: Timer?
    private var densityCache: [CGDirectDisplayID: Double] = [:]

    private let mouseWheelLineHeight: Double = 10
    private let fallbackPointsPerMM = 72.0 / 25.4

    private enum Keys {
        static let meters = "accumulatedMeters"
        static let unit = "unit"
    }

    init() {
        accumulatedMeters = defaults.double(forKey: Keys.meters)
        lastPersistedMeters = accumulatedMeters
        unit = DistanceUnit(rawValue: defaults.string(forKey: Keys.unit) ?? "") ?? .metric
        label = ""
        label = makeLabel()

        startMonitoring()
        startTimer()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(persist),
            name: NSApplication.willTerminateNotification, object: nil)
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func reset() {
        accumulatedMeters = 0
        lastPersistedMeters = 0
        defaults.set(0.0, forKey: Keys.meters)
        label = makeLabel()
    }

    private func startMonitoring() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return }
            var dy = Double(event.scrollingDeltaY)
            if !event.hasPreciseScrollingDeltas { dy *= self.mouseWheelLineHeight }
            guard dy != 0 else { return }
            let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
            guard let screen else { return }
            self.accumulatedMeters += abs(dy) / self.pointsPerMM(for: screen) / 1000.0
        }
    }

    private func startTimer() {
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let newLabel = makeLabel()
        if newLabel != label { label = newLabel }
        if accumulatedMeters != lastPersistedMeters {
            defaults.set(accumulatedMeters, forKey: Keys.meters)
            lastPersistedMeters = accumulatedMeters
        }
    }

    @objc private func persist() {
        defaults.set(accumulatedMeters, forKey: Keys.meters)
        lastPersistedMeters = accumulatedMeters
    }

    @objc private func screensChanged() {
        densityCache.removeAll()
    }

    private func pointsPerMM(for screen: NSScreen) -> Double {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return fallbackPointsPerMM
        }
        let id = CGDirectDisplayID(number.uint32Value)
        if let cached = densityCache[id] { return cached }
        let mm = CGDisplayScreenSize(id)
        let density = mm.width > 0 ? Double(screen.frame.width) / mm.width : fallbackPointsPerMM
        densityCache[id] = density
        return density
    }

    private func makeLabel() -> String {
        let m = accumulatedMeters
        switch unit {
        case .metric:
            if m < 1000 { return String(format: "%.0f m", m) }
            return String(format: "%.2f km", m / 1000)
        case .imperial:
            let miles = m / 1609.344
            if miles < 0.1 { return String(format: "%.0f ft", m * 3.28084) }
            return String(format: "%.2f mi", miles)
        }
    }
}
