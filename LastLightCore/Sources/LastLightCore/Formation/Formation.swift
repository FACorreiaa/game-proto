public enum Side: Sendable, Hashable {
    case player, enemy

    /// Maximum units this side may field.
    public var cap: Int {
        switch self {
        case .player: 5
        case .enemy: 6
        }
    }
}

public enum FormationError: Error, Equatable {
    case slotOccupied(Slot)
    case full(cap: Int)
    /// The player's cast is unique: a character can only stand in one slot.
    case duplicateCharacter(UnitID)
}

public struct Formation: Sendable {
    public let side: Side
    public private(set) var units: [Slot: UnitInstance] = [:]

    public init(side: Side) {
        self.side = side
    }

    public mutating func place(_ unit: UnitInstance, at slot: Slot) throws(FormationError) {
        if units[slot] != nil { throw .slotOccupied(slot) }
        if units.count >= side.cap { throw .full(cap: side.cap) }
        if side == .player, units.values.contains(where: { $0.id == unit.id }) {
            throw .duplicateCharacter(unit.id)
        }
        units[slot] = unit
    }
}
