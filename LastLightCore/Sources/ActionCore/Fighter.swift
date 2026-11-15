public enum FighterState: Equatable, Sendable {
    case idle
    case run
    case air
    case attack(Int)
    case dodge
    case hitstun
    case staggered
    case fuse
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

    var coyote = 0
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
        guard let a = currentAttack, attackPhase == .active else { return nil }
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
        spec.frontalBlock && (state == .idle || state == .run)
    }

    var isActionable: Bool { state == .idle || state == .run || state == .air }

    mutating func enter(_ newState: FighterState, duration: Int = 0) {
        state = newState
        stateFrame = 0
        stateDuration = duration
    }
}
