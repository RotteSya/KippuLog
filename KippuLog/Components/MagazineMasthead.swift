import SwiftUI

/// The magazine's nameplate — character-spaced wordmark, the editor's
/// seal, and the classic thick-thin editorial rule. One masthead for the
/// filled magazine and its empty first issue alike.
struct MagazineMasthead: View {
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
    }
}

#Preview {
    MagazineMasthead()
        .padding(.vertical, 40)
        .background(Ink.background)
}
