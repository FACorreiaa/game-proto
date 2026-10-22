import Testing
@testable import LastLightCore

@Test func adjacency() {
    let f0 = Slot(column: .front, row: 0)!, f1 = Slot(column: .front, row: 1)!
    let b0 = Slot(column: .back, row: 0)!, b1 = Slot(column: .back, row: 1)!
    #expect(f0.isAdjacent(to: f1))      // same column, neighbouring rows
    #expect(f0.isAdjacent(to: b0))      // same row, other column
    #expect(!f0.isAdjacent(to: b1))     // diagonal
    #expect(!f0.isAdjacent(to: Slot(column: .front, row: 2)!))
    #expect(!f0.isAdjacent(to: f0))
}

@Test func slotRejectsOutOfRangeRow() {
    #expect(Slot(column: .front, row: 3) == nil)
    #expect(Slot(column: .back, row: -1) == nil)
}

@Test func slotOrderingIsColumnThenRow() {
    #expect(Slot.all.map { "\($0.column)\($0.row)" } == ["front0", "front1", "front2", "back0", "back1", "back2"])
}

@Test func playerCapIsFive() throws {
    var f = Formation(side: .player)
    for (i, slot) in Slot.all.prefix(5).enumerated() { try f.place(.fixture("u\(i)"), at: slot) }
    #expect(throws: FormationError.full(cap: 5)) { try f.place(.fixture("u5"), at: Slot.all[5]) }
}

@Test func playerRejectsDuplicateCharacter() throws {
    var f = Formation(side: .player)
    try f.place(.fixture("jin"), at: Slot.all[0])
    #expect(throws: FormationError.duplicateCharacter("jin")) { try f.place(.fixture("jin"), at: Slot.all[1]) }
}

@Test func enemyAllowsDuplicatesAndSix() throws {
    var f = Formation(side: .enemy)
    for slot in Slot.all { try f.place(.fixture("drone"), at: slot) }
    #expect(f.units.count == 6)
}

@Test func occupiedSlotRejected() throws {
    var f = Formation(side: .enemy)
    try f.place(.fixture("a"), at: Slot.all[0])
    #expect(throws: FormationError.slotOccupied(Slot.all[0])) { try f.place(.fixture("b"), at: Slot.all[0]) }
}
