import Testing
@testable import LastLightCore

private let trust = try! Bond(id: "trust", partners: ("kai", "vex"), levels: [
    BondEffect(attackPercent: 20), BondEffect(attackPercent: 35), BondEffect(attackPercent: 50),
])
private let oath = try! Bond(id: "oath", partners: ("lia", "kai"), levels: [
    BondEffect(attackPercent: 20), BondEffect(attackPercent: 20), BondEffect(attackPercent: 20),
])

@Test func bondRequiresThreeLevels() {
    #expect(throws: BondError.wrongLevelCount(1)) {
        try Bond(id: "b", partners: ("a", "b"), levels: [BondEffect()])
    }
}

@Test func bondRejectsSamePartnerTwice() {
    #expect(throws: BondError.samePartner) {
        try Bond(id: "b", partners: ("a", "a"), levels: [BondEffect(), BondEffect(), BondEffect()])
    }
}

@Test func activeWhenAdjacentSameColumn() {
    let active = BondResolver.active(bonds: [trust], levels: ["trust": 1],
                                     in: .player([("kai", .front0), ("vex", .front1)]))
    #expect(active == [ActiveBond(bondID: "trust", level: 1, slots: [.front0, .front1],
                                  effect: BondEffect(attackPercent: 20))])
}

@Test func activeWhenAdjacentSameRow() {
    let active = BondResolver.active(bonds: [trust], levels: ["trust": 1],
                                     in: .player([("kai", .front0), ("vex", .back0)]))
    #expect(active.map(\.bondID) == ["trust"])
    #expect(active.first?.slots == [.front0, .back0])
}

@Test func inactiveWhenDiagonal() {
    let active = BondResolver.active(bonds: [trust], levels: ["trust": 1],
                                     in: .player([("kai", .front0), ("vex", .back1)]))
    #expect(active.isEmpty)
}

@Test func inactiveWhenPartnerMissing() {
    let active = BondResolver.active(bonds: [trust], levels: ["trust": 1], in: .player([("kai", .front0)]))
    #expect(active.isEmpty)
}

@Test func inactiveWhenNotUnlocked() {
    let formation = Formation.player([("kai", .front0), ("vex", .front1)])
    #expect(BondResolver.active(bonds: [trust], levels: [:], in: formation).isEmpty)
    #expect(BondResolver.active(bonds: [trust], levels: ["trust": 0], in: formation).isEmpty)
    #expect(BondResolver.active(bonds: [trust], levels: ["trust": 4], in: formation).isEmpty)
}

@Test func levelSelectsEffect() {
    let active = BondResolver.active(bonds: [trust], levels: ["trust": 3],
                                     in: .player([("kai", .front0), ("vex", .front1)]))
    #expect(active.first?.level == 3)
    #expect(active.first?.effect.attackPercent == 50)
}

@Test func unitCanHoldTwoBonds() {
    let active = BondResolver.active(bonds: [trust, oath], levels: ["trust": 1, "oath": 1],
                                     in: .player([("kai", .front1), ("vex", .front0), ("lia", .front2)]))
    #expect(active.map(\.bondID) == ["oath", "trust"])
    #expect(active.map(\.slots) == [[.front1, .front2], [.front0, .front1]])
}
