import Testing
@testable import LastLightCore

@Test func requiresExactlyThreeStages() {
    #expect(throws: UnitDefinitionError.wrongStageCount(2)) {
        try UnitDefinition(id: "x", name: "X", region: .foundry, stages: [.dummy, .dummy])
    }
}

@Test func rejectsZeroAttackInterval() {
    var bad = StageData.dummy.stats
    bad.attackInterval = 0
    #expect(throws: UnitDefinitionError.invalidStats(stage: 1, reason: "attackInterval must be > 0")) {
        try UnitDefinition(id: "x", name: "X", region: .foundry,
                           stages: [StageData(stats: bad, ability: StageData.dummy.ability), .dummy, .dummy])
    }
}

@Test func rejectsZeroChargeMax() {
    var bad = StageData.dummy.stats
    bad.chargeMax = 0
    #expect(throws: UnitDefinitionError.invalidStats(stage: 2, reason: "chargeMax must be > 0")) {
        try UnitDefinition(id: "x", name: "X", region: .foundry,
                           stages: [.dummy, StageData(stats: bad, ability: StageData.dummy.ability), .dummy])
    }
}

@Test func rejectsZeroMaxHP() {
    var bad = StageData.dummy.stats
    bad.maxHP = 0
    #expect(throws: UnitDefinitionError.invalidStats(stage: 3, reason: "maxHP must be > 0")) {
        try UnitDefinition(id: "x", name: "X", region: .foundry,
                           stages: [.dummy, .dummy, StageData(stats: bad, ability: StageData.dummy.ability)])
    }
}

@Test func stageLookup() {
    let def = UnitDefinition.dummy(id: "x", hp: [100, 150, 220])
    #expect(def.data(for: .one).stats.maxHP == 100)
    #expect(def.data(for: .three).stats.maxHP == 220)
}
