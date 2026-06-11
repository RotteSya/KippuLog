import SwiftUI

/// The dark room — a dithered warm pool of light around the exhibit.
/// No flat black, no banding; the room has air.
struct StudioBackdrop: View {
    /// Where the lamp points, in unit coordinates.
    var center = UnitPoint(x: 0.5, y: 0.30)
    var radius: CGFloat = 0.78
    var warmth: CGFloat = 0.5

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
