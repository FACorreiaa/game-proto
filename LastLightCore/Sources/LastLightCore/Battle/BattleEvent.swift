public enum BattleOutcome: Sendable, Equatable {
    case playerWon, enemyWon, draw, timedOut
}

/// Everything the renderer needs to replay a fight, and to show why it was won or lost.
public enum BattleEvent: Sendable, Equatable {
    case bondActivated(tick: Int, bondID: BondID, members: [CombatantID])
    case attack(tick: Int, source: CombatantID, target: CombatantID, damage: Int, hpAfter: Int)
    case abilityCast(tick: Int, source: CombatantID, abilityID: String, targets: [CombatantID])
    case damage(tick: Int, source: CombatantID, target: CombatantID, amount: Int, absorbed: Int, hpAfter: Int)
    case heal(tick: Int, source: CombatantID, target: CombatantID, amount: Int, hpAfter: Int)
    case shield(tick: Int, source: CombatantID, target: CombatantID, amount: Int)
    case death(tick: Int, unit: CombatantID)
    case ended(tick: Int, outcome: BattleOutcome)
}

public struct BattleResult: Sendable, Equatable {
    public let outcome: BattleOutcome
    public let durationTicks: Int
    public let events: [BattleEvent]
    public let finalHP: [CombatantID: Int]
}
