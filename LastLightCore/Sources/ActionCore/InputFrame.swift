/// One frame of intent, from the touchscreen, a keyboard, a controller or an AI brain.
/// `moveX` and `jumpHeld` are held state; the other flags mean "pressed on this frame".
public struct InputFrame: Equatable, Sendable {
    public var moveX: Double = 0
    public var jump = false
    public var jumpHeld = false
    public var attack = false
    public var dodge = false
    public var special = false
    public var switchHero = false

    public init(
        moveX: Double = 0, jump: Bool = false, jumpHeld: Bool = false, attack: Bool = false,
        dodge: Bool = false, special: Bool = false, switchHero: Bool = false
    ) {
        self.moveX = moveX
        self.jump = jump
        self.jumpHeld = jumpHeld
        self.attack = attack
        self.dodge = dodge
        self.special = special
        self.switchHero = switchHero
    }

    public static let neutral = InputFrame()
}
