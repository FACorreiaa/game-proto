public enum Team: Sendable, Equatable {
    case hero
    case enemy
}

extension FighterKind {
    public var team: Team {
        switch self {
        case .caelen, .orion: .hero
        case .dummy, .scrapDrone, .forgedSoldier, .theProtocol: .enemy
        }
    }
}

public enum FighterKind: String, Sendable, Equatable, CaseIterable {
    case caelen
    case orion
    case dummy
    case scrapDrone
    case forgedSoldier
    case theProtocol
}

/// One swing. All durations are in frames at 60 per second.
public struct AttackSpec: Sendable, Equatable {
    public var windup: Int
    public var active: Int
    public var recovery: Int
    public var damage: Double
    /// How far the hitbox reaches past the front of the body.
    public var reach: Double
    public var height: Double
    public var yOffset: Double
    public var knockback: Double
    /// Forward speed while winding up and striking.
    public var lunge: Double
    public var hitstun: Int
    public var hitStop: Int
    /// Stands still through the windup and moves only while striking: a charge.
    public var holdsStill = false

    public var total: Int { windup + active + recovery }
    /// First frame on which a buffered attack press chains into the next swing.
    public var chainFrom: Int { windup + 2 }

    public init(
        windup: Int, active: Int, recovery: Int, damage: Double, reach: Double, height: Double,
        yOffset: Double = 0, knockback: Double, lunge: Double, hitstun: Int, hitStop: Int
    ) {
        self.windup = windup
        self.active = active
        self.recovery = recovery
        self.damage = damage
        self.reach = reach
        self.height = height
        self.yOffset = yOffset
        self.knockback = knockback
        self.lunge = lunge
        self.hitstun = hitstun
        self.hitStop = hitStop
    }
}

public struct DodgeSpec: Sendable, Equatable {
    public var duration: Int
    public var speed: Double
    /// Frames of the dodge during which nothing can hit.
    public var invulnerable: ClosedRange<Int>
    public var cooldown: Int

    public init(duration: Int, speed: Double, invulnerable: ClosedRange<Int>, cooldown: Int) {
        self.duration = duration
        self.speed = speed
        self.invulnerable = invulnerable
        self.cooldown = cooldown
    }
}

public struct SelfDestructSpec: Sendable, Equatable {
    /// Fraction of max HP at or below which the fuse lights.
    public var threshold: Double
    public var fuse: Int
    public var radius: Double
    public var damage: Double
    public var speedFactor: Double

    public init(threshold: Double, fuse: Int, radius: Double, damage: Double, speedFactor: Double) {
        self.threshold = threshold
        self.fuse = fuse
        self.radius = radius
        self.damage = damage
        self.speedFactor = speedFactor
    }
}

public struct FighterSpec: Sendable {
    public var width: Double
    public var height: Double
    public var maxHP: Double
    public var runSpeed: Double
    /// Zero means it cannot jump.
    public var jumpSpeed: Double = 0
    public var attacks: [AttackSpec] = []
    public var dodge: DodgeSpec?
    /// Frames at the start of a swing during which an incoming enemy hit is deflected.
    public var parryWindow = 0
    /// Frames of safety after being hurt.
    public var hurtInvulnerable = 0
    /// Hits from the front do nothing while it is standing or walking.
    public var frontalBlock = false
    /// Being hit during its own swing does not interrupt the swing.
    public var poise = false
    public var selfDestruct: SelfDestructSpec?
    public var immortal = false
    public var rooted = false
    /// Hits do nothing and never interrupt it, except while it recovers from its own attack or is staggered.
    public var armored = false
    /// The level ends when it falls. It waits for the hero instead of patrolling, and its brain picks each attack.
    public var boss = false
    /// Frames it takes to rise after noticing a hero, before its first move.
    public var wakeDelay = 0
    public var brain: (any Brain)?

    public init(width: Double, height: Double, maxHP: Double, runSpeed: Double) {
        self.width = width
        self.height = height
        self.maxHP = maxHP
        self.runSpeed = runSpeed
    }
}
