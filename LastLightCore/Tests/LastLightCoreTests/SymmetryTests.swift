import Testing
@testable import LastLightCore

// In a mirror match (identical units in identical slots on both sides) a fair simulation can only draw or time out.

private let mirrorPool: [UnitDefinition] = [
    .dummy(id: "striker", hp: 90, attack: 12, chargeMax: 30, chargePerAttack: 10, chargePerHitTaken: 5,
           ability: Ability(id: "burst", target: .basicTarget, effect: .damage(multiplier: 2.5))),
    .dummy(id: "shielder", hp: 120, attack: 7, interval: 27, chargeMax: 20, chargePerAttack: 10, chargePerHitTaken: 5,
           ability: Ability(id: "ward", target: .lowestHPAlly, effect: .shield(amount: 25))),
    .dummy(id: "healer", hp: 80, attack: 6, interval: 33, chargeMax: 20, chargePerAttack: 10, chargePerHitTaken: 5,
           ability: Ability(id: "mend", target: .lowestHPAlly, effect: .heal(amount: 30))),
    .dummy(id: "sweeper", hp: 100, attack: 9, interval: 31, chargeMax: 40, chargePerAttack: 10, chargePerHitTaken: 5,
           ability: Ability(id: "wave", target: .allEnemies, effect: .damage(multiplier: 0.8))),
    .dummy(id: "tank", hp: 200, attack: 5, armor: 3, chargeMax: 30, chargePerAttack: 10, chargePerHitTaken: 10,
           ability: Ability(id: "brace", target: .selfOnly, effect: .shield(amount: 40))),
]

private func mirror(_ placements: [(UnitDefinition, Slot)]) -> BattleSetup {
    var p = Formation(side: .player), e = Formation(side: .enemy)
    for (def, slot) in placements {
        try! p.place(UnitInstance(definition: def, stage: .one), at: slot)
        try! e.place(UnitInstance(definition: def, stage: .one), at: slot)
    }
    return BattleSetup(player: p, enemy: e)
}

@Test func randomMirrorsNeverPickASide() {
    var rng = SeededRandom(seed: 11)
    var decided: [BattleOutcome] = []
    for _ in 0..<200 {
        let size = Int.random(in: 1...5, using: &rng)
        let units = mirrorPool.shuffled(using: &rng).prefix(size)
        let slots = Slot.all.shuffled(using: &rng)
        let outcome = BattleSimulator.run(mirror(Array(zip(units, slots)))).outcome
        if outcome == .playerWon || outcome == .enemyWon { decided.append(outcome) }
    }
    #expect(decided.isEmpty)
}

@Test func shielderMirrorIsEven() {
    let r = BattleSimulator.run(mirror([(mirrorPool[1], .front0), (mirrorPool[0], .back0)]))
    #expect(r.outcome == .draw || r.outcome == .timedOut)
}

@Test func healerMirrorIsEven() {
    let r = BattleSimulator.run(mirror([(mirrorPool[2], .back1), (mirrorPool[0], .front1)]))
    #expect(r.outcome == .draw || r.outcome == .timedOut)
}

@Test func castCountsMatchInMirror() {
    let r = BattleSimulator.run(mirror([(mirrorPool[0], .front0)]))
    let casts = r.events.compactMap { if case let .abilityCast(_, source, _, _) = $0 { source.side } else { nil } }
    #expect(casts.filter { $0 == .player }.count == casts.filter { $0 == .enemy }.count)
}

@Test func sameTickHealLandsAfterDamage() {
    // Healer's own ally takes a lethal 10 and a 20 heal on the same tick: heals resolve after damage, so it survives.
    let ally = UnitDefinition.dummy(id: "ally", hp: 10, attack: 1, interval: 10_000, chargeMax: noCharge)
    let healer = UnitDefinition.dummy(id: "healer", hp: 1000, attack: 1, chargeMax: 10, chargePerAttack: 10,
                                      ability: Ability(id: "mend", target: .lowestHPAlly, effect: .heal(amount: 20)))
    let enemy = UnitDefinition.dummy(id: "e", hp: 1000, attack: 10, interval: 60, chargeMax: noCharge)
    var p = Formation(side: .player), e = Formation(side: .enemy)
    try! p.place(UnitInstance(definition: ally, stage: .one), at: .front0)
    try! p.place(UnitInstance(definition: healer, stage: .one), at: .back0)
    try! e.place(UnitInstance(definition: enemy, stage: .one), at: .front0)
    let r = BattleSimulator.run(BattleSetup(player: p, enemy: e))
    // Tick 60: enemy hits ally for 10 (→ 0) while the healer casts; heal lands after damage → 10 back, alive.
    #expect(!r.events.contains(.death(tick: 60, unit: .player(.front0))))
}
