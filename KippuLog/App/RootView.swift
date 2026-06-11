import SwiftUI

struct RootView: View {
    @Environment(TicketStore.self) private var store

    var body: some View {
        ZStack {
            Ink.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("きっぷログ")
                    .font(Typo.mincho(34))
                    .tracking(6)
                    .foregroundStyle(Ink.text)
                Text("旅の切符を、一冊に。")
                    .font(Typo.gothic(13))
                    .tracking(2)
                    .foregroundStyle(Ink.textSoft)
            }
        }
    }
}

#Preview {
    RootView()
        .environment(TicketStore())
}
