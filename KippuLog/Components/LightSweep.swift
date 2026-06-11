import SwiftUI

/// One-shot warm light pass (the scanSweep shader driven by an
/// animatable progress) — used when a fresh ticket lands on the shelf.
struct LightSweepModifier: ViewModifier, @preconcurrency Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .visualEffect { [progress] view, proxy in
                view.colorEffect(
                    ShaderLibrary.scanSweep(
                        .float2(proxy.size),
                        .float(Float(progress))
                    )
                )
            }
    }
}

extension View {
    func lightSweep(progress: Double) -> some View {
        modifier(LightSweepModifier(progress: progress))
    }
}
