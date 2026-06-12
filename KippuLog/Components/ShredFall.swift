import SwiftUI

/// Animatable driver for the `shredFall` shader — `withAnimation`
/// interpolates `progress`, the modifier re-renders per frame, and the
/// ticket tears into strips that fall away. The gate takes it back.
struct ShredFallModifier: ViewModifier, @preconcurrency Animatable {
    var progress: Double
    var seed: Float

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .visualEffect { [progress] view, proxy in
                view.layerEffect(
                    ShaderLibrary.shredFall(
                        .float2(proxy.size),
                        .float(Float(progress)),
                        .float(seed)
                    ),
                    maxSampleOffset: CGSize(width: 60, height: proxy.size.height * 1.6)
                )
            }
    }
}

extension View {
    func shredFall(progress: Double, seed: UInt64) -> some View {
        modifier(ShredFallModifier(progress: progress, seed: Float(seed % 977)))
    }
}
