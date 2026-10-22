import LastLightCore

/// Placeholder units until the real cast sheet lands (Chapter 1 content plan). Stats are illustrative only.
enum SamplePool {
    static func unit(_ id: String, _ region: Region, hp: Int, attack: Int, armor: Int = 0, interval: Int = 30,
                     ability: Ability) -> UnitDefinition {
        let stages = [1.0, 1.4, 1.9].map { scale in
            StageData(stats: UnitStats(maxHP: Int(Double(hp) * scale), attack: Int(Double(attack) * scale), armor: armor,
                                       attackInterval: interval, chargeMax: 60, chargePerAttack: 10, chargePerHitTaken: 5),
                      ability: ability)
        }
        return try! UnitDefinition(id: id, name: id, region: region, stages: stages)
    }

    static let units: [UnitDefinition] = [
        unit("defector", .foundry, hp: 140, attack: 9, armor: 3,
             ability: Ability(id: "overclock", target: .enemyFrontColumn, effect: .damage(multiplier: 1.5))),
        unit("creator", .foundry, hp: 80, attack: 8,
             ability: Ability(id: "patch", target: .lowestHPAlly, effect: .heal(amount: 40))),
        unit("welder", .foundry, hp: 110, attack: 11, interval: 25,
             ability: Ability(id: "arc", target: .basicTarget, effect: .damage(multiplier: 2.5))),
        unit("priestess", .dawnfaith, hp: 90, attack: 7,
             ability: Ability(id: "dawnward", target: .lowestHPAlly, effect: .shield(amount: 50))),
        unit("zealot", .dawnfaith, hp: 160, attack: 8, armor: 4,
             ability: Ability(id: "vow", target: .selfOnly, effect: .shield(amount: 60))),
        unit("sunblade", .dawnfaith, hp: 100, attack: 13,
             ability: Ability(id: "flare", target: .allEnemies, effect: .damage(multiplier: 0.8))),
        unit("smuggler", .lanternCities, hp: 85, attack: 12, interval: 22,
             ability: Ability(id: "backstab", target: .backlineFirst, effect: .damage(multiplier: 3))),
        unit("lamplighter", .lanternCities, hp: 95, attack: 10,
             ability: Ability(id: "lantern", target: .allEnemies, effect: .damage(multiplier: 0.7))),
    ]

    static let bonds: [Bond] = [
        try! Bond(id: "maker-and-made", partners: ("defector", "creator"),
                  levels: [BondEffect(attackPercent: 15, maxHPPercent: 15), BondEffect(attackPercent: 25, maxHPPercent: 25),
                           BondEffect(attackPercent: 40, maxHPPercent: 40)]),
        try! Bond(id: "faith-and-steel", partners: ("priestess", "welder"),
                  levels: [BondEffect(chargePerAttackBonus: 3), BondEffect(chargePerAttackBonus: 5),
                           BondEffect(chargePerAttackBonus: 8)]),
    ]

    static var enemy: Formation {
        var f = Formation(side: .enemy)
        let drone = unit("drone", .machine, hp: 110, attack: 9,
                         ability: Ability(id: "burst", target: .basicTarget, effect: .damage(multiplier: 2)))
        let sentinel = unit("sentinel", .machine, hp: 200, attack: 7, armor: 4,
                            ability: Ability(id: "bulwark", target: .selfOnly, effect: .shield(amount: 50)))
        try! f.place(UnitInstance(definition: sentinel, stage: .one), at: Slot(column: .front, row: 1)!)
        for row in [0, 2] { try! f.place(UnitInstance(definition: drone, stage: .one), at: Slot(column: .front, row: row)!) }
        for row in [0, 2] { try! f.place(UnitInstance(definition: drone, stage: .one), at: Slot(column: .back, row: row)!) }
        return f
    }
}
