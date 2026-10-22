public struct CombatantID: Hashable, Sendable, Comparable {
    public let side: Side
    public let slot: Slot

    public init(side: Side, slot: Slot) {
        self.side = side
        self.slot = slot
    }

    /// Player before enemy, then slot order.
    public static func < (lhs: CombatantID, rhs: CombatantID) -> Bool {
        if lhs.side != rhs.side { return lhs.side == .player }
        return lhs.slot < rhs.slot
    }
}

/// A unit's mutable state for the duration of one battle.
struct Combatant: Sendable {
    let id: CombatantID
    let unitID: UnitID
    /// Final stats for this battle (stage and bonds already applied).
    var stats: UnitStats
    let ability: Ability
    var hp: Int
    var shield = 0
    var charge = 0
    var cooldown: Int
    /// Flipped only by the end-of-tick death check, so a unit killed mid-tick still acts on that tick.
    var isAlive = true

    init(id: CombatantID, unitID: UnitID, stats: UnitStats, ability: Ability) {
        self.id = id
        self.unitID = unitID
        self.stats = stats
        self.ability = ability
        hp = stats.maxHP
        cooldown = stats.attackInterval
    }
}
