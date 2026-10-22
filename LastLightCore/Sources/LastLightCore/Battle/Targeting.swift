enum Targeting {
    /// Living targets for `selector`, from the actor's point of view. Empty when nothing is valid.
    static func targets(for selector: TargetSelector, actor: Combatant,
                        allies: [Combatant], enemies: [Combatant]) -> [CombatantID] {
        let livingEnemies = enemies.filter(\.isAlive)
        switch selector {
        case .basicTarget:
            return nearest(in: column(preferring: [.front, .back], among: livingEnemies), to: actor)
        case .backlineFirst:
            return nearest(in: column(preferring: [.back, .front], among: livingEnemies), to: actor)
        case .enemyFrontColumn:
            return column(preferring: [.front, .back], among: livingEnemies).map(\.id).sorted()
        case .allEnemies:
            return livingEnemies.map(\.id).sorted()
        case .lowestHPAlly:
            let lowest = allies.filter(\.isAlive).min { a, b in
                let lhs = a.hp * b.stats.maxHP, rhs = b.hp * a.stats.maxHP
                return lhs != rhs ? lhs < rhs : a.id < b.id
            }
            return lowest.map { [$0.id] } ?? []
        case .selfOnly:
            return [actor.id]
        }
    }

    /// Living units in the first column of `order` that has anyone in it.
    private static func column(preferring order: [Column], among living: [Combatant]) -> [Combatant] {
        for column in order {
            let units = living.filter { $0.id.slot.column == column }
            if !units.isEmpty { return units }
        }
        return []
    }

    /// Closest row to the actor; ties go to the lower row.
    private static func nearest(in candidates: [Combatant], to actor: Combatant) -> [CombatantID] {
        let pick = candidates.min { a, b in
            let da = abs(a.id.slot.row - actor.id.slot.row), db = abs(b.id.slot.row - actor.id.slot.row)
            return da != db ? da < db : a.id.slot.row < b.id.slot.row
        }
        return pick.map { [$0.id] } ?? []
    }
}
