public typealias UnitID = String

public enum Region: String, Sendable, CaseIterable {
    case foundry, dawnfaith, lanternCities, machine
}

public enum Stage: Int, Sendable, CaseIterable, Comparable {
    case one = 1, two, three

    public static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct UnitStats: Sendable, Equatable {
    public var maxHP: Int
    public var attack: Int
    public var armor: Int
    /// Ticks between actions; must be > 0.
    public var attackInterval: Int
    /// Charge needed to cast the signature ability; must be > 0.
    public var chargeMax: Int
    public var chargePerAttack: Int
    public var chargePerHitTaken: Int

    public init(maxHP: Int, attack: Int, armor: Int, attackInterval: Int,
                chargeMax: Int, chargePerAttack: Int, chargePerHitTaken: Int) {
        self.maxHP = maxHP
        self.attack = attack
        self.armor = armor
        self.attackInterval = attackInterval
        self.chargeMax = chargeMax
        self.chargePerAttack = chargePerAttack
        self.chargePerHitTaken = chargePerHitTaken
    }
}

public struct StageData: Sendable, Equatable {
    public let stats: UnitStats
    public let ability: Ability

    public init(stats: UnitStats, ability: Ability) {
        self.stats = stats
        self.ability = ability
    }
}

public enum UnitDefinitionError: Error, Equatable {
    case wrongStageCount(Int)
    case invalidStats(stage: Int, reason: String)
}

public struct UnitDefinition: Sendable {
    public let id: UnitID
    public let name: String
    public let region: Region
    private let stages: [StageData]

    public init(id: UnitID, name: String, region: Region, stages: [StageData]) throws(UnitDefinitionError) {
        guard stages.count == Stage.allCases.count else { throw .wrongStageCount(stages.count) }
        for (index, data) in stages.enumerated() {
            let stage = index + 1
            if data.stats.maxHP <= 0 { throw .invalidStats(stage: stage, reason: "maxHP must be > 0") }
            if data.stats.attackInterval <= 0 { throw .invalidStats(stage: stage, reason: "attackInterval must be > 0") }
            if data.stats.chargeMax <= 0 { throw .invalidStats(stage: stage, reason: "chargeMax must be > 0") }
        }
        self.id = id
        self.name = name
        self.region = region
        self.stages = stages
    }

    public func data(for stage: Stage) -> StageData {
        stages[stage.rawValue - 1]
    }
}

public struct UnitInstance: Sendable {
    public let definition: UnitDefinition
    public let stage: Stage
    public var id: UnitID { definition.id }

    public init(definition: UnitDefinition, stage: Stage) {
        self.definition = definition
        self.stage = stage
    }
}
