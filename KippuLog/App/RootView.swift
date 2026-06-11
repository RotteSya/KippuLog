import SwiftUI

struct RootView: View {
    @Environment(TicketStore.self) private var store

    var body: some View {
        switch DevRoute.current {
        case .gallery:
            ArtGalleryView()
        case .gallery2:
            ArtGalleryView(page: 1)
        case .hero:
            ArtHeroView()
        case nil:
            placeholder
        }
    }

    private var placeholder: some View {
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
