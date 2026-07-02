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
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

#Preview {
    StudioBackdrop()
}
