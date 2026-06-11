import SwiftUI

/// Shared field editor — used by the capture confirm sheet and the
/// detail edit sheet. Quiet rows on paper; no Form chrome.
struct TicketFormFields: View {
    @Binding var ticket: Ticket

    var body: some View {
        VStack(spacing: 0) {
            kindChips
                .padding(.bottom, 22)

            fieldRow("発駅") {
                stationField("駅名", text: $ticket.fromStation)
                    .accessibilityIdentifier("field-from")
            }
            if ticket.kind != .nyujoken {
                fieldRow("着駅") {
                    stationField("駅名", text: $ticket.toStation)
                        .accessibilityIdentifier("field-to")
                }
            }
            fieldRow("日付") {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { ticket.travelDate ?? .now },
                        set: { ticket.travelDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .tint(Ink.shu)
            }
            fieldRow("運賃") {
                TextField(
                    "0",
                    text: Binding(
                        get: { ticket.price.map(String.init) ?? "" },
                        set: { ticket.price = Int($0.filter(\.isNumber)) }
                    )
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(Typo.gothic(15))
                .frame(maxWidth: 140)
                .overlay(alignment: .trailingFirstTextBaseline) {
                    Text("円")
                        .font(Typo.gothic(12))
                        .foregroundStyle(Ink.textSoft)
                        .offset(x: 18)
                }
                .padding(.trailing, 18)
            }
            fieldRow("会社") {
                Menu {
                    ForEach(RailBrand.allCases) { brand in
                        Button(brand.displayName) { ticket.brand = brand }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(ticket.brand.displayName)
                            .font(Typo.gothic(14))
                            .foregroundStyle(Ink.text)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Ink.textFaint)
                    }
                }
            }
            fieldRow("列車") {
                optionalField("のぞみ２２５号", value: $ticket.trainName)
            }
            fieldRow("座席") {
                optionalField("７号車１２番Ａ席", value: $ticket.seat)
            }
        }
    }

    // MARK: Kind stamps

    /// Selection as 判子 imprints — the chosen kind is pressed in shu,
    /// each stamp a hair off true.
    private var kindChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(Array(TicketKind.allCases.enumerated()), id: \.element) { index, kind in
                    let isOn = ticket.kind == kind
                    Button {
                        Haptic.play(.stamp)
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) {
                            ticket.kind = kind
                        }
                    } label: {
                        Text(kind.label)
                            .font(Typo.gothic(12, bold: true))
                            .tracking(1)
                            .foregroundStyle(isOn ? Color(hex: 0xF7F3EB) : Ink.textSoft)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(isOn ? Ink.shu : .clear)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(
                                        isOn ? Ink.shu : Ink.rule,
                                        lineWidth: isOn ? 0 : 1
                                    )
                            }
                            .rotationEffect(.degrees(isOn ? stampTilt(index) : 0))
                            .scaleEffect(isOn ? 1.04 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 3)
        }
        .scrollIndicators(.hidden)
    }

    private func stampTilt(_ index: Int) -> Double {
        [-1.6, 1.2, -0.9, 1.8, -1.3, 0.8][index % 6]
    }

    // MARK: Rows

    private func fieldRow(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(Typo.gothic(11))
                    .tracking(2)
                    .foregroundStyle(Ink.textSoft)
                    .frame(width: 52, alignment: .leading)
                Spacer()
                content()
            }
            .padding(.vertical, 12)
            DottedRule()
        }
    }

    private func stationField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(Typo.gothic(15, bold: true))
            .multilineTextAlignment(.trailing)
            .autocorrectionDisabled()
    }

    private func optionalField(_ placeholder: String, value: Binding<String?>) -> some View {
        TextField(
            placeholder,
            text: Binding(
                get: { value.wrappedValue ?? "" },
                set: { value.wrappedValue = $0.isEmpty ? nil : $0 }
            )
        )
        .font(Typo.gothic(14))
        .multilineTextAlignment(.trailing)
        .autocorrectionDisabled()
    }
}

/// Printed-form separator: a fine dotted rule.
struct DottedRule: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            context.stroke(
                path,
                with: .color(Ink.rule.opacity(0.9)),
                style: StrokeStyle(lineWidth: 1, dash: [1.5, 3.5])
            )
        }
        .frame(height: 1)
        .accessibilityHidden(true)
    }
}
