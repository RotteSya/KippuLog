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
            TimelineView()
        }
    }
}

#Preview {
    RootView()
        .environment(TicketStore())
}
