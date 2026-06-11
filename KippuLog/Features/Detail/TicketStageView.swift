import SwiftUI

/// The studio — one ticket on a dark stage. (First cut: hero + facts;
/// tilt, flip, paging and editing arrive with the full detail pass.)
struct TicketStageView: View {
    @Environment(\.dismiss) private var dismiss
    let ticket: Ticket

    var body: some View {
        ZStack {
            Ink.studio.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    TicketPlate(ticket: ticket, lying: false)
                        .frame(maxWidth: ticket.kind.isEdmondson ? 300 : 360)
                        .padding(.top, 84)
                        .padding(.bottom, 48)

                    Text(ticket.routeText)
                        .font(Typo.mincho(26))
                        .tracking(3)
                        .foregroundStyle(Color(hex: 0xEDE6DA))
                        .padding(.bottom, 6)

                    if let date = ticket.travelDate {
                        Text(Editorial.shortDate(date))
                            .font(Typo.caption(11))
                            .tracking(2)
                            .foregroundStyle(Color(hex: 0x9C938A))
                    }

                    factsGrid
                        .padding(.horizontal, 32)
                        .padding(.top, 40)

                    if !ticket.memo.isEmpty {
                        Text(ticket.memo)
                            .font(Typo.gothic(13))
                            .lineSpacing(7)
                            .foregroundStyle(Color(hex: 0xBCB3A8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 32)
                            .padding(.top, 36)
                    }

                    Spacer(minLength: 100)
                }
            }
            .scrollIndicators(.hidden)
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: 0xBCB3A8))
                    .frame(width: 40, height: 40)
            }
            .glassEffect(.regular, in: .circle)
            .padding(.leading, 20)
            .padding(.top, 8)
        }
    }

    private var factsGrid: some View {
        VStack(spacing: 0) {
            factRow("種別", ticket.kind.label)
            factRow("会社", ticket.brand.displayName)
            if let train = ticket.trainName { factRow("列車", train) }
            if let seat = ticket.seat { factRow("座席", seat) }
            if let price = ticket.price { factRow("運賃", Editorial.yen(price)) }
        }
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(Typo.gothic(11))
                    .tracking(2)
                    .foregroundStyle(Color(hex: 0x847B70))
                Spacer()
                Text(value)
                    .font(Typo.gothic(13))
                    .foregroundStyle(Color(hex: 0xD8CFC2))
            }
            .padding(.vertical, 13)
            Rectangle()
                .fill(Color(hex: 0x2B261F))
                .frame(height: 1)
        }
    }
}

#Preview {
    TicketStageView(ticket: Ticket.samples[1])
}
