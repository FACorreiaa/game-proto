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
    /// Damage heroes take from enemies is multiplied by this. The difficulty setting: below 1 is easier.
    public var heroDamageScale = 1.0
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
    public var sentryAttackGap = 90...140
    /// The Sentry Core keeps its target between these distances.
    public var sentryNear = 250.0
    public var sentryFar = 400.0
    /// Speed of a slowed fighter, as a fraction of normal.
    public var slowFactor = 0.5
    /// The Dogma Frame stays this close to the machine it shields.
    public var dogmaFollowDistance = 110.0
    public var wardHeight = 220.0
    public var protocolAttackGap = 70...110
    /// In its last phase The Protocol waits this fraction of the usual time between attacks.
    public var protocolExecutionGapScale = 0.6
    /// Frames a phase change lasts. It cannot be hurt meanwhile.
    public var bossPhaseShiftFrames = 100
    /// Ascension: how high it flies, how many attacks it makes up there and on the ground before switching.
    public var protocolFlightHeight = 170.0
    public var protocolAirActions = 3
    public var protocolGroundActions = 2
    public var protocolAirGap = 60...90
    public var protocolTakeoffPause = 80
    /// Frames it stays open after crashing back down.
    public var protocolLandOpen = 150
    /// Machines it summons are capped at this many alive at once.
    public var protocolMaxMinions = 2
    /// How many of one summoned kind an ordinary enemy keeps alive near it.
    public var maxSummoned = 2

    // Lantern Cities enemies.
    public var ratbornAttackGap = 50...90
    /// Frames a Ratborn backs off after it bites.
    public var ratbornRetreat = 30...70
    /// Chance a Ratborn breaks off its approach for a moment, so it's never a straight line in.
    public var ratbornFeintChance = 0.012
    public var gunnerNear = 220.0
    public var gunnerFar = 380.0
    public var gunnerAttackGap = 110...160
    public var bruteAttackGap = 70...110
    public var bruteSlamChance = 0.45
    public var bruteTurnDelay = 20
    public var weaverNear = 200.0
    public var weaverFar = 360.0
    public var weaverAttackGap = 100...150

    // The Cinder King.
    public var cinderAttackGap = 60...100
    /// In the last phase it acts this much sooner.
    public var cinderPriceGapScale = 0.7
    public var cinderTurnDelay = 12
    /// Up close it swings or sweeps this often instead of throwing.
    public var cinderCloseChance = 0.7
    /// How far from him his debtors still shield him.
    public var debtorShieldRange = 900.0
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

    public var seraphine: FighterSpec = {
        var s = FighterSpec(width: 34, height: 86, maxHP: 90, runSpeed: 255)
        // Levels are built for this jump; a lower one can't clear their walls.
        s.jumpSpeed = 660
        s.attacks = [
            // A close swing of the staff, then a bolt of light that reaches across the room.
            AttackSpec(windup: 4, active: 4, recovery: 12, damage: 9, reach: 58, height: 70, yOffset: 10,
                       knockback: 120, lunge: 60, hitstun: 14, hitStop: 3),
            AttackSpec(windup: 9, active: 3, recovery: 18, damage: 14, reach: 240, height: 26, yOffset: 44,
                       knockback: 200, lunge: 0, hitstun: 18, hitStop: 4),
        ]
        s.dodge = DodgeSpec(duration: 16, speed: 560, invulnerable: 1...11, cooldown: 24)
        s.parryWindow = 6
        s.hurtInvulnerable = 40
        s.special = .heal(amount: 30, range: 300, cooldown: 720)
        s.brain = PartnerBrain()
        return s
    }()

    public var nimue: FighterSpec = {
        var s = FighterSpec(width: 32, height: 80, maxHP: 85, runSpeed: 300)
        s.jumpSpeed = 700
        s.attacks = [
            // Thrown blades: quick and light, the third one heavier.
            AttackSpec(windup: 2, active: 3, recovery: 9, damage: 7, reach: 140, height: 24, yOffset: 46,
                       knockback: 80, lunge: 30, hitstun: 10, hitStop: 2),
            AttackSpec(windup: 2, active: 3, recovery: 10, damage: 7, reach: 140, height: 24, yOffset: 40,
                       knockback: 80, lunge: 30, hitstun: 10, hitStop: 2),
            AttackSpec(windup: 5, active: 4, recovery: 16, damage: 15, reach: 160, height: 30, yOffset: 42,
                       knockback: 260, lunge: 40, hitstun: 20, hitStop: 5),
        ]
        s.dodge = DodgeSpec(duration: 14, speed: 620, invulnerable: 1...10, cooldown: 20)
        s.parryWindow = 6
        s.hurtInvulnerable = 40
        s.special = .decoy(frames: 180, cooldown: 600)
        s.brain = PartnerBrain()
        return s
    }()

    public var decoy: FighterSpec = {
        var s = FighterSpec(width: 32, height: 80, maxHP: 35, runSpeed: 0)
        s.isDecoy = true
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

    /// Sentry Core: floats at chest height, keeps its distance and fires a beam along the floor line.
    public var sentryCore: FighterSpec = {
        var s = FighterSpec(width: 40, height: 40, maxHP: 40, runSpeed: 150)
        var beam = AttackSpec(windup: 50, active: 6, recovery: 40, damage: 10, reach: 480, height: 22, yOffset: 0,
                              knockback: 120, lunge: 0, hitstun: 12, hitStop: 4)
        beam.slowFrames = 120
        s.attacks = [beam]
        s.hovers = true
        s.brain = SentryBrain()
        return s
    }()

    /// Dogma Frame: does not attack. Machines near it cannot be hurt until it is destroyed.
    public var dogmaFrame: FighterSpec = {
        var s = FighterSpec(width: 44, height: 110, maxHP: 55, runSpeed: 70)
        s.wardRadius = 260
        s.brain = DogmaBrain()
        return s
    }()

    /// The Protocol. Judgement: 0 slam (close), 1 charge (dodge through it), 2 floor surge (jump it).
    /// Ascension adds 3 summon and 4 laser rain from the air. Execution adds 5 pulse (both sides) and 6 beam.
    public var theProtocol: FighterSpec = {
        var s = FighterSpec(width: 150, height: 250, maxHP: 520, runSpeed: 55)
        var slam = AttackSpec(windup: 48, active: 6, recovery: 72, damage: 22, reach: 115, height: 130,
                              knockback: 420, lunge: 0, hitstun: 22, hitStop: 7)
        var charge = AttackSpec(windup: 56, active: 24, recovery: 84, damage: 20, reach: 40, height: 150,
                                knockback: 460, lunge: 520, hitstun: 22, hitStop: 7)
        charge.holdsStill = true
        var surge = AttackSpec(windup: 62, active: 8, recovery: 76, damage: 16, reach: 640, height: 34,
                               knockback: 240, lunge: 0, hitstun: 18, hitStop: 5)
        // Ascension: called from the air.
        var summon = AttackSpec(windup: 50, active: 1, recovery: 70, damage: 0, reach: 0, height: 0,
                                knockback: 0, lunge: 0, hitstun: 0, hitStop: 0)
        summon.effect = .summon(.scrapDrone, count: 2)
        var rain = AttackSpec(windup: 45, active: 1, recovery: 60, damage: 0, reach: 0, height: 0,
                              knockback: 0, lunge: 0, hitstun: 0, hitStop: 0)
        rain.effect = .rain(columns: 4, width: 80, warning: 55, active: 14, damage: 14)
        // Execution: a pulse along the floor on both sides, and a beam across the room at chest height.
        var pulse = AttackSpec(windup: 54, active: 8, recovery: 70, damage: 16, reach: 520, height: 30,
                               knockback: 260, lunge: 0, hitstun: 18, hitStop: 5)
        pulse.bothSides = true
        let beam = AttackSpec(windup: 64, active: 8, recovery: 80, damage: 22, reach: 900, height: 36, yOffset: 44,
                              knockback: 300, lunge: 0, hitstun: 20, hitStop: 6)
        s.attacks = [slam, charge, surge, summon, rain, pulse, beam]
        s.phaseThresholds = [0.6, 0.3]
        s.flightPhase = 2
        s.armored = true
        s.boss = true
        s.poise = true
        s.wakeDelay = 110
        s.brain = ProtocolBrain()
        return s
    }()

    // MARK: The Lantern Cities

    /// Ratborn: small, quick and erratic. Darts in, bites, backs off.
    public var ratborn: FighterSpec = {
        var s = FighterSpec(width: 30, height: 58, maxHP: 22, runSpeed: 270)
        s.jumpSpeed = 560
        s.attacks = [
            AttackSpec(windup: 10, active: 3, recovery: 12, damage: 6, reach: 30, height: 40,
                       knockback: 120, lunge: 230, hitstun: 12, hitStop: 3),
        ]
        s.brain = RatbornBrain()
        return s
    }()

    /// Lantern Gunner: keeps its distance and throws lanterns that leave the ground burning.
    public var lanternGunner: FighterSpec = {
        var s = FighterSpec(width: 36, height: 80, maxHP: 40, runSpeed: 150)
        s.attacks = [
            AttackSpec(windup: 30, active: 2, recovery: 40, damage: 0, reach: 0, height: 0,
                       knockback: 0, lunge: 0, hitstun: 0, hitStop: 0)
                .with { $0.effect = .lob(Lob(.fire, width: 84, height: 26, warning: 44, active: 70, damage: 10, range: 420)) },
        ]
        s.brain = GunnerBrain()
        return s
    }()

    /// Smuggler Brute: a wall of health. Its swing isn't stopped by being hit, and its slam hits both sides.
    public var smugglerBrute: FighterSpec = {
        var s = FighterSpec(width: 60, height: 104, maxHP: 170, runSpeed: 120)
        s.attacks = [
            AttackSpec(windup: 22, active: 5, recovery: 30, damage: 16, reach: 70, height: 80,
                       knockback: 300, lunge: 60, hitstun: 18, hitStop: 6),
            AttackSpec(windup: 46, active: 6, recovery: 50, damage: 22, reach: 120, height: 50, yOffset: 0,
                       knockback: 380, lunge: 0, hitstun: 24, hitStop: 8)
                .with { $0.bothSides = true },
        ]
        s.poise = true
        s.choosesAttacks = true
        s.brain = BruteBrain()
        return s
    }()

    /// Night Weaver: stays back, sends copies of itself in, and lays snares where the hero will walk.
    public var nightWeaver: FighterSpec = {
        var s = FighterSpec(width: 34, height: 88, maxHP: 70, runSpeed: 210)
        s.attacks = [
            AttackSpec(windup: 36, active: 2, recovery: 40, damage: 0, reach: 0, height: 0,
                       knockback: 0, lunge: 0, hitstun: 0, hitStop: 0)
                .with { $0.effect = .summon(.weaverImage, count: 2) },
            AttackSpec(windup: 24, active: 2, recovery: 36, damage: 0, reach: 0, height: 0,
                       knockback: 0, lunge: 0, hitstun: 0, hitStop: 0)
                .with { $0.effect = .lob(Lob(.snare, width: 70, height: 14, warning: 30, active: 240, damage: 4,
                                             slowFrames: 90, range: 380)) },
        ]
        s.choosesAttacks = true
        s.brain = WeaverBrain()
        return s
    }()

    /// A Night Weaver's image: looks like the Weaver, breaks in one hit, hits lightly, and fades in six seconds.
    public var weaverImage: FighterSpec = {
        var s = FighterSpec(width: 34, height: 88, maxHP: 1, runSpeed: 230)
        s.attacks = [
            AttackSpec(windup: 14, active: 3, recovery: 16, damage: 3, reach: 40, height: 60,
                       knockback: 60, lunge: 120, hitstun: 8, hitStop: 2),
        ]
        s.lifetime = 360
        s.brain = DroneBrain()
        return s
    }()

    /// The Cinder King. Offer: a cane and thrown lanterns. Debt: calls Ratborn, who shield him while they live,
    /// and fire bursts from the floor. Price: faster, with a sweep on both sides and wider eruptions.
    public var cinderKing: FighterSpec = {
        var s = FighterSpec(width: 76, height: 150, maxHP: 720, runSpeed: 95)
        let cane = AttackSpec(windup: 28, active: 6, recovery: 36, damage: 16, reach: 110, height: 100,
                              knockback: 320, lunge: 80, hitstun: 18, hitStop: 6)
        let lantern = AttackSpec(windup: 34, active: 1, recovery: 46, damage: 0, reach: 0, height: 0,
                                 knockback: 0, lunge: 0, hitstun: 0, hitStop: 0)
            .with { $0.effect = .lob(Lob(.fire, width: 100, height: 30, warning: 50, active: 90, damage: 12, range: 700)) }
        let debtors = AttackSpec(windup: 44, active: 1, recovery: 60, damage: 0, reach: 0, height: 0,
                                 knockback: 0, lunge: 0, hitstun: 0, hitStop: 0)
            .with { $0.effect = .summon(.ratborn, count: 2) }
        let vents = AttackSpec(windup: 40, active: 1, recovery: 56, damage: 0, reach: 0, height: 0,
                               knockback: 0, lunge: 0, hitstun: 0, hitStop: 0)
            .with { $0.effect = .eruption(columns: 3, width: 70, height: 170, warning: 56, active: 22, damage: 16) }
        let sweep = AttackSpec(windup: 42, active: 7, recovery: 48, damage: 20, reach: 160, height: 60, yOffset: 0,
                               knockback: 380, lunge: 0, hitstun: 22, hitStop: 7)
            .with { $0.bothSides = true }
        let wideVents = vents.with {
            $0.effect = .eruption(columns: 5, width: 70, height: 170, warning: 50, active: 22, damage: 16)
        }
        s.attacks = [cane, lantern, debtors, vents, sweep, wideVents]
        s.phaseThresholds = [0.65, 0.3]
        s.shieldedBy = .ratborn
        s.boss = true
        s.poise = true
        s.wakeDelay = 100
        s.brain = CinderKingBrain()
        return s
    }()

    public init() {}

    public func spec(for kind: FighterKind) -> FighterSpec {
        switch kind {
        case .caelen: caelen
        case .orion: orion
        case .seraphine: seraphine
        case .nimue: nimue
        case .decoy: decoy
        case .dummy: dummy
        case .scrapDrone: scrapDrone
        case .forgedSoldier: forgedSoldier
        case .sentryCore: sentryCore
        case .dogmaFrame: dogmaFrame
        case .theProtocol: theProtocol
        case .ratborn: ratborn
        case .lanternGunner: lanternGunner
        case .smugglerBrute: smugglerBrute
        case .nightWeaver: nightWeaver
        case .weaverImage: weaverImage
        case .cinderKing: cinderKing
        }
    }
}
