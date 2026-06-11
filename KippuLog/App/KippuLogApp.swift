import SwiftUI

@main
struct KippuLogApp: App {
    @State private var store = TicketStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
