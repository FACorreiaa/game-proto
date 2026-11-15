/// Every number that decides how the game feels. Change values here, not in the logic.
public struct Tuning: Sendable {
    public static let framesPerSecond = 60.0

    public var gravity = 1900.0
    /// Extra gravity multiplier while rising with jump released, which makes a tap a short hop.
    public var jumpCutGravity = 2.4
    public var airControl = 0.9
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

    public init() {}

    public func spec(for kind: FighterKind) -> FighterSpec {
        switch kind {
        case .caelen: caelen
        case .dummy: dummy
        case .scrapDrone: scrapDrone
        case .forgedSoldier: forgedSoldier
        }
    }
}
