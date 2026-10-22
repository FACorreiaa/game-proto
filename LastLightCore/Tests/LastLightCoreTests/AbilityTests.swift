import Testing
@testable import LastLightCore

private func setup(player: [(UnitDefinition, Slot)], enemy: UnitDefinition) -> BattleSetup {
    var p = Formation(side: .player), e = Formation(side: .enemy)
    for (def, slot) in player { try! p.place(UnitInstance(definition: def, stage: .one), at: slot) }
    try! e.place(UnitInstance(definition: enemy, stage: .one), at: .front0)
    return BattleSetup(player: p, enemy: e)
}

private let punchingBag = UnitDefinition.dummy(id: "bag", hp: 1000, attack: 1, interval: 10_000, chargeMax: noCharge)

@Test func castsWhenChargeFull() {
    let striker = UnitDefinition.dummy(id: "p", attack: 10, chargeMax: 20, chargePerAttack: 10,
                                       ability: Ability(id: "triple", target: .basicTarget, effect: .damage(multiplier: 3)))
    let r = BattleSimulator.run(setup(player: [(striker, .front0)], enemy: punchingBag))
    let early = r.events.filter {
        switch $0 {
        case let .attack(tick, _, _, _, _), let .abilityCast(tick, _, _, _), let .damage(tick, _, _, _, _, _): tick <= 90
        default: false
        }
    }
    #expect(early == [
        .attack(tick: 30, source: .player(.front0), target: .enemy(.front0), damage: 10, hpAfter: 990),
        .attack(tick: 60, source: .player(.front0), target: .enemy(.front0), damage: 10, hpAfter: 980),
        .abilityCast(tick: 90, source: .player(.front0), abilityID: "triple", targets: [.enemy(.front0)]),
        .damage(tick: 90, source: .player(.front0), target: .enemy(.front0), amount: 30, absorbed: 0, hpAfter: 950),
    ])
}

@Test func healCapsAtMax() {
    let ally = UnitDefinition.dummy(id: "ally", attack: 1, chargeMax: noCharge)
    let healer = UnitDefinition.dummy(id: "healer", attack: 1, chargeMax: 10, chargePerAttack: 10,
                                      ability: Ability(id: "mend", target: .lowestHPAlly, effect: .heal(amount: 20)))
    let enemy = UnitDefinition.dummy(id: "e", hp: 1000, attack: 5, chargeMax: noCharge)
    let r = BattleSimulator.run(setup(player: [(ally, .front0), (healer, .back0)], enemy: enemy))
    // Enemy hits ally to 95 at tick 30; healer casts at 60 before the enemy's tick-60 hit (player acts first).
    #expect(r.events.contains(.heal(tick: 60, source: .player(.back0), target: .player(.front0), amount: 5, hpAfter: 100)))
}

@Test func shieldAbsorbsFirst() {
    let guardian = UnitDefinition.dummy(id: "g", hp: 200, attack: 1, chargeMax: 10, chargePerAttack: 10,
                                        ability: Ability(id: "aegis", target: .selfOnly, effect: .shield(amount: 15)))
    let enemy = UnitDefinition.dummy(id: "e", hp: 1000, attack: 10, chargeMax: noCharge)
    let r = BattleSimulator.run(setup(player: [(guardian, .front0)], enemy: enemy))
    let enemyHits = r.events.compactMap { event -> (Int, Int)? in
        if case let .attack(tick, source, _, _, hpAfter) = event, source == .enemy(.front0), tick <= 90 { return (tick, hpAfter) }
        return nil
    }
    #expect(r.events.contains(.shield(tick: 60, source: .player(.front0), target: .player(.front0), amount: 15)))
    #expect(enemyHits.map(\.0) == [30, 60, 90])
    #expect(enemyHits.map(\.1) == [190, 190, 185]) // tick 60 fully absorbed (shield 15→5); tick 90 absorbs 5
}

@Test func hitsTakenBuildCharge() {
    let attacker = UnitDefinition.dummy(id: "p", hp: 1000, attack: 1, chargeMax: noCharge)
    let enemy = UnitDefinition.dummy(id: "e", hp: 1000, attack: 1, chargeMax: 50, chargePerAttack: 0, chargePerHitTaken: 25,
                                     ability: Ability(id: "brace", target: .selfOnly, effect: .shield(amount: 1)))
    let r = BattleSimulator.run(setup(player: [(attacker, .front0)], enemy: enemy))
    let casts = r.events.compactMap { event -> Int? in
        if case let .abilityCast(tick, source, _, _) = event, source == .enemy(.front0) { return tick }
        return nil
    }
    // Hit at 30 and 60 → charge 50 after tick 60; the tick-start state decides, so the cast lands at 90.
    #expect(casts.first == 90)
}

@Test func castGivesNoCharge() {
    let striker = UnitDefinition.dummy(id: "p", attack: 10, chargeMax: 10, chargePerAttack: 10,
                                       ability: Ability(id: "jab", target: .basicTarget, effect: .damage(multiplier: 1)))
    let r = BattleSimulator.run(setup(player: [(striker, .front0)], enemy: punchingBag))
    let actions = r.events.compactMap { event -> String? in
        switch event {
        case let .attack(tick, _, _, _, _) where tick <= 120: "A"
        case let .abilityCast(tick, _, _, _) where tick <= 120: "C"
        default: nil
        }
    }
    #expect(actions == ["A", "C", "A", "C"]) // a cast resets charge to 0 and adds nothing
}
