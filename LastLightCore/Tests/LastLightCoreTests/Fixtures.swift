@testable import LastLightCore

extension StageData {
    static let dummy = StageData(
        stats: UnitStats(maxHP: 100, attack: 10, armor: 0, attackInterval: 30,
                         chargeMax: 100, chargePerAttack: 10, chargePerHitTaken: 0),
        ability: Ability(id: "dummy-strike", target: .basicTarget, effect: .damage(multiplier: 2))
    )
}

extension UnitDefinition {
    static func dummy(
        id: UnitID,
        hp: [Int],
        attack: Int = 10,
        armor: Int = 0,
        interval: Int = 30,
        chargeMax: Int = 100,
        chargePerAttack: Int = 10,
        chargePerHitTaken: Int = 0,
        ability: Ability = StageData.dummy.ability,
        region: Region = .foundry
    ) -> UnitDefinition {
        let stages = hp.map {
            StageData(stats: UnitStats(maxHP: $0, attack: attack, armor: armor, attackInterval: interval,
                                       chargeMax: chargeMax, chargePerAttack: chargePerAttack,
                                       chargePerHitTaken: chargePerHitTaken),
                      ability: ability)
        }
        return try! UnitDefinition(id: id, name: id, region: region, stages: stages)
    }

    static func dummy(
        id: UnitID,
        hp: Int = 100,
        attack: Int = 10,
        armor: Int = 0,
        interval: Int = 30,
        chargeMax: Int = 100,
        chargePerAttack: Int = 10,
        chargePerHitTaken: Int = 0,
        ability: Ability = StageData.dummy.ability,
        region: Region = .foundry
    ) -> UnitDefinition {
        dummy(id: id, hp: [hp, hp, hp], attack: attack, armor: armor, interval: interval,
              chargeMax: chargeMax, chargePerAttack: chargePerAttack, chargePerHitTaken: chargePerHitTaken,
              ability: ability, region: region)
    }
}

extension UnitInstance {
    static func fixture(_ id: UnitID, stage: Stage = .one) -> UnitInstance {
        UnitInstance(definition: .dummy(id: id), stage: stage)
    }
}

extension Slot {
    static let front0 = Slot(column: .front, row: 0)!
    static let front1 = Slot(column: .front, row: 1)!
    static let front2 = Slot(column: .front, row: 2)!
    static let back0 = Slot(column: .back, row: 0)!
    static let back1 = Slot(column: .back, row: 1)!
    static let back2 = Slot(column: .back, row: 2)!
}

extension Formation {
    static func player(_ placements: [(UnitID, Slot)]) -> Formation {
        var f = Formation(side: .player)
        for (id, slot) in placements { try! f.place(.fixture(id), at: slot) }
        return f
    }
}

extension CombatantID {
    static func player(_ slot: Slot) -> CombatantID { CombatantID(side: .player, slot: slot) }
    static func enemy(_ slot: Slot) -> CombatantID { CombatantID(side: .enemy, slot: slot) }
}

extension Combatant {
    static func test(side: Side, slot: Slot, hp: Int = 100, maxHP: Int = 100, alive: Bool = true) -> Combatant {
        var stats = StageData.dummy.stats
        stats.maxHP = maxHP
        var c = Combatant(id: CombatantID(side: side, slot: slot), unitID: "\(side)-\(slot.column)\(slot.row)",
                          stats: stats, ability: StageData.dummy.ability)
        c.hp = hp
        c.isAlive = alive
        return c
    }
}
