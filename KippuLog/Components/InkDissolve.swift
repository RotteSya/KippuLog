import SwiftUI

/// Animatable driver for the `inkDissolve` shader — `withAnimation`
/// interpolates `progress`, the modifier re-renders per frame, and the
/// ticket scatters into sumi dust.
struct InkDissolveModifier: ViewModifier, @preconcurrency Animatable {
    var progress: Double
    var seed: Float

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .visualEffect { [progress] view, proxy in
                view.colorEffect(
                    ShaderLibrary.inkDissolve(
                        .float2(proxy.size),
                        .float(Float(progress)),
                        .float(seed)
                    )
                )
            }
    }
}

extension View {
    func inkDissolve(progress: Double, seed: UInt64) -> some View {
        modifier(InkDissolveModifier(progress: progress, seed: Float(seed % 977)))
    }
}
