public enum FighterState: Equatable, Sendable {
    case idle
    case run
    case air
    case attack(Int)
    case dodge
    case hitstun
    case staggered
    case fuse
    /// Orion's Adapt: braced for a hit.
    case guardStance
    /// A boss changing phase: it cannot be hurt until this ends.
    case phaseShift
    case dead
}

public enum AttackPhase: Equatable, Sendable {
    case windup
    case active
    case recovery
}

public struct Fighter: Sendable, Identifiable {
    public let id: Int
    public let kind: FighterKind
    public let team: Team
    public var spec: FighterSpec
    /// Centre of the feet.
    public var pos: Vec2
    public var vel = Vec2.zero
    /// +1 facing right, -1 facing left.
    public var facing: Double
    public var hp: Double
    public var state = FighterState.idle
    /// Frames spent in the current state.
    public var stateFrame = 0
    public var stateDuration = 0
    public var onGround = true
    public var dodgeCooldown = 0
    public var invulnerable = 0

    /// Scratch space for brains.
    public var aiCooldown = 0
    public var aiAux = 0
    /// Which attack starts on the next attack press. Brains of fighters with several separate attacks set it.
    public var nextAttack = 0
    /// Frames until the special can be used again.
    public internal(set) var specialCooldown = 0
    /// Frames left on Caelen's mark. While it lasts, hits on this fighter do more.
    public internal(set) var markedFrames = 0
    /// Frames left of moving slowly, after a Sentry Core's beam.
    public internal(set) var slowFrames = 0
    /// A boss's phase, from 1.
    public internal(set) var phase = 1
    /// Holds itself in the air at the tuning's flight height instead of falling.
    public internal(set) var flying = false
    /// Dropping back to the floor; it lands open to attack.
    public internal(set) var descending = false
    /// Second scratch counter for brains.
    var aiAux2 = 0
    var aiAux3 = 0
    /// A partner left standing on a plate when control passed away from it: it stays there and holds it down.
    public internal(set) var holding = false
    /// An attack whose effect the world applies after this frame.
    var pendingEffect: Int?
    var markScale = 1.0
    /// Damage multiplier of the swing in progress; above 1 for the counter after an absorbed hit.
    var swingScale = 1.0
    var specialBuffer = 0
    var wantsCommand = false
    /// A heal or a decoy waiting for the world, which needs the other fighters to carry it out.
    var wantsSpecial = false
    /// Frames left before a decoy goes. Zero for everyone else.
    public internal(set) var expires = 0

    /// False for a placed enemy that has not noticed a hero yet; it patrols instead of fighting.
    public var awake = true
    /// Index of the platform it stands on, when it stands on one.
    public internal(set) var groundIndex: Int?
    public internal(set) var coyote = 0
    var patrolFrames = 0
    var strandedFrames = 0
    var lastSafe: Vec2?
    var attackBuffer = 0
    var jumpBuffer = 0
    var dodgeBuffer = 0
    var hitIDs: Set<Int> = []
    var sinceHit = 0

    init(id: Int, kind: FighterKind, team: Team, spec: FighterSpec, pos: Vec2, facing: Double) {
        self.id = id
        self.kind = kind
        self.team = team
        self.spec = spec
        self.pos = pos
        self.facing = facing
        self.hp = spec.maxHP
    }

    public var isAlive: Bool { state != .dead }

    public var hurtbox: Box {
        Box(minX: pos.x - spec.width / 2, minY: pos.y, maxX: pos.x + spec.width / 2, maxY: pos.y + spec.height)
    }

    public var currentAttack: AttackSpec? {
        if case .attack(let i) = state { spec.attacks[i] } else { nil }
    }

    public var attackPhase: AttackPhase? {
        guard let a = currentAttack else { return nil }
        if stateFrame < a.windup { return .windup }
        if stateFrame < a.windup + a.active { return .active }
        return .recovery
    }

    /// The area a swing hits, while it is in its active frames.
    public var hitbox: Box? {
        guard let a = currentAttack, attackPhase == .active, a.effect == .strike else { return nil }
        if a.bothSides {
            return Box(minX: pos.x - spec.width / 2 - a.reach, minY: pos.y + a.yOffset,
                       maxX: pos.x + spec.width / 2 + a.reach, maxY: pos.y + a.yOffset + a.height)
        }
        let front = pos.x + facing * (spec.width / 2 + a.reach)
        return Box(minX: min(pos.x, front), minY: pos.y + a.yOffset,
                   maxX: max(pos.x, front), maxY: pos.y + a.yOffset + a.height)
    }

    public var isDodgeInvulnerable: Bool {
        guard state == .dodge, let d = spec.dodge else { return false }
        return d.invulnerable.contains(stateFrame)
    }

    public var isParrying: Bool {
        guard case .attack = state else { return false }
        return stateFrame < spec.parryWindow
    }

    /// True while a frontal hit would be stopped by its shield.
    public var isGuarding: Bool {
        guard spec.frontalBlock else { return false }
        if state == .idle || state == .run { return true }
        // A duellist keeps its guard up through the windup and the swing; it opens only as it recovers.
        if spec.guardsWhileSwinging, case .attack = state { return attackPhase != .recovery }
        return false
    }

    /// True while an armoured fighter can be hurt: after its own attack, or staggered by a parry.
    public var isOpen: Bool {
        !spec.armored || attackPhase == .recovery || state == .staggered
    }

    var isActionable: Bool { state == .idle || state == .run || state == .air }

    mutating func enter(_ newState: FighterState, duration: Int = 0) {
        state = newState
        stateFrame = 0
        stateDuration = duration
    }
}
