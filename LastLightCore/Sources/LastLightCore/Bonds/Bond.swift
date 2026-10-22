public typealias BondID = String

public struct BondEffect: Sendable, Equatable {
    public var attackPercent: Int
    public var maxHPPercent: Int
    public var chargePerAttackBonus: Int

    public init(attackPercent: Int = 0, maxHPPercent: Int = 0, chargePerAttackBonus: Int = 0) {
        self.attackPercent = attackPercent
        self.maxHPPercent = maxHPPercent
        self.chargePerAttackBonus = chargePerAttackBonus
    }
}

public enum BondError: Error, Equatable {
    case wrongLevelCount(Int)
    case samePartner
}

/// A relationship between two specific characters. Its effect applies only while they stand adjacent.
public struct Bond: Sendable {
    public static let levelCount = 3

    public let id: BondID
    public let partners: (UnitID, UnitID)
    /// Effect at levels 1...3, in order.
    public let levels: [BondEffect]

    public init(id: BondID, partners: (UnitID, UnitID), levels: [BondEffect]) throws(BondError) {
        guard levels.count == Bond.levelCount else { throw .wrongLevelCount(levels.count) }
        guard partners.0 != partners.1 else { throw .samePartner }
        self.id = id
        self.partners = partners
        self.levels = levels
    }
}
