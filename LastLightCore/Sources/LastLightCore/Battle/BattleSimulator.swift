public enum BattleSimulator {
    public static let ticksPerSecond = 30
    /// 90 seconds; a fight still running at this point ends as `.timedOut`.
    public static let maxTicks = 2700

    public static func run(_ setup: BattleSetup) -> BattleResult {
        var battle = Battle(setup: setup)
        return battle.run()
    }
}

private struct Hit {
    let source: CombatantID
    let target: CombatantID
    let amount: Int
    let isBasicAttack: Bool
}

/// Everything decided on one tick, before any of it is applied.
private struct TickPlan {
    var hits: [Hit] = []
    var heals: [(CombatantID, CombatantID, Int)] = []
    var shields: [(CombatantID, CombatantID, Int)] = []
    var chargeDelta: [CombatantID: Int] = [:]
}

/// One fight's mutable state. Actions due on the same tick are all decided from the tick-start snapshot, then
/// applied in phases (see `resolve`); deaths are settled once at the end of the tick, so simultaneous kills are draws.
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
        applyBonds(BondResolver.active(bonds: setup.bonds, levels: setup.bondLevels, in: setup.player))
    }

    /// Each active bond adds its bonuses to both members, computed from their base stats so bonds stack additively.
    private mutating func applyBonds(_ active: [ActiveBond]) {
        let base = units.mapValues(\.stats)
        for bond in active {
            let members = bond.slots.map { CombatantID(side: .player, slot: $0) }
            for id in members {
                units[id]!.stats.attack += base[id]!.attack * bond.effect.attackPercent / 100
                units[id]!.stats.maxHP += base[id]!.maxHP * bond.effect.maxHPPercent / 100
                units[id]!.stats.chargePerAttack += bond.effect.chargePerAttackBonus
                units[id]!.hp = units[id]!.stats.maxHP
            }
            events.append(.bondActivated(tick: 0, bondID: bond.bondID, members: members))
        }
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
        var tickPlan = TickPlan()
        for id in due { plan(id, snapshot: snapshot, into: &tickPlan) }
        resolve(tickPlan)
        for id in order where units[id]!.isAlive && units[id]!.hp <= 0 {
            units[id]!.isAlive = false
            events.append(.death(tick: tick, unit: id))
        }
    }

    /// Decides one actor's action from the tick-start snapshot: cast when charge is full, otherwise basic-attack.
    private mutating func plan(_ id: CombatantID, snapshot: [CombatantID: Combatant], into tickPlan: inout TickPlan) {
        let actor = snapshot[id]!
        let allies = order.compactMap { snapshot[$0] }.filter { $0.id.side == id.side }
        let enemies = order.compactMap { snapshot[$0] }.filter { $0.id.side != id.side }
        if actor.charge >= actor.stats.chargeMax {
            tickPlan.chargeDelta[id, default: 0] -= actor.charge
            let targets = Targeting.targets(for: actor.ability.target, actor: actor, allies: allies, enemies: enemies)
            events.append(.abilityCast(tick: tick, source: id, abilityID: actor.ability.id, targets: targets))
            for target in targets {
                switch actor.ability.effect {
                case let .damage(multiplier):
                    let raw = Int((Double(actor.stats.attack) * multiplier).rounded())
                    tickPlan.hits.append(Hit(source: id, target: target, amount: max(1, raw - snapshot[target]!.stats.armor),
                                             isBasicAttack: false))
                case let .heal(amount):
                    tickPlan.heals.append((id, target, amount))
                case let .shield(amount):
                    tickPlan.shields.append((id, target, amount))
                }
            }
            return
        }
        guard let target = Targeting.targets(for: .basicTarget, actor: actor, allies: allies, enemies: enemies).first
        else { return }
        tickPlan.chargeDelta[id, default: 0] += actor.stats.chargePerAttack
        tickPlan.hits.append(Hit(source: id, target: target, amount: max(1, actor.stats.attack - snapshot[target]!.stats.armor),
                                 isBasicAttack: true))
    }

    /// Applies a tick's effects in side-independent phases: shields, then all damage, then heals, then charge.
    /// Each phase's totals don't depend on the order within it, so neither side gets an edge from processing order.
    private mutating func resolve(_ tickPlan: TickPlan) {
        var chargeDelta = tickPlan.chargeDelta
        for (source, target, amount) in tickPlan.shields {
            units[target]!.shield += amount
            events.append(.shield(tick: tick, source: source, target: target, amount: amount))
        }
        for hit in tickPlan.hits {
            let absorbed = min(units[hit.target]!.shield, hit.amount)
            units[hit.target]!.shield -= absorbed
            units[hit.target]!.hp -= hit.amount - absorbed
            chargeDelta[hit.target, default: 0] += units[hit.target]!.stats.chargePerHitTaken
            let hpAfter = max(0, units[hit.target]!.hp)
            events.append(hit.isBasicAttack
                ? .attack(tick: tick, source: hit.source, target: hit.target, damage: hit.amount, hpAfter: hpAfter)
                : .damage(tick: tick, source: hit.source, target: hit.target, amount: hit.amount,
                          absorbed: absorbed, hpAfter: hpAfter))
        }
        for (source, target, amount) in tickPlan.heals {
            let healed = max(0, min(amount, units[target]!.stats.maxHP - units[target]!.hp))
            units[target]!.hp += healed
            events.append(.heal(tick: tick, source: source, target: target, amount: healed,
                                hpAfter: max(0, units[target]!.hp)))
        }
        for (id, delta) in chargeDelta { units[id]!.charge += delta }
        for id in order { units[id]!.hp = max(0, units[id]!.hp) }
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
