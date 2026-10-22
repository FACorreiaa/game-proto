public struct BalanceReport: Sendable {
    public let trials: Int
    public let overallWinRate: Double
    /// Win rate of the trials each unit took part in.
    public let unitWinRates: [UnitID: Double]
    /// Win rate of the trials in which each bond was active.
    public let bondWinRates: [BondID: Double]

    /// Units whose win rate beats the overall rate by more than `margin`, most dominant first.
    public func dominantUnits(margin: Double) -> [UnitID] {
        unitWinRates
            .filter { $0.value - overallWinRate > margin }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map(\.key)
    }
}

/// Plays many random team compositions against one enemy to catch builds that dominate (spec §2 anti-goal).
public enum BalanceRunner {
    public static func run(pool: [UnitDefinition], bonds: [Bond], bondLevel: Int, stage: Stage, enemy: Formation,
                           teamSize: Int, trials: Int, seed: UInt64) -> BalanceReport {
        precondition(teamSize <= min(pool.count, Side.player.cap), "team larger than pool or formation cap")
        var rng = SeededRandom(seed: seed)
        let levels = Dictionary(uniqueKeysWithValues: bonds.map { ($0.id, bondLevel) })
        var wins = 0
        var unitTally: [UnitID: (wins: Int, games: Int)] = [:]
        var bondTally: [BondID: (wins: Int, games: Int)] = [:]

        for _ in 0..<trials {
            let team = pool.shuffled(using: &rng).prefix(teamSize)
            let slots = Slot.all.shuffled(using: &rng)
            var formation = Formation(side: .player)
            for (unit, slot) in zip(team, slots) {
                try! formation.place(UnitInstance(definition: unit, stage: stage), at: slot)
            }
            let setup = BattleSetup(player: formation, enemy: enemy, bonds: bonds, bondLevels: levels)
            let won = BattleSimulator.run(setup).outcome == .playerWon ? 1 : 0
            wins += won
            for unit in team { unitTally[unit.id, default: (0, 0)].wins += won; unitTally[unit.id]!.games += 1 }
            for bond in BondResolver.active(bonds: bonds, levels: levels, in: formation) {
                bondTally[bond.bondID, default: (0, 0)].wins += won
                bondTally[bond.bondID]!.games += 1
            }
        }

        func rate(_ t: (wins: Int, games: Int)) -> Double { Double(t.wins) / Double(t.games) }
        return BalanceReport(trials: trials,
                             overallWinRate: trials == 0 ? 0 : Double(wins) / Double(trials),
                             unitWinRates: unitTally.mapValues(rate),
                             bondWinRates: bondTally.mapValues(rate))
    }
}
