import SwiftUI

struct RootView: View {
    @Environment(TicketStore.self) private var store
    @AppStorage("appearanceOverride") private var appearanceOverride = AppearanceOverride.system.rawValue

    var body: some View {
        content
            .preferredColorScheme(AppearanceOverride(rawValue: appearanceOverride)?.colorScheme)
    }

    @ViewBuilder
    private var content: some View {
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
