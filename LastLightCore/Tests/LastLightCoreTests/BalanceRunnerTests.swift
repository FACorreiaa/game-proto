import Testing
@testable import LastLightCore

// Enemy tuned (4 drones, hp 95, atk 10) so a random team of 4 from `plain` wins ~45% (seed 7, 400 trials).
private func enemy() -> Formation {
    var f = Formation(side: .enemy)
    for slot in [Slot.front0, .front1, .front2, .back1] {
        try! f.place(UnitInstance(definition: .dummy(id: "drone", hp: 95, attack: 10, chargeMax: noCharge), stage: .one),
                     at: slot)
    }
    return f
}

/// Mixed strengths so team quality varies from trial to trial.
private let plain = [7, 8, 9, 10, 11, 12, 13].enumerated().map {
    UnitDefinition.dummy(id: "d\($0.offset)", attack: $0.element, chargeMax: noCharge)
}
private let titan = UnitDefinition.dummy(id: "titan", attack: 60, chargeMax: noCharge)

private func report(_ pool: [UnitDefinition], trials: Int = 2000, seed: UInt64 = 7) -> BalanceReport {
    BalanceRunner.run(pool: pool, bonds: [], bondLevel: 1, stage: .one, enemy: enemy(),
                      teamSize: 4, trials: trials, seed: seed)
}

@Test func averageTeamIsContested() {
    let r = report(plain, trials: 400)
    #expect(r.overallWinRate > 0.3 && r.overallWinRate < 0.7)
}

@Test func flagsOverpoweredUnit() {
    #expect(report(plain + [titan]).dominantUnits(margin: 0.15) == ["titan"])
}

@Test func sameSeedSameReport() {
    #expect(report(plain + [titan], trials: 300).unitWinRates == report(plain + [titan], trials: 300).unitWinRates)
}

@Test func balancedPoolFlagsNothing() {
    let identical = (0..<8).map { UnitDefinition.dummy(id: "same\($0)", attack: 10, chargeMax: noCharge) }
    let r = report(identical)
    #expect(r.dominantUnits(margin: 0.15) == [])
}

@Test func bondWinRateTracksActiveBonds() {
    let bond = try! Bond(id: "pair", partners: ("d0", "d1"), levels: [BondEffect(attackPercent: 100),
                                                                       BondEffect(attackPercent: 100),
                                                                       BondEffect(attackPercent: 100)])
    let r = BalanceRunner.run(pool: plain, bonds: [bond], bondLevel: 1, stage: .one, enemy: enemy(),
                              teamSize: 4, trials: 1000, seed: 3)
    #expect((r.bondWinRates["pair"] ?? 0) > r.overallWinRate)
}
