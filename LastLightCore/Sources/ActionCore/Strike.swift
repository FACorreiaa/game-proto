/// A column of light called down by a boss. It warns, then burns for a few frames, then is gone.
/// Strikes hurt heroes only, and each hero at most once.
public struct Strike: Sendable, Equatable {
    public var box: Box
    /// Frames of warning before it burns.
    public var warning: Int
    public var active: Int
    public var damage: Double
    public internal(set) var age = 0
    var hit: Set<Int> = []

    public init(box: Box, warning: Int, active: Int, damage: Double) {
        self.box = box
        self.warning = warning
        self.active = active
        self.damage = damage
    }

    public var isWarning: Bool { age < warning }
    public var isActive: Bool { age >= warning && age < warning + active }
    public var isDone: Bool { age >= warning + active }
}
