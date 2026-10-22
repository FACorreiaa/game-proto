import Testing
@testable import LastLightCore

@Test func simpleWinTimeline() {
    // P: hp 100 atk 10 interval 30 | E: hp 25 atk 1 interval 30, both armor 0
    let r = BattleSimulator.run(.oneVsOne(player: .dummy(id: "p", hp: 100, attack: 10, chargeMax: noCharge),
                                          enemy: .dummy(id: "e", hp: 25, attack: 1, chargeMax: noCharge)))
    #expect(r.outcome == .playerWon)
    #expect(r.durationTicks == 90)
    #expect(r.events.contains(.death(tick: 90, unit: .enemy(.front0))))
    #expect(r.finalHP[.player(.front0)] == 97) // enemy also hit on ticks 30, 60, 90
}

@Test func armorFloorsDamageAtOne() {
    let r = BattleSimulator.run(.oneVsOne(player: .dummy(id: "p", attack: 10, chargeMax: noCharge),
                                          enemy: .dummy(id: "e", hp: 5, attack: 1, armor: 15, chargeMax: noCharge)))
    let playerHits = r.events.compactMap { event -> Int? in
        if case let .attack(_, source, _, damage, _) = event, source == .player(.front0) { return damage }
        return nil
    }
    #expect(!playerHits.isEmpty)
    #expect(playerHits.allSatisfy { $0 == 1 })
}

@Test func simultaneousKillIsDraw() {
    let r = BattleSimulator.run(.oneVsOne(player: .dummy(id: "p", hp: 10, attack: 10, chargeMax: noCharge),
                                          enemy: .dummy(id: "e", hp: 10, attack: 10, chargeMax: noCharge)))
    #expect(r.outcome == .draw)
    #expect(r.durationTicks == 30)
    let deaths = r.events.filter { if case .death(tick: 30, _) = $0 { true } else { false } }
    #expect(deaths == [.death(tick: 30, unit: .player(.front0)), .death(tick: 30, unit: .enemy(.front0))])
}

@Test func stalemateTimesOut() {
    let r = BattleSimulator.run(.oneVsOne(player: .dummy(id: "p", hp: 1000, attack: 1, armor: 5, chargeMax: noCharge),
                                          enemy: .dummy(id: "e", hp: 1000, attack: 1, armor: 5, chargeMax: noCharge)))
    #expect(r.outcome == .timedOut)
    #expect(r.durationTicks == 2700)
}

@Test func emptyEnemyIsInstantWin() {
    let r = BattleSimulator.run(BattleSetup(player: .player([("p", .front0)]), enemy: Formation(side: .enemy)))
    #expect(r.outcome == .playerWon)
    #expect(r.durationTicks == 0)
    #expect(r.events == [.ended(tick: 0, outcome: .playerWon)])
}

@Test func emptyPlayerIsInstantLoss() {
    var enemy = Formation(side: .enemy)
    try! enemy.place(.fixture("e"), at: .front0)
    let r = BattleSimulator.run(BattleSetup(player: Formation(side: .player), enemy: enemy))
    #expect(r.outcome == .enemyWon)
    #expect(r.durationTicks == 0)
}

@Test func bothEmptyIsDraw() {
    let r = BattleSimulator.run(BattleSetup(player: Formation(side: .player), enemy: Formation(side: .enemy)))
    #expect(r.outcome == .draw)
    #expect(r.durationTicks == 0)
}

private func fiveVsSix() -> BattleSetup {
    var p = Formation(side: .player), e = Formation(side: .enemy)
    for (i, slot) in Slot.all.prefix(5).enumerated() {
        try! p.place(UnitInstance(definition: .dummy(id: "p\(i)", hp: 80 + i * 10, attack: 8 + i), stage: .one), at: slot)
    }
    for (i, slot) in Slot.all.enumerated() {
        try! e.place(UnitInstance(definition: .dummy(id: "drone", hp: 70, attack: 9, interval: 25 + i), stage: .one), at: slot)
    }
    return BattleSetup(player: p, enemy: e)
}

@Test func deterministic() {
    #expect(BattleSimulator.run(fiveVsSix()) == BattleSimulator.run(fiveVsSix()))
}

@Test func endedIsLastEvent() {
    let r = BattleSimulator.run(fiveVsSix())
    #expect(r.events.last == .ended(tick: r.durationTicks, outcome: r.outcome))
}
