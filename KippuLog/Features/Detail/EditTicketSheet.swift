import SwiftUI

/// Quiet editing room for an existing ticket.
struct EditTicketSheet: View {
    @Environment(TicketStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Ticket

    init(ticket: Ticket) {
        _draft = State(initialValue: ticket)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    TicketCard(ticket: draft, lying: false)
                        .frame(maxWidth: draft.kind.isEdmondson ? 230 : 280)
                        .padding(.top, 24)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: draft)

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
    }
}
