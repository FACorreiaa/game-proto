public struct ActiveBond: Sendable, Equatable {
    public let bondID: BondID
    public let level: Int
    /// The two partners' slots, sorted.
    public let slots: [Slot]
    public let effect: BondEffect

    public init(bondID: BondID, level: Int, slots: [Slot], effect: BondEffect) {
        self.bondID = bondID
        self.level = level
        self.slots = slots
        self.effect = effect
    }
}

public enum BondResolver {
    /// Bonds that are unlocked (level 1...3), with both partners present and adjacent. Sorted by bond id.
    public static func active(bonds: [Bond], levels: [BondID: Int], in formation: Formation) -> [ActiveBond] {
        var slotByUnit: [UnitID: Slot] = [:]
        for (slot, unit) in formation.units { slotByUnit[unit.id] = slot }

        return bonds.compactMap { bond -> ActiveBond? in
            guard let level = levels[bond.id], (1...Bond.levelCount).contains(level),
                  let a = slotByUnit[bond.partners.0], let b = slotByUnit[bond.partners.1],
                  a.isAdjacent(to: b)
            else { return nil }
            return ActiveBond(bondID: bond.id, level: level, slots: [a, b].sorted(), effect: bond.levels[level - 1])
        }
        .sorted { $0.bondID < $1.bondID }
    }
}
