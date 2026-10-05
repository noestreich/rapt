import Foundation
#if os(iOS)
import CoreHaptics
import UIKit
#endif

/// Vibrationsmuster für das iPhone. Auf dem Mac tut diese Klasse nichts.
final class Haptics {
    static let shared = Haptics()

    #if os(iOS)
    private var engine: CHHapticEngine?
    private let fallback = UIImpactFeedbackGenerator(style: .medium)

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        try? engine?.start()
    }

    private var isEnabled: Bool { GameSettings.shared.hapticsEnabled }

    private func transient(_ time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time)
    }

    private func continuous(_ time: TimeInterval, duration: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time, duration: duration)
    }

    private func fade(from start: TimeInterval, duration: TimeInterval, peak: Float) -> CHHapticParameterCurve {
        CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: start, value: peak),
            .init(relativeTime: start + duration, value: 0),
        ], relativeTime: 0)
    }

    private func play(_ events: [CHHapticEvent], curves: [CHHapticParameterCurve] = [], fallbackIntensity: CGFloat) {
        guard isEnabled else { return }
        guard let engine else {
            fallback.impactOccurred(intensity: fallbackIntensity)
            return
        }
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            try engine.start()
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback.impactOccurred(intensity: fallbackIntensity)
        }
    }

    func select() {
        play([transient(0, intensity: 0.35, sharpness: 0.8)], fallbackIntensity: 0.3)
    }

    func invalid() {
        play([transient(0, intensity: 0.5, sharpness: 0.3), transient(0.09, intensity: 0.5, sharpness: 0.3)], fallbackIntensity: 0.5)
    }

    /// Treffer, mit jeder Kaskadenstufe kräftiger.
    func match(combo: Int) {
        let intensity = min(1, 0.45 + 0.15 * Float(combo - 1))
        play([transient(0, intensity: intensity, sharpness: 0.55)], fallbackIntensity: CGFloat(intensity))
    }

    /// Kurzer Schlag und abklingendes Grollen.
    func explosion() {
        play([
            transient(0, intensity: 1, sharpness: 0.7),
            continuous(0.02, duration: 0.45, intensity: 0.9, sharpness: 0.15),
        ], curves: [fade(from: 0.02, duration: 0.45, peak: 1)], fallbackIntensity: 1)
    }

    /// Anschwellendes Surren für die Schockwelle.
    func warp() {
        play([continuous(0, duration: 0.3, intensity: 0.6, sharpness: 0.9)],
             curves: [fade(from: 0, duration: 0.3, peak: 1)], fallbackIntensity: 0.6)
    }

    func plan() {
        play((0..<4).map { transient(Double($0) * 0.08, intensity: 0.5 + 0.15 * Float($0), sharpness: 0.6) }, fallbackIntensity: 0.8)
    }
    #else
    private init() {}
    func select() {}
    func invalid() {}
    func match(combo: Int) {}
    func explosion() {}
    func warp() {}
    func plan() {}
    #endif
}
