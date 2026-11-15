/// Every number that decides how the game feels. Change values here, not in the logic.
public struct Tuning: Sendable {
    public static let framesPerSecond = 60.0

    public var gravity = 1900.0
    /// Extra gravity multiplier while rising with jump released, which makes a tap a short hop.
    public var jumpCutGravity = 2.4
    public var airControl = 0.9
    /// Speed gained per second while pushing the stick, on the ground and in the air.
    public var groundAccel = 3200.0
    public var airAccel = 2200.0
    /// Speed lost per second with the stick released on the ground. In the air momentum is kept longer.
    public var groundDecel = 3800.0
    public var airDecel = 900.0
    /// Speed changed per second while pushing against the current direction: a quick turn.
    public var turnAccel = 6000.0
    public var maxFallSpeed = 1500.0

    /// Health lost by falling out of the level; the hero is put back on the last safe ground.
    public var fallDamage = 15.0
    public var checkpointHeal = 30.0
    public var pickupReach = 16.0
    /// A placed enemy notices a hero inside this box around itself.
    public var wakeRange = 520.0
    public var wakeHeight = 220.0
    /// Enemies ignore a hero this far above or below them.
    public var enemySightHeight = 150.0
    public var patrolSpeed = 0.35
    public var patrolTurnFrames = 150
    public var coyoteFrames = 6
    public var jumpBuffer = 7
    public var attackBuffer = 10
    public var dodgeBuffer = 8

    public var parryStagger = 80
    public var parryHitStop = 10
    public var staggerDamageBonus = 1.5
    public var heroHurtHitStop = 6
    public var hitstunFriction = 0.86

    public var corpseFrames = 45
    public var dummyRegenFrames = 120
    public var waveDelay = 100
    public var waveClearHeal = 20.0

    public var droneAttackGap = 40...85
    public var soldierAttackGap = 50...90
    public var soldierTurnDelay = 28
    public var protocolAttackGap = 70...110
    /// Below this fraction of health The Protocol attacks more often.
    public var protocolEnrageAt = 0.5
    public var protocolEnrageGapScale = 0.65
    /// Frames it needs to turn around, which is the time a hero behind it has.
    public var protocolTurnDelay = 26
    /// How often it slams a hero standing close, rather than charging or sending a surge.
    public var protocolSlamChance = 0.6
    /// Frames between the boss falling and the level ending.
    public var bossVictoryFrames = 110

    /// The AI partner hits softer than the player does, so it helps without taking the fight over.
    public var partnerDamageScale = 0.6
    public var partnerAttackGap = 22...50
    /// How often the partner reacts to a telegraphed attack by dodging.
    public var partnerDodgeChance = 0.6
    public var partnerFollowDistance = 80.0
    public var partnerEngageRange = 420.0
    public var switchCooldown = 20
    public var specialBuffer = 8
    /// How often the AI partner raises its guard instead of dodging, when the guard is ready.
    public var partnerGuardChance = 0.5
    /// A companion waiting in a level joins when the hero comes this close.
    public var joinRange = 90.0
    /// Further behind than this, or stuck on another floor for `partnerStrandedFrames`, the partner catches up at once.
    public var partnerRegroupDistance = 560.0
    public var partnerStrandedHeight = 60.0
    public var partnerStrandedFrames = 150
    /// A fallen hero gets back up with this fraction of health when a wave is cleared.
    public var reviveFraction = 0.4

    public var caelen: FighterSpec = {
        var s = FighterSpec(width: 36, height: 84, maxHP: 100, runSpeed: 270)
        s.jumpSpeed = 660
        s.attacks = [
            AttackSpec(windup: 3, active: 4, recovery: 11, damage: 10, reach: 62, height: 70, yOffset: 10,
                       knockback: 140, lunge: 90, hitstun: 14, hitStop: 3),
            AttackSpec(windup: 3, active: 4, recovery: 13, damage: 12, reach: 66, height: 70, yOffset: 10,
                       knockback: 160, lunge: 110, hitstun: 16, hitStop: 3),
            AttackSpec(windup: 6, active: 5, recovery: 20, damage: 22, reach: 78, height: 80, yOffset: 6,
                       knockback: 380, lunge: 170, hitstun: 26, hitStop: 7),
        ]
        s.dodge = DodgeSpec(duration: 16, speed: 560, invulnerable: 1...11, cooldown: 24)
        s.parryWindow = 8
        s.hurtInvulnerable = 40
        s.special = .command(range: 560, frames: 420, damageScale: 1.4, cooldown: 600)
        s.brain = PartnerBrain()
        return s
    }()

    public var orion: FighterSpec = {
        var s = FighterSpec(width: 34, height: 86, maxHP: 90, runSpeed: 285)
        s.jumpSpeed = 660
        s.attacks = [
            AttackSpec(windup: 2, active: 3, recovery: 9, damage: 7, reach: 50, height: 66, yOffset: 12,
                       knockback: 110, lunge: 120, hitstun: 12, hitStop: 2),
            AttackSpec(windup: 3, active: 4, recovery: 14, damage: 11, reach: 56, height: 70, yOffset: 10,
                       knockback: 220, lunge: 150, hitstun: 18, hitStop: 4),
        ]
        s.dodge = DodgeSpec(duration: 16, speed: 580, invulnerable: 1...11, cooldown: 22)
        s.parryWindow = 6
        s.hurtInvulnerable = 40
        s.special = .adapt(window: 34, stagger: 55, counterScale: 2.2, cooldown: 420)
        s.brain = PartnerBrain()
        return s
    }()

    public var dummy: FighterSpec = {
        var s = FighterSpec(width: 40, height: 90, maxHP: 300, runSpeed: 0)
        s.immortal = true
        s.rooted = true
        return s
    }()

    public var scrapDrone: FighterSpec = {
        var s = FighterSpec(width: 44, height: 36, maxHP: 30, runSpeed: 190)
        s.attacks = [
            AttackSpec(windup: 18, active: 4, recovery: 24, damage: 8, reach: 26, height: 36,
                       knockback: 160, lunge: 260, hitstun: 14, hitStop: 4),
        ]
        s.selfDestruct = SelfDestructSpec(threshold: 0.4, fuse: 55, radius: 105, damage: 16, speedFactor: 0.75)
        s.brain = DroneBrain()
        return s
    }()

    public var forgedSoldier: FighterSpec = {
        var s = FighterSpec(width: 48, height: 100, maxHP: 90, runSpeed: 80)
        s.attacks = [
            AttackSpec(windup: 30, active: 5, recovery: 34, damage: 18, reach: 80, height: 90,
                       knockback: 320, lunge: 60, hitstun: 20, hitStop: 6),
        ]
        s.frontalBlock = true
        s.poise = true
        s.brain = SoldierBrain()
        return s
    }()

    /// The Protocol. Attack 0 is the slam (close), 1 the charge (dodge through it), 2 the floor surge (jump it).
    public var theProtocol: FighterSpec = {
        var s = FighterSpec(width: 150, height: 250, maxHP: 460, runSpeed: 55)
        var slam = AttackSpec(windup: 48, active: 6, recovery: 72, damage: 22, reach: 115, height: 130,
                              knockback: 420, lunge: 0, hitstun: 22, hitStop: 7)
        var charge = AttackSpec(windup: 56, active: 24, recovery: 84, damage: 20, reach: 40, height: 150,
                                knockback: 460, lunge: 520, hitstun: 22, hitStop: 7)
        charge.holdsStill = true
        var surge = AttackSpec(windup: 62, active: 8, recovery: 76, damage: 16, reach: 640, height: 34,
                               knockback: 240, lunge: 0, hitstun: 18, hitStop: 5)
        s.attacks = [slam, charge, surge]
        s.armored = true
        s.boss = true
        s.poise = true
        s.wakeDelay = 110
        s.brain = ProtocolBrain()
        return s
    }()

    public init() {}

    public func spec(for kind: FighterKind) -> FighterSpec {
        switch kind {
        case .caelen: caelen
        case .orion: orion
        case .dummy: dummy
        case .scrapDrone: scrapDrone
        case .forgedSoldier: forgedSoldier
        case .theProtocol: theProtocol
        }
    }
}
