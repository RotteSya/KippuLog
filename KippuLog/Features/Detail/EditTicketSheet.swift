import SwiftUI
import Combine

/// Quiet editing room for an existing ticket. The preview steps aside
/// while the keyboard is up — the form always has the whole desk.
struct EditTicketSheet: View {
    @Environment(TicketStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Ticket
    @State private var keyboardUp = false

    init(ticket: Ticket) {
        _draft = State(initialValue: ticket)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if !keyboardUp {
                        TicketCard(ticket: draft, lying: false)
                            .frame(maxWidth: draft.kind.isEdmondson ? 230 : 280)
                            .padding(.top, 24)
                            // Keystrokes update the preview instantly; only a
                            // kind change (new stock) animates.
                            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: draft.kind)
                            .transition(
                                .scale(scale: 0.85, anchor: .top)
                                    .combined(with: .opacity)
                            )
                    }

                    TicketFormFields(ticket: $draft)
                        .padding(.horizontal, 26)
                }
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Ink.background)
            .navigationTitle("切符を直す")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("やめる") { dismiss() }
                        .font(Typo.gothic(13))
                        .tint(Ink.textSoft)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Haptic.play(.stamp)
                        store.update(draft)
                        dismiss()
                    }
                    .font(Typo.gothic(13, bold: true))
                    .tint(Ink.shu)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .appearanceOverridden()
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                keyboardUp = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                keyboardUp = false
            }
        }
    }
}
