import Foundation

/// Development/screenshot routing via launch arguments:
/// `-uiScreen gallery` jumps straight to a screen with sample data.
enum DevRoute: String {
    case gallery
    case gallery2
    case hero
    case viewfinder

    static let current: DevRoute? = {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-uiScreen"),
              index + 1 < args.count else { return nil }
        return DevRoute(rawValue: args[index + 1])
    }()
}
