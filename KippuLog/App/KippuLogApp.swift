import SwiftUI

@main
struct KippuLogApp: App {
    @State private var store = TicketStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                // Deterministic appearance for screenshot sweeps on cloned
                // simulators (which don't inherit `simctl ui appearance`).
                .preferredColorScheme(
                    ProcessInfo.processInfo.arguments.contains("-uiDark") ? .dark : nil
                )
        }
    }
}
