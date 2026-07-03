import SwiftUI

/// 旅の記 — the collector's note, written on the back of the torn 半券.
/// The slip carries the same stock and serial as the ticket above it;
/// the writing is pen ink, not print. The stub used to repeat the
/// ticket's own facts — now it holds the one thing the ticket can't:
/// what the journey felt like.
struct MemoSlip: View {
    @Environment(TicketStore.self) private var store
    let ticket: Ticket

    @State private var draft = ""
    @FocusState private var focused: Bool

    /// Pen ink — blue-black, the one hand-made mark in the studio.
    private static let penInk = Color(hex: 0x3A4459)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("旅　の　記")
                    .font(Typo.gothic(9.5, bold: true))
                    .tracking(2.5)
                Spacer()
                Text(TicketText.serial(seed: ticket.styleSeed))
                    .font(Typo.gothic(8.5))
            }
            .foregroundStyle(Ink.ticketInkSoft)

            TextField("ひとこと残す…", text: $draft, axis: .vertical)
                .font(.custom("HiraMaruProN-W4", size: 14))
                .lineSpacing(9)
                .foregroundStyle(Self.penInk)
                .tint(Ink.shu)
                .focused($focused)
                .lineLimit(2...8)
                .accessibilityIdentifier("memo-field")
                .accessibilityLabel("旅の記")
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { save() }
                }
                .submitLabel(.done)
        }
        .padding(.horizontal, 18)
        .padding(.top, 15)
        .padding(.bottom, 17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            StubShape(toothCount: 26, toothDepth: 4, corner: 5)
                .fill(Color(hex: 0xF2EDE1))
                .visualEffect { [seed = ticket.styleSeed] content, geo in
                    content.colorEffect(
                        ShaderLibrary.ticketPaper(
                            .float2(geo.size),
                            .color(Color.clear),
                            .float(Float((seed &+ 7) % 9973)),
                            .float(0),
                            .float(3),
                            .float(0)
                        )
                    )
                }
                .clipShape(StubShape(toothCount: 26, toothDepth: 4, corner: 5))
        }
        .overlay {
            StubShape(toothCount: 26, toothDepth: 4, corner: 5)
                .stroke(Color.black.opacity(0.10), lineWidth: 0.6)
        }
        .shadow(color: .black.opacity(0.30), radius: 10, y: 7)
        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        .onAppear { draft = ticket.memo }
        .toolbar {
            if focused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { focused = false }
                        .font(Typo.gothic(13, bold: true))
                        .tint(Ink.shu)
                }
            }
        }
    }

    private func save() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != ticket.memo else { return }
        var updated = ticket
        updated.memo = trimmed
        store.update(updated)
        Haptic.play(.tick)
    }
}

/// Stub outline: perforation teeth across the top edge, rounded feet.
nonisolated struct StubShape: Shape {
    var toothCount: Int
    var toothDepth: CGFloat
    var corner: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let toothWidth = rect.width / CGFloat(toothCount)
        let top = rect.minY + toothDepth

        path.move(to: CGPoint(x: rect.minX, y: top))
        // Teeth march across the torn edge.
        for i in 0..<toothCount {
            let x0 = rect.minX + CGFloat(i) * toothWidth
            path.addLine(to: CGPoint(x: x0 + toothWidth * 0.5, y: rect.minY))
            path.addLine(to: CGPoint(x: x0 + toothWidth, y: top))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        path.addArc(
            center: CGPoint(x: rect.maxX - corner, y: rect.maxY - corner),
            radius: corner, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + corner, y: rect.maxY - corner),
            radius: corner, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        StudioBackdrop()
        MemoSlip(ticket: Ticket.samples[1])
            .frame(width: 318)
    }
    .environment(TicketStore())
}
