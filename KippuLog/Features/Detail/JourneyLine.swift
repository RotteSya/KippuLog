import SwiftUI

/// The placard's route diagram — the journey drawn as a line, the way a
/// station wall map would print it: departure ring, one hairline of
/// track, and an arrival dot in 朱. The line draws itself as the exhibit
/// settles; an entrance ticket (single station) gets a lone platform
/// marker instead of a track.
struct JourneyLine: View, Animatable {
    let ticket: Ticket
    /// 0 → nothing, 1 → the whole journey laid out. Drives the draw.
    /// Animatable — the body re-evaluates every frame of the cascade, so
    /// each element reads its own window off one clock.
    var progress: CGFloat = 1

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private var hasArrival: Bool { !ticket.toStation.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            if hasArrival {
                stations
                    .padding(.bottom, 13)
                track
            } else {
                Text(ticket.fromStation)
                    .font(Typo.mincho(27))
                    .tracking(3)
                    .foregroundStyle(Stage.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .opacity(fade(0.0, 0.5))
                    .padding(.bottom, 13)
                platformMark
            }

            if let meta = metaLine {
                Text(meta)
                    .font(Typo.gothic(10.5))
                    .tracking(1.8)
                    .foregroundStyle(Stage.softText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .opacity(fade(0.72, 1.0))
                    .padding(.top, 14)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: Two stations, one line

    private var stations: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(ticket.fromStation)
                .opacity(fade(0.0, 0.30))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(ticket.toStation)
                .opacity(fade(0.62, 0.95))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(Typo.mincho(24))
        .tracking(2)
        .foregroundStyle(Stage.text)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    /// The track: an open departure ring, the drawn hairline, and the
    /// arrival dot pressed in 朱 as the line reaches the platform.
    private var track: some View {
        HStack(spacing: 0) {
            Circle()
                .strokeBorder(Stage.softText, lineWidth: 1.3)
                .frame(width: 7, height: 7)
                .opacity(fade(0.0, 0.18))

            TrackStroke(progress: trackT)
                .stroke(
                    Stage.faintText.opacity(0.85),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round)
                )
                .frame(height: 7)
                .padding(.horizontal, 5)

            Circle()
                .fill(Ink.shu)
                .frame(width: 7, height: 7)
                .scaleEffect(arrivalScale)
                .opacity(fade(0.80, 0.92))
        }
    }

    /// The line itself rides the middle of the cascade.
    private var trackT: CGFloat {
        ramp(progress, from: 0.18, to: 0.82)
    }

    /// The arrival dot presses in with a touch of overshoot — a stamp,
    /// not a fade.
    private var arrivalScale: CGFloat {
        let t = ramp(progress, from: 0.80, to: 0.98)
        guard t > 0 else { return 0.01 }
        return 0.6 + 0.55 * t - 0.15 * t * t
    }

    // MARK: Single station (入場券)

    private var platformMark: some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(Stage.faintText.opacity(0.85))
                .frame(width: 22 * ramp(progress, from: 0.2, to: 0.7), height: 1)
            Circle()
                .fill(Ink.shu)
                .frame(width: 6, height: 6)
                .scaleEffect(arrivalScale)
            Rectangle()
                .fill(Stage.faintText.opacity(0.85))
                .frame(width: 22 * ramp(progress, from: 0.2, to: 0.7), height: 1)
        }
        .frame(height: 7)
    }

    // MARK: Small print

    /// One quiet metadata line under the track: operator, train, seat.
    private var metaLine: String? {
        var parts: [String] = [ticket.brand.displayName]
        if let train = ticket.trainName { parts.append(train) }
        if let seat = ticket.seat { parts.append(seat) }
        return parts.isEmpty ? nil : parts.joined(separator: " ・ ")
    }

    private var accessibilitySummary: String {
        var summary = hasArrival
            ? "\(ticket.fromStation)から\(ticket.toStation)まで"
            : ticket.fromStation
        if let meta = metaLine { summary += "、" + meta }
        return summary
    }

    // MARK: Cascade helpers

    /// Local ramp: this element's share of the one placard clock.
    private func ramp(_ t: CGFloat, from: CGFloat, to: CGFloat) -> CGFloat {
        guard to > from else { return 1 }
        return min(max((t - from) / (to - from), 0), 1)
    }

    private func fade(_ from: CGFloat, _ to: CGFloat) -> Double {
        Double(ramp(progress, from: from, to: to))
    }
}

/// The line of the journey — drawn left to right by `progress`.
nonisolated private struct TrackStroke: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = rect.midY
        path.move(to: CGPoint(x: rect.minX, y: y))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * max(progress, 0.0001), y: y))
        return path
    }
}

#Preview {
    ZStack {
        StudioBackdrop()
        VStack(spacing: 60) {
            JourneyLine(ticket: Ticket.samples[1])
                .frame(width: 318)
            JourneyLine(ticket: Ticket.samples[0])
                .frame(width: 318)
        }
    }
    .environment(TicketStore())
}
