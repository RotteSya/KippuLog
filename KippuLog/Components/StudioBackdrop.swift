import SwiftUI

/// The dark room — a dithered warm pool of light around the exhibit.
/// No flat black, no banding; the room has air.
///
/// Animatable: the lamp swings and warms *continuously* between scenes —
/// one room whose light moves, never two rooms crossfading.
struct StudioBackdrop: View, Animatable {
    /// Where the lamp points, in unit coordinates.
    var center = UnitPoint(x: 0.5, y: 0.30)
    var radius: CGFloat = 0.78
    var warmth: CGFloat = 0.5
    /// The lamp's cone gets air — dust motes drifting up through the
    /// light. Stage rooms only (it re-renders at 30fps, and rooms that
    /// host their own motion don't need it).
    var air = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(AnimatablePair(center.x, center.y), AnimatablePair(radius, warmth))
        }
        set {
            center = UnitPoint(x: newValue.first.first, y: newValue.first.second)
            radius = newValue.second.first
            warmth = newValue.second.second
        }
    }

    var body: some View {
        if air, !reduceMotion {
            SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 1200)
                room
                    .visualEffect { [center, radius] content, proxy in
                        content.colorEffect(
                            ShaderLibrary.studioAir(
                                .float2(proxy.size),
                                .float2(Float(center.x), Float(center.y)),
                                .float(Float(radius)),
                                .float(Float(time))
                            )
                        )
                    }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        } else {
            room
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var room: some View {
        Rectangle()
            .fill(Color(hex: 0x14110E))
            .visualEffect { [center, radius, warmth] content, proxy in
                content.colorEffect(
                    ShaderLibrary.studioLight(
                        .float2(proxy.size),
                        .float2(Float(center.x), Float(center.y)),
                        .float(Float(radius)),
                        .float(Float(warmth))
                    )
                )
            }
    }
}

#Preview {
    StudioBackdrop()
}
