import CoreHaptics
import UIKit

/// Tactile vocabulary of the app. Every named effect is a small piece of
/// physical theatre: the gate punch, the rubber stamp, the paper tick.
@MainActor
enum Haptic {
    enum Effect {
        /// Light paper tick — selection, field focus.
        case tick
        /// 改札パンチ — sharp clack with a low after-knock.
        case punch
        /// はんこ — heavy press with a soft settle.
        case stamp
        /// Two soft rising taps — save confirmed.
        case success
        /// Faint slide notch used while paging.
        case page
    }

    private static var engine: CHHapticEngine?
    private static var engineReady = false

    static func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.resetHandler = { engineReady = false }
            engine.stoppedHandler = { _ in engineReady = false }
            try engine.start()
            Self.engine = engine
            engineReady = true
        } catch {
            engine = nil
        }
    }

    static func play(_ effect: Effect) {
        if !engineReady { prepare() }
        guard let engine, engineReady else {
            fallback(effect)
            return
        }
        do {
            let pattern = try pattern(for: effect)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            fallback(effect)
        }
    }

    // MARK: Patterns

    private static func pattern(for effect: Effect) throws -> CHHapticPattern {
        switch effect {
        case .tick:
            return try CHHapticPattern(events: [
                transient(time: 0, intensity: 0.45, sharpness: 0.7)
            ], parameters: [])
        case .punch:
            return try CHHapticPattern(events: [
                transient(time: 0, intensity: 1.0, sharpness: 0.62),
                transient(time: 0.075, intensity: 0.55, sharpness: 0.28),
            ], parameters: [])
        case .stamp:
            return try CHHapticPattern(events: [
                transient(time: 0, intensity: 0.9, sharpness: 0.35),
                continuous(time: 0.01, duration: 0.12, intensity: 0.5, sharpness: 0.2),
            ], parameters: [])
        case .success:
            return try CHHapticPattern(events: [
                transient(time: 0, intensity: 0.5, sharpness: 0.4),
                transient(time: 0.11, intensity: 0.75, sharpness: 0.55),
            ], parameters: [])
        case .page:
            return try CHHapticPattern(events: [
                transient(time: 0, intensity: 0.3, sharpness: 0.55)
            ], parameters: [])
        }
    }

    private static func transient(time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }

    private static func continuous(time: TimeInterval, duration: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time,
            duration: duration
        )
    }

    private static func fallback(_ effect: Effect) {
        switch effect {
        case .tick, .page:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .punch, .stamp:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
