/// What happened during a step. The renderer and the sound layer react to these; they never decide outcomes.
public enum GameEvent: Equatable, Sendable {
    case spawned(id: Int, kind: FighterKind)
    case swing(id: Int, index: Int)
    case hit(attacker: Int, target: Int, damage: Double, at: Vec2)
    case blocked(attacker: Int, target: Int, at: Vec2)
    case parried(by: Int, attacker: Int, at: Vec2)
    case evaded(id: Int)
    case jumped(id: Int)
    case landed(id: Int)
    case dodged(id: Int)
    case fuseLit(id: Int)
    case exploded(id: Int, at: Vec2, radius: Double)
    case died(id: Int)
    case waveStarted(number: Int)
    case waveCleared(number: Int)
    case controlChanged(id: Int)
    case revived(id: Int)
    case heroDown
    case fell(id: Int)
    case respawned(id: Int)
    case checkpoint(index: Int)
    case collected(id: Int, secret: Bool, at: Vec2)
    case woke(id: Int)
    case levelComplete
    /// A companion found in the level starts fighting at the hero's side.
    case joined(id: Int)
    /// A companion left behind catches up in one step.
    case regrouped(id: Int, at: Vec2)
    case bossDefeated(id: Int)
    case slowed(id: Int)
    /// A boss crossed a health threshold and starts its next phase.
    case bossPhase(id: Int, phase: Int)
    /// A boss came down from the air and is open.
    case bossLanded(id: Int)
    /// A column of light began to burn.
    case struck(at: Vec2, width: Double, kind: StrikeKind)
    /// Something was thrown and will land at `at`.
    case lobbed(id: Int, kind: StrikeKind, at: Vec2)
    /// A summoned thing ran out of time and faded.
    case faded(id: Int, at: Vec2)
    /// Caelen's Command put a mark on an enemy.
    case commanded(by: Int, target: Int)
    /// Orion's Adapt: the guard went up.
    case guarded(id: Int)
    /// A hit landed on the guard and did nothing.
    case absorbed(by: Int, attacker: Int, at: Vec2)
    /// A story scene is due. The simulation only says so; showing it is the app's work.
    case scene(id: String)
    /// A hero got health back from a heal.
    case healed(id: Int, amount: Double)
    /// A flare went off; `radius` is how far it reaches.
    case flared(id: Int, at: Vec2, radius: Double)
    /// An eclipse went off: the dark counterpart of a flare.
    case eclipsed(id: Int, at: Vec2, radius: Double)
    /// Caught looking into a flare.
    case dazed(id: Int)
    case decoyPlaced(id: Int, at: Vec2)
    /// A decoy broke or ran out.
    case decoyGone(id: Int, at: Vec2)
}
