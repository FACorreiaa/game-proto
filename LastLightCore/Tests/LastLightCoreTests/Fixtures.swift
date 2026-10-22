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
