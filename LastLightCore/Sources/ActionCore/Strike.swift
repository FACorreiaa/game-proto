/// What a strike looks like and what it is.
public enum StrikeKind: String, Sendable, Equatable {
    /// A column of light called down by The Protocol.
    case light
    /// A thrown lantern burning on the ground.
    case fire
    /// A Night Weaver's snare: it catches and slows.
    case snare
    /// The Last Oracle's dark: it bursts up from the floor.
    case dark
}

/// Something that warns, then is live for a few frames, then is gone: a column of light, a burning patch, a snare.
/// Strikes hurt heroes only, and each hero at most once.
public struct Strike: Sendable, Equatable {
    public var kind: StrikeKind = .light
    public var box: Box
    /// Frames a hero it catches moves at reduced speed.
    public var slowFrames = 0
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
