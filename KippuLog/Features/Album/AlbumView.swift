import SwiftUI

/// 収蔵帳 — the whole collection at a glance, year by year, mounted on
/// kraft spreads with photo corners like a vintage collector's album.
/// Pinch the timeline closed to get here; pinch open (or tap a month
/// stamp) to dive back in.
struct AlbumView: View {
    @Environment(TicketStore.self) private var store
    let zoomNamespace: Namespace.ID
    /// The ticket on stage, if any — the spread scrolls so its mount is
    /// on the page when the return flight lands.
    var selection: Ticket?
    var onOpen: (Ticket) -> Void
    var onJumpMonth: (DateComponents) -> Void
    /// The album's two quiet doors: back to the 誌面, and the 奥付.
    var onCloseAlbum: () -> Void = {}
    var onOkuzuke: () -> Void = {}

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 34) {
                    header
                        .padding(.top, 20)

                    ForEach(store.yearGroups, id: \.year) { group in
                        YearSpread(
                            year: group.year,
                            months: group.months,
                            zoomNamespace: zoomNamespace,
                            onOpen: onOpen,
                            onJumpMonth: onJumpMonth
                        )
                        .padding(.horizontal, 20)
                    }

                    Text("つまんで ひらく")
                        .font(Typo.gothic(10))
                        .tracking(3)
                        .foregroundStyle(Ink.textFaint)
                        .padding(.bottom, 110)
                }
            }
            .scrollIndicators(.hidden)
            .onChange(of: selection) { old, new in
                // Paging on the stage: keep the return slot on the page.
                guard old != nil, let new else { return }
                proxy.scrollTo("a-cell-\(new.id)", anchor: .center)
            }
        }
        .background(Ink.background)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("収蔵帳")
                .font(Typo.mincho(20))
                .tracking(9)
                .foregroundStyle(Ink.text)
                .padding(.leading, 9) // optical centre against tracking tail
            HStack(spacing: 8) {
                Rectangle().fill(Ink.rule).frame(width: 30, height: 0.7)
                Text("THE COLLECTION")
                    .font(Typo.caption(8.5))
                    .tracking(3)
                    .foregroundStyle(Ink.textFaint)
                Rectangle().fill(Ink.rule).frame(width: 30, height: 0.7)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("収蔵帳")
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topLeading) {
            albumDoor("誌面", identifier: "album-magazine", action: onCloseAlbum)
                .padding(.leading, 24)
        }
        .overlay(alignment: .topTrailing) {
            albumDoor("奥付", identifier: "album-okuzuke", action: onOkuzuke)
                .padding(.trailing, 24)
        }
    }

    /// Corner door, same small print as the magazine cover's.
    private func albumDoor(_ label: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.play(.tick)
            action()
        } label: {
            Text(label)
                .font(Typo.gothic(10, bold: true))
                .tracking(1.5)
                .foregroundStyle(Ink.textSoft)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .overlay {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Ink.rule, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

/// One year of journeys on a kraft page.
private struct YearSpread: View {
    @Environment(TicketStore.self) private var store
    let year: Int
    let months: [(month: DateComponents, tickets: [Ticket])]
    let zoomNamespace: Namespace.ID
    var onOpen: (Ticket) -> Void
    var onJumpMonth: (DateComponents) -> Void

    @State private var appeared = false

    private static let kraft = Color.dynamic(light: 0xDDD3BD, dark: 0x453E30)
    private static let kraftEdge = Color.dynamic(light: 0xC9BC9F, dark: 0x575040)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(year))
                    .font(Typo.serifFigure(34, weight: .medium))
                    .foregroundStyle(Ink.text)
                HankoSeal(character: "旅", size: 15)
                    .offset(y: -4)
                Spacer()
                Text(yearStats)
                    .font(Typo.serifFigure(11.5, weight: .regular))
                    .foregroundStyle(Ink.textSoft)
            }
            .padding(.horizontal, 4)

            // The kraft page — one dense run of mounted prints; the month
            // slip rides the first print of each month.
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14), GridItem(.flexible())],
                spacing: 20
            ) {
                ForEach(Array(flattened.enumerated()), id: \.element.ticket.id) { i, item in
                    AlbumMini(
                        ticket: item.ticket,
                        monthSlip: item.monthStart,
                        zoomNamespace: zoomNamespace,
                        onOpen: onOpen,
                        onJumpMonth: onJumpMonth
                    )
                    .id("a-cell-\(item.ticket.id)")
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.86)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.78)
                            .delay(Double(min(i, 14)) * 0.025),
                        value: appeared
                    )
                }
            }
            .padding(18)
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Self.kraft)
                    .visualEffect { content, geo in
                        content.colorEffect(
                            ShaderLibrary.ticketPaper(
                                .float2(geo.size),
                                .color(Color.clear),
                                .float(Float(year % 977)),
                                .float(0)
                            )
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Self.kraftEdge.opacity(0.6), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.10), radius: 14, y: 8)
            }
        }
        .onAppear {
            guard !appeared else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    /// The year's tickets in one run; the first of each month carries the
    /// month components for its pasted slip.
    private var flattened: [(ticket: Ticket, monthStart: DateComponents?)] {
        var result: [(Ticket, DateComponents?)] = []
        for group in months {
            for (i, ticket) in group.tickets.enumerated() {
                result.append((ticket, i == 0 ? group.month : nil))
            }
        }
        return result
    }

    private var yearStats: String {
        let all = months.flatMap(\.tickets)
        let spent = all.compactMap(\.price).reduce(0, +)
        return "\(all.count)枚 ・ \(Editorial.yen(spent))"
    }
}

/// One mounted ticket: thumbnail (or live plate) under four photo corners,
/// with a pasted month slip when it opens a new month.
private struct AlbumMini: View {
    @Environment(TicketStore.self) private var store
    let ticket: Ticket
    var monthSlip: DateComponents?
    let zoomNamespace: Namespace.ID
    var onOpen: (Ticket) -> Void
    var onJumpMonth: (DateComponents) -> Void

    private static let mount = Color.dynamic(light: 0xC5B89B, dark: 0x5C5443)

    var body: some View {
        Group {
            if let thumb = store.thumbnail(for: ticket) {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 2.5))
            } else {
                TicketArtView(ticket: ticket)
            }
        }
        .shadow(color: .black.opacity(0.14), radius: 3, y: 2)
        .overlay { PhotoCorners(color: Self.mount) }
        .overlay(alignment: .topLeading) {
            if let monthSlip {
                Button {
                    Haptic.play(.tick)
                    onJumpMonth(monthSlip)
                } label: {
                    Text(Editorial.kanjiMonth(monthSlip.month ?? 1))
                        .font(Typo.gothic(9, bold: true))
                        .tracking(1.5)
                        .foregroundStyle(Ink.ticketInk)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color(hex: 0xF2EDE1))
                                .shadow(color: .black.opacity(0.22), radius: 1.5, y: 1)
                        }
                        .rotationEffect(.degrees(-3))
                }
                .buttonStyle(.plain)
                .offset(x: -7, y: -9)
                .accessibilityLabel("\(Editorial.kanjiMonth(monthSlip.month ?? 1))へ移動")
            }
        }
        .rotationEffect(.degrees(restingAngle))
        .contentShape(Rectangle())
        .matchedTransitionSource(id: "a-\(ticket.id)", in: zoomNamespace)
        .onTapGesture {
            Haptic.play(.tick)
            onOpen(ticket)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("切符 \(ticket.routeText)")
        .accessibilityIdentifier("album-mini-\(ticket.routeText)")
    }

    private var restingAngle: Double {
        var rng = SeededRandom(ticket.styleSeed ^ 0xA1B)
        return rng.double(in: -2.4...2.4)
    }
}

/// The four kraft mounts holding a print to the page.
private struct PhotoCorners: View {
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let s: CGFloat = max(11, proxy.size.width * 0.13)
            ZStack {
                corner(size: s).position(x: s * 0.28, y: s * 0.28)
                corner(size: s).rotationEffect(.degrees(90))
                    .position(x: proxy.size.width - s * 0.28, y: s * 0.28)
                corner(size: s).rotationEffect(.degrees(270))
                    .position(x: s * 0.28, y: proxy.size.height - s * 0.28)
                corner(size: s).rotationEffect(.degrees(180))
                    .position(x: proxy.size.width - s * 0.28, y: proxy.size.height - s * 0.28)
            }
        }
        .allowsHitTesting(false)
    }

    private func corner(size: CGFloat) -> some View {
        MountTriangle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.18), radius: 1, y: 0.8)
    }
}

private nonisolated struct MountTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
