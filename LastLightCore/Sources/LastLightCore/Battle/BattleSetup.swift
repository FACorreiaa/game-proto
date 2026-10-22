public struct BattleSetup: Sendable {
    public let player: Formation
    public let enemy: Formation
    public let bonds: [Bond]
    /// In-run bond levels (1...3). Bonds missing here are locked.
    public let bondLevels: [BondID: Int]

    public init(player: Formation, enemy: Formation, bonds: [Bond] = [], bondLevels: [BondID: Int] = [:]) {
        precondition(player.side == .player && enemy.side == .enemy, "formations passed on the wrong sides")
        self.player = player
        self.enemy = enemy
        self.bonds = bonds
        self.bondLevels = bondLevels
    }
}
