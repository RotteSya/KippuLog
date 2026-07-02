import SwiftUI

/// The magazine's nameplate — character-spaced wordmark, the editor's
/// seal, and the classic thick-thin editorial rule. One masthead for the
/// filled magazine and its empty first issue alike.
///
/// The seal *stamps* in once per launch — the editor signing the issue —
/// then stays pressed for the session.
struct MagazineMasthead: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stamped = SealSession.done
    @State private var bloom = false

    var body: some View {
        VStack(spacing: 0) {
            // Character-spaced wordmark — truly centered, no tracking tail.
            HStack(spacing: 9) {
                ForEach(Array("きっぷログ".enumerated()), id: \.offset) { _, char in
                    Text(String(char))
                        .font(Typo.mincho(22))
                }
            }
            .foregroundStyle(Ink.text)
            .accessibilityRepresentation { Text("きっぷログ") }
            .overlay(alignment: .trailing) {
                HankoSeal(size: 16)
                    .scaleEffect(stamped ? 1 : 1.9)
                    .opacity(stamped ? 1 : 0)
                    .background {
                        Circle()
                            .stroke(Ink.shu.opacity(bloom ? 0 : 0.5), lineWidth: 1.2)
                            .scaleEffect(bloom ? 2.3 : 0.6)
                            .accessibilityHidden(true)
                    }
                    .offset(x: 34, y: -2)
            }
            .padding(.bottom, 16)

            // Classic thick-thin editorial rule.
            VStack(spacing: 3) {
                Rectangle().fill(Ink.text.opacity(0.85)).frame(height: 1.4)
                Rectangle().fill(Ink.rule).frame(height: 0.6)
            }
            .padding(.bottom, 12)

            Text("COLLECTED JOURNEYS")
                .font(Typo.caption(9.5))
                .tracking(3.6)
                .foregroundStyle(Ink.textFaint)
        }
        .padding(.horizontal, 30)
        .onAppear {
            guard !stamped else { return }
            SealSession.done = true
            guard !reduceMotion else {
                stamped = true
                return
            }
            Task {
                try? await Task.sleep(for: .milliseconds(620))
                Haptic.play(.stamp)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.58)) {
                    stamped = true
                }
                withAnimation(.easeOut(duration: 0.55).delay(0.05)) {
                    bloom = true
                }
            }
        }
    }
}

/// The seal signs once per session, however many mastheads appear.
@MainActor
private enum SealSession {
    static var done = false
}

#Preview {
    MagazineMasthead()
        .padding(.vertical, 40)
        .background(Ink.background)
}
