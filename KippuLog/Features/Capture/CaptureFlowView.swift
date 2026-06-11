import SwiftUI

/// The gate — capture flow shell. Camera, gate animation, OCR and the
/// confirm sheet land in the capture pass; this stub keeps the punch
/// button honest meanwhile.
struct CaptureFlowView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Ink.studio.ignoresSafeArea()
            VStack(spacing: 14) {
                Text("改札口")
                    .font(Typo.mincho(22))
                    .tracking(6)
                    .foregroundStyle(Color(hex: 0xEDE6DA))
                Text("まもなく開きます")
                    .font(Typo.gothic(12))
                    .foregroundStyle(Color(hex: 0x9C938A))
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: 0xBCB3A8))
                    .frame(width: 40, height: 40)
            }
            .glassEffect(.regular, in: .circle)
            .padding(.trailing, 20)
            .padding(.top, 8)
        }
    }
}
