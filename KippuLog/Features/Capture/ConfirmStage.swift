import SwiftUI

/// One geometry for the gate→confirm handoff.
///
/// The gate's final glide parks the scan on exactly the frame the confirm
/// reveal will occupy — both sides read *this* and nothing else, so the
/// phase switch is a held object, not a cut. If the reveal layout changes,
/// change it here.
enum ConfirmStage {
    /// Air above the stage slot (below the safe-area top).
    static let topPadding: CGFloat = 38
    /// The slot's bounds — the scan fits inside, true aspect.
    static let maxWidth: CGFloat = 300
    static let maxHeight: CGFloat = 230

    /// A scan's display size inside the slot for a given container width.
    static func fitted(aspect: CGFloat, in container: CGSize) -> CGSize {
        let boundW = min(maxWidth, container.width - 60)
        let width = min(boundW, maxHeight * aspect)
        return CGSize(width: width, height: width / aspect)
    }

    /// The slot's center, measured down from the safe-area top.
    static func centerY(aspect: CGFloat, in container: CGSize) -> CGFloat {
        topPadding + fitted(aspect: aspect, in: container).height / 2
    }
}
