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
        case .viewfinder:
            ViewfinderRehearsalView()
        case nil:
            ZStack {
                TimelineView()
                if store.needsWelcome {
                    // 開幕 — plays once; its exit lifts the lights on the
                    // page already living underneath.
                    WelcomeCeremony()
                        .zIndex(1)
                        .transition(.opacity)
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environment(TicketStore())
}
