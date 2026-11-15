import SpriteKit

/// Screen edges to keep clear, the same shape on every platform.
struct Insets {
    var top: CGFloat = 0
    var left: CGFloat = 0
    var bottom: CGFloat = 0
    var right: CGFloat = 0

    static let zero = Insets()
}

#if os(iOS)
import UIKit

/// Taps in the hand. Does nothing on a Mac.
final class Haptics {
    private let lightTap = UIImpactFeedbackGenerator(style: .light)
    private let heavyTap = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidTap = UIImpactFeedbackGenerator(style: .rigid)

    func light(_ intensity: CGFloat = 1) { lightTap.impactOccurred(intensity: intensity) }
    func heavy() { heavyTap.impactOccurred() }
    func rigid(_ intensity: CGFloat = 1) { rigidTap.impactOccurred(intensity: intensity) }
}

extension SKView {
    var insets: Insets {
        Insets(top: safeAreaInsets.top, left: safeAreaInsets.left, bottom: safeAreaInsets.bottom, right: safeAreaInsets.right)
    }
}
#else
final class Haptics {
    func light(_ intensity: CGFloat = 1) {}
    func heavy() {}
    func rigid(_ intensity: CGFloat = 1) {}
}

extension SKView {
    var insets: Insets { .zero }
}
#endif
