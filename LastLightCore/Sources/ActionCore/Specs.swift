public enum Team: Sendable, Equatable {
    case hero
    case enemy
}

extension FighterKind {
    public var team: Team {
        switch self {
        case .caelen, .orion, .seraphine, .nimue, .decoy: .hero
        case .dummy, .scrapDrone, .forgedSoldier, .sentryCore, .dogmaFrame, .theProtocol, .lineWarden,
             .ratborn, .lanternGunner, .smugglerBrute, .nightWeaver, .weaverImage, .cinderKing,
             .zealot, .radiantAcolyte, .solarGuard, .haloDisciple, .lastOracle: .enemy
        }
    }
}

public enum FighterKind: String, Sendable, Equatable, CaseIterable {
    case caelen
    case orion
    case seraphine
    case nimue
    /// Nimue's Lantern Trick: a stand-in that draws enemies away. It is on the heroes' side but is not a hero.
    case decoy
    case dummy
    case scrapDrone
    case forgedSoldier
    case sentryCore
    case dogmaFrame
    case theProtocol
    /// Chapter 1's mid-boss: the machine that keeps the line.
    case lineWarden
    // The Lantern Cities.
    case ratborn
    case lanternGunner
    case smugglerBrute
    case nightWeaver
    /// One of a Night Weaver's copies of itself: one hit breaks it, and it fades on its own.
    case weaverImage
    /// The Lantern Cities' boss.
    case cinderKing
    // The Dawnfaith.
    case zealot
    case radiantAcolyte
    case solarGuard
    case haloDisciple
    /// The Dawnfaith's boss.
    case lastOracle
}

/// What an attack does when its active frames begin.
public enum AttackEffect: Sendable, Equatable {
    /// An ordinary hitbox in front of the attacker.
    case strike
    /// Calls fighters in beside the attacker. It never calls more than the tuning allows alive at once.
    case summon(FighterKind, count: Int)
    /// Calls down columns of light: one over each hero, the rest spread over the room.
    case rain(columns: Int, width: Double, warning: Int, active: Int, damage: Double)
    /// Throws something that lands under the target: a burning patch or a snare.
    case lob(Lob)
    /// Fire bursts up from the floor: one column under each hero, the rest spread over the room.
    case eruption(columns: Int, width: Double, height: Double, warning: Int, active: Int, damage: Double,
                  kind: StrikeKind = .fire)
    /// Restores health to its own side within range, the attacker excepted.
    case mend(amount: Double, range: Double)
    /// A burst of light. Anyone within the radius who is facing it, and not dodging, is dazed for a while.
    case flare(radius: Double, daze: Int)
    /// The flare turned inside out: anyone within the radius who is NOT facing it is dazed.
    case eclipse(radius: Double, daze: Int)
    /// A strike laid where each hero will be when it lands, judged from how they are moving now.
    case prophecy(width: Double, height: Double, warning: Int, active: Int, damage: Double)
}

/// What a thrown thing leaves on the ground where it lands. It warns, then stays live for `active` frames and
/// catches each hero at most once.
public struct Lob: Sendable, Equatable {
    public var kind: StrikeKind
    public var width: Double
    public var height: Double
    public var warning: Int
    public var active: Int
    public var damage: Double
    /// Frames a hero it catches moves at reduced speed.
    public var slowFrames: Int
    /// It lands under the target when the target is this close; otherwise this far ahead.
    public var range: Double

    public init(_ kind: StrikeKind, width: Double, height: Double, warning: Int, active: Int, damage: Double,
                slowFrames: Int = 0, range: Double) {
        self.kind = kind
        self.width = width
        self.height = height
        self.warning = warning
        self.active = active
        self.damage = damage
        self.slowFrames = slowFrames
        self.range = range
    }
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
    /// Frames the target moves at reduced speed after being hit.
    public var slowFrames = 0
    /// The hitbox reaches out on both sides, not only in front.
    public var bothSides = false
    public var effect = AttackEffect.strike

    public var total: Int { windup + active + recovery }

    /// A copy with some fields changed, for specs written as literals.
    public func with(_ change: (inout AttackSpec) -> Void) -> AttackSpec {
        var copy = self
        change(&copy)
        return copy
    }
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

/// The one ability each hero has besides the shared moves.
public enum SpecialSpec: Sendable, Equatable {
    /// Marks an enemy. The partner goes for it and every hit on it does more.
    case command(range: Double, frames: Int, damageScale: Double, cooldown: Int)
    /// A short guard. A hit taken during it does nothing, staggers the attacker, and is answered with a counter.
    case adapt(window: Int, stagger: Int, counterScale: Double, cooldown: Int)
    /// Heals every awake hero within range, the user included.
    case heal(amount: Double, range: Double, cooldown: Int)
    /// Leaves a decoy where the user stands. Enemies go for it until it breaks or its time runs out.
    case decoy(frames: Int, cooldown: Int)

    public var cooldown: Int {
        switch self {
        case .command(_, _, _, let cooldown), .adapt(_, _, _, let cooldown), .heal(_, _, let cooldown),
             .decoy(_, let cooldown): cooldown
        }
    }

    public var name: String {
        switch self {
        case .command: "COMMAND"
        case .adapt: "ADAPT"
        case .heal: "LIGHT LISTENS"
        case .decoy: "LANTERN TRICK"
        }
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
    /// The frontal guard stays up through its own windup and swing, dropping only in recovery.
    public var guardsWhileSwinging = false
    /// Being hit during its own swing does not interrupt the swing.
    public var poise = false
    /// Hits never knock it into hitstun; only a parry staggers it.
    public var unflinching = false
    public var selfDestruct: SelfDestructSpec?
    public var immortal = false
    public var rooted = false
    public var special: SpecialSpec?
    /// A stand-in, not a person: it can't be controlled, picks nothing up and never ends the game by falling.
    public var isDecoy = false
    /// Frames it lasts after appearing before it fades by itself. Zero means it stays.
    public var lifetime = 0
    /// Its brain chooses which attack to use next, instead of always opening with the first.
    public var choosesAttacks = false
    /// Floats at the height it was placed at and ignores gravity while it lives.
    public var hovers = false
    /// Machines this close to it cannot be hurt while it lives. Zero means it shields nobody.
    public var wardRadius = 0.0
    /// Fractions of health at which a boss moves to its next phase. It cannot be hurt past one in a single hit.
    public var phaseThresholds: [Double] = []
    /// The phase a boss spends in the air. Zero means it never flies.
    public var flightPhase = 0
    /// While any fighter of this kind lives nearby, hits on it do nothing.
    public var shieldedBy: FighterKind?
    /// The attack it answers with at once when its frontal guard stops a hit.
    public var riposte: Int?
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
