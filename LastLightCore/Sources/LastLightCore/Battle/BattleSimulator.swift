public enum BattleSimulator {
    public static let ticksPerSecond = 30
    /// 90 seconds; a fight still running at this point ends as `.timedOut`.
    public static let maxTicks = 2700

    public static func run(_ setup: BattleSetup) -> BattleResult {
        var battle = Battle(setup: setup)
        return battle.run()
    }
}

/// One fight's mutable state. Actions due on the same tick target from the tick-start snapshot and apply in
/// `CombatantID` order; deaths are settled once at the end of the tick, so simultaneous kills are draws.
private struct Battle {
    private var units: [CombatantID: Combatant] = [:]
    private let order: [CombatantID]
    private var events: [BattleEvent] = []
    private var tick = 0

    init(setup: BattleSetup) {
        for formation in [setup.player, setup.enemy] {
            for (slot, instance) in formation.units {
                let id = CombatantID(side: formation.side, slot: slot)
                let data = instance.definition.data(for: instance.stage)
                units[id] = Combatant(id: id, unitID: instance.id, stats: data.stats, ability: data.ability)
            }
        }
        order = units.keys.sorted()
    }

    mutating func run() -> BattleResult {
        if let outcome = outcome() { return finish(outcome) }
        while tick < BattleSimulator.maxTicks {
            tick += 1
            step()
            if let outcome = outcome() { return finish(outcome) }
        }
        return finish(.timedOut)
    }

    private mutating func step() {
        var due: [CombatantID] = []
        for id in order where units[id]!.isAlive {
            units[id]!.cooldown -= 1
            if units[id]!.cooldown <= 0 {
                units[id]!.cooldown = units[id]!.stats.attackInterval
                due.append(id)
            }
        }
        let snapshot = units
        for id in due { act(id, snapshot: snapshot) }
        for id in order where units[id]!.isAlive && units[id]!.hp <= 0 {
            units[id]!.isAlive = false
            events.append(.death(tick: tick, unit: id))
        }
    }

    private mutating func act(_ id: CombatantID, snapshot: [CombatantID: Combatant]) {
        let actor = snapshot[id]!
        let allies = snapshot.values.filter { $0.id.side == id.side }
        let enemies = snapshot.values.filter { $0.id.side != id.side }
        guard let targetID = Targeting.targets(for: .basicTarget, actor: actor, allies: allies, enemies: enemies).first
        else { return }
        let amount = max(1, units[id]!.stats.attack - units[targetID]!.stats.armor)
        let (_, hpAfter) = applyDamage(amount, to: targetID)
        events.append(.attack(tick: tick, source: id, target: targetID, damage: amount, hpAfter: hpAfter))
    }

    /// Shield absorbs first; HP never drops below 0. Returns (absorbed, hpAfter).
    private mutating func applyDamage(_ amount: Int, to id: CombatantID) -> (Int, Int) {
        let absorbed = min(units[id]!.shield, amount)
        units[id]!.shield -= absorbed
        units[id]!.hp = max(0, units[id]!.hp - (amount - absorbed))
        return (absorbed, units[id]!.hp)
    }

    private func outcome() -> BattleOutcome? {
        let playerAlive = units.values.contains { $0.id.side == .player && $0.isAlive }
        let enemyAlive = units.values.contains { $0.id.side == .enemy && $0.isAlive }
        switch (playerAlive, enemyAlive) {
        case (false, false): return .draw
        case (true, false): return .playerWon
        case (false, true): return .enemyWon
        case (true, true): return nil
        }
    }

    private mutating func finish(_ outcome: BattleOutcome) -> BattleResult {
        events.append(.ended(tick: tick, outcome: outcome))
        return BattleResult(outcome: outcome, durationTicks: tick, events: events,
                            finalHP: units.mapValues(\.hp))
    }
}
