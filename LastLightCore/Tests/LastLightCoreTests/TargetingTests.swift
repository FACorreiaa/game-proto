import Testing
@testable import LastLightCore

private func enemies(_ slots: [Slot], dead: [Slot] = []) -> [Combatant] {
    slots.map { .test(side: .enemy, slot: $0) } + dead.map { .test(side: .enemy, slot: $0, hp: 0, alive: false) }
}

@Test func combatantIDOrderingPlayerFirstThenSlot() {
    #expect([CombatantID.enemy(.front0), .player(.back0), .player(.front2)].sorted()
            == [.player(.front2), .player(.back0), .enemy(.front0)])
}

@Test func basicPrefersFrontNearestRowTieLower() {
    let actor = Combatant.test(side: .player, slot: .front1)
    let t = Targeting.targets(for: .basicTarget, actor: actor, allies: [actor],
                              enemies: enemies([.front0, .front2, .back1]))
    #expect(t == [.enemy(.front0)])
}

@Test func basicFallsBackToBackColumn() {
    let actor = Combatant.test(side: .player, slot: .back2)
    let t = Targeting.targets(for: .basicTarget, actor: actor, allies: [actor],
                              enemies: enemies([.back0, .back2], dead: [.front0]))
    #expect(t == [.enemy(.back2)])
}

@Test func backlineFirstIgnoresFront() {
    let actor = Combatant.test(side: .player, slot: .front0)
    let t = Targeting.targets(for: .backlineFirst, actor: actor, allies: [actor], enemies: enemies([.front0, .back1]))
    #expect(t == [.enemy(.back1)])
}

@Test func frontColumnHitsAllInColumn() {
    let actor = Combatant.test(side: .player, slot: .front0)
    let t = Targeting.targets(for: .enemyFrontColumn, actor: actor, allies: [actor],
                              enemies: enemies([.back0, .front1, .front0]))
    #expect(t == [.enemy(.front0), .enemy(.front1)])
}

@Test func allEnemiesSkipsDead() {
    let actor = Combatant.test(side: .player, slot: .front0)
    let t = Targeting.targets(for: .allEnemies, actor: actor, allies: [actor],
                              enemies: enemies([.back2, .front1], dead: [.front0]))
    #expect(t == [.enemy(.front1), .enemy(.back2)])
}

@Test func lowestHPAllyIncludesSelf() {
    let actor = Combatant.test(side: .player, slot: .front0, hp: 30)
    let ally = Combatant.test(side: .player, slot: .front1, hp: 50)
    let t = Targeting.targets(for: .lowestHPAlly, actor: actor, allies: [ally, actor], enemies: enemies([.front0]))
    #expect(t == [.player(.front0)])
}

@Test func lowestHPAllyUsesRatioNotRawHP() {
    let actor = Combatant.test(side: .player, slot: .front0, hp: 40, maxHP: 50)    // 80%
    let tank = Combatant.test(side: .player, slot: .front1, hp: 100, maxHP: 200)   // 50%
    let t = Targeting.targets(for: .lowestHPAlly, actor: actor, allies: [actor, tank], enemies: [])
    #expect(t == [.player(.front1)])
}

@Test func selfOnlyIsActor() {
    let actor = Combatant.test(side: .enemy, slot: .back1)
    #expect(Targeting.targets(for: .selfOnly, actor: actor, allies: [actor], enemies: []) == [.enemy(.back1)])
}

@Test func noLivingEnemiesGivesEmpty() {
    let actor = Combatant.test(side: .player, slot: .front0)
    #expect(Targeting.targets(for: .basicTarget, actor: actor, allies: [actor], enemies: enemies([], dead: [.front0])) == [])
}
