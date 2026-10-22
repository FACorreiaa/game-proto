import Testing
@testable import LastLightCore

private func effect(_ attack: Int, hp: Int = 0) -> [BondEffect] {
    [BondEffect(attackPercent: attack, maxHPPercent: hp), BondEffect(attackPercent: attack, maxHPPercent: hp),
     BondEffect(attackPercent: attack, maxHPPercent: hp)]
}

private let trust = try! Bond(id: "trust", partners: ("kai", "vex"), levels: [
    BondEffect(attackPercent: 20), BondEffect(attackPercent: 35), BondEffect(attackPercent: 50),
])

private func battle(_ placements: [(UnitDefinition, Slot, Stage)], bonds: [Bond], levels: [BondID: Int]) -> BattleResult {
    var p = Formation(side: .player), e = Formation(side: .enemy)
    for (def, slot, stage) in placements { try! p.place(UnitInstance(definition: def, stage: stage), at: slot) }
    try! e.place(UnitInstance(definition: .dummy(id: "bag", hp: 1000, attack: 1, interval: 10_000, chargeMax: noCharge),
                              stage: .one), at: .front0)
    return BattleSimulator.run(BattleSetup(player: p, enemy: e, bonds: bonds, bondLevels: levels))
}

private func firstAttackDamage(_ r: BattleResult, from source: CombatantID) -> Int? {
    for event in r.events {
        if case let .attack(_, s, _, damage, _) = event, s == source { return damage }
    }
    return nil
}

private let kai = UnitDefinition.dummy(id: "kai", attack: 10, chargeMax: noCharge)
private let vex = UnitDefinition.dummy(id: "vex", attack: 10, chargeMax: noCharge)

@Test func adjacentBondBuffsAttack() {
    let r = battle([(kai, .front0, .one), (vex, .front1, .one)], bonds: [trust], levels: ["trust": 3])
    #expect(firstAttackDamage(r, from: .player(.front0)) == 15)
}

@Test func diagonalBondDoesNothing() {
    let r = battle([(kai, .front0, .one), (vex, .back1, .one)], bonds: [trust], levels: ["trust": 3])
    #expect(firstAttackDamage(r, from: .player(.front0)) == 10)
    #expect(!r.events.contains { if case .bondActivated = $0 { true } else { false } })
}

@Test func bondEventComesFirst() {
    let r = battle([(kai, .front0, .one), (vex, .front1, .one)], bonds: [trust], levels: ["trust": 1])
    #expect(r.events.first == .bondActivated(tick: 0, bondID: "trust", members: [.player(.front0), .player(.front1)]))
}

@Test func bondRaisesMaxHPAndStartingHP() {
    let tough = try! Bond(id: "tough", partners: ("kai", "vex"), levels: effect(0, hp: 50))
    let r = battle([(kai, .front0, .one), (vex, .front1, .one)], bonds: [tough], levels: ["tough": 1])
    #expect(r.finalHP[.player(.front1)] == 150)
}

@Test func stageThreeUsesStageThreeStats() {
    let evolved = UnitDefinition.dummy(id: "evo", hp: [100, 150, 220], chargeMax: noCharge)
    let r = battle([(evolved, .front0, .three)], bonds: [], levels: [:])
    #expect(r.finalHP[.player(.front0)] == 220)
}

@Test func stackedBondsAdd() {
    let lia = UnitDefinition.dummy(id: "lia", attack: 10, chargeMax: noCharge)
    let a = try! Bond(id: "a", partners: ("kai", "vex"), levels: effect(20))
    let b = try! Bond(id: "b", partners: ("lia", "kai"), levels: effect(20))
    let r = battle([(kai, .front1, .one), (vex, .front0, .one), (lia, .front2, .one)], bonds: [a, b],
                   levels: ["a": 1, "b": 1])
    #expect(firstAttackDamage(r, from: .player(.front1)) == 14)
}
