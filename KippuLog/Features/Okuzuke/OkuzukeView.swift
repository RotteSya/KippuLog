import SwiftUI

/// 奥付 — the magazine's colophon page, which is where a magazine keeps
/// its publication facts and where きっぷログ keeps its few settings.
/// Quiet rows on paper: appearance, the sample journeys, the opening
/// ceremony, the collection's figures, and the imprint itself.
struct OkuzukeView: View {
    @Environment(TicketStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearanceOverride") private var appearanceOverride = AppearanceOverride.system.rawValue

    /// Fired after the sheet closes when the user asks to see 開幕 again.
    var onReplayWelcome: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.top, 30)
                    .padding(.bottom, 34)

                section("あしらい") {
                    appearanceStamps
                }

                section("見本の旅") {
                    sampleRow
                }

                section("開幕") {
                    quietRow(
                        label: "開幕をもう一度みる",
                        detail: "はじめの一枚が、もう一度印刷されます"
                    ) {
                        Haptic.play(.punch)
                        dismiss()
                        onReplayWelcome()
                    }
                    .accessibilityIdentifier("okuzuke-replay")
                }

                section("しるべ") {
                    linkRow("使いかたとサポート", destination: "https://rottesya.github.io/KippuLog/")
                    linkRow("プライバシー", destination: "https://rottesya.github.io/KippuLog/privacy.html")
                    linkRow("編集部へたより", destination: "mailto:raysyadesu@gmail.com")
                }

                imprint
                    .padding(.top, 44)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 30)
        }
        .scrollIndicators(.hidden)
        .background(Ink.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .appearanceOverridden()
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 10) {
            Text("奥　付")
                .font(Typo.mincho(20))
                .foregroundStyle(Ink.text)
            HStack(spacing: 8) {
                Rectangle().fill(Ink.rule).frame(width: 30, height: 0.7)
                Text("COLOPHON")
                    .font(Typo.caption(8.5))
                    .tracking(3)
                    .foregroundStyle(Ink.textFaint)
                Rectangle().fill(Ink.rule).frame(width: 30, height: 0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Sections

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Ink.shu)
                    .frame(width: 8, height: 8)
                    .rotationEffect(.degrees(-3))
                Text(title)
                    .font(Typo.gothic(10, bold: true))
                    .tracking(3)
                    .foregroundStyle(Ink.textSoft)
            }

            content()

            DottedRule()
                .padding(.top, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 22)
    }

    // MARK: Appearance

    /// Three stamps, like the kind chips: the room follows the system,
    /// stays paper, or stays night.
    private var appearanceStamps: some View {
        HStack(spacing: 8) {
            ForEach(AppearanceOverride.allCases) { mode in
                let isOn = appearanceOverride == mode.rawValue
                Button {
                    Haptic.play(.stamp)
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) {
                        appearanceOverride = mode.rawValue
                    }
                } label: {
                    Text(mode.label)
                        .font(Typo.gothic(12, bold: true))
                        .tracking(0.6)
                        .lineLimit(1)
                        .foregroundStyle(isOn ? Color(hex: 0xF7F3EB) : Ink.textSoft)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isOn ? Ink.shu : .clear)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(isOn ? Ink.shu : Ink.rule, lineWidth: isOn ? 0 : 1)
                        }
                        .rotationEffect(.degrees(isOn ? [-1.2, 0.9, -0.8][AppearanceOverride.allCases.firstIndex(of: mode) ?? 0] : 0))
                        .scaleEffect(isOn ? 1.04 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("okuzuke-appearance-\(mode.rawValue)")
            }
        }
    }

    // MARK: Samples

    @ViewBuilder
    private var sampleRow: some View {
        if store.hasSamples {
            quietRow(
                label: "サンプルの旅を片付ける",
                detail: "見本の\(store.tickets.filter(\.isSample).count)枚が誌面から下がります"
            ) {
                Haptic.play(.stamp)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    store.removeSamples()
                }
            }
            .accessibilityIdentifier("okuzuke-tidy-samples")
        } else {
            quietRow(
                label: "サンプルの旅を並べる",
                detail: "見本の八枚で誌面の雰囲気を眺められます"
            ) {
                Haptic.play(.stamp)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    store.addSamples()
                }
            }
            .accessibilityIdentifier("okuzuke-add-samples")
        }
    }

    // MARK: Rows

    private func quietRow(label: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(label)
                        .font(Typo.gothic(14))
                        .foregroundStyle(Ink.text)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Ink.textFaint)
                }
                Text(detail)
                    .font(Typo.gothic(11))
                    .foregroundStyle(Ink.textFaint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func linkRow(_ label: String, destination: String) -> some View {
        Link(destination: URL(string: destination)!) {
            HStack {
                Text(label)
                    .font(Typo.gothic(14))
                    .foregroundStyle(Ink.text)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Ink.textFaint)
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Imprint

    private var imprint: some View {
        VStack(spacing: 11) {
            HankoSeal(size: 16)
            Text("きっぷログ")
                .font(Typo.mincho(13))
                .tracking(4)
                .foregroundStyle(Ink.text)
            Text("全 \(store.tickets.count) 枚 — \(Editorial.yen(store.totalSpent))")
                .font(Typo.serifFigure(12, weight: .regular))
                .foregroundStyle(Ink.textSoft)
            VStack(spacing: 4) {
                Text("第 \(Bundle.main.shortVersion) 版")
                    .font(Typo.gothic(10))
                    .tracking(1.5)
                    .foregroundStyle(Ink.textFaint)
                Text("© 2026 She Lingzhao")
                    .font(Typo.caption(9))
                    .tracking(1.5)
                    .foregroundStyle(Ink.textFaint)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The room follows the system, stays paper, or stays night.
enum AppearanceOverride: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "おまかせ"
        case .light: "紙"
        case .dark: "夜"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension Bundle {
    /// e.g. "1.0.1"
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}

extension View {
    /// Sheets are their own presentations — the root's colour-scheme
    /// preference doesn't reach them, so each paper sheet re-applies the
    /// reader's あしらい choice itself.
    func appearanceOverridden() -> some View {
        modifier(AppearanceOverrideModifier())
    }
}

private struct AppearanceOverrideModifier: ViewModifier {
    @AppStorage("appearanceOverride") private var appearanceOverride = AppearanceOverride.system.rawValue

    func body(content: Content) -> some View {
        content.preferredColorScheme(AppearanceOverride(rawValue: appearanceOverride)?.colorScheme)
    }
}

#Preview {
    OkuzukeView()
        .environment(TicketStore())
}
