public enum TargetSelector: Sendable, Equatable {
    case basicTarget
    case backlineFirst
    case lowestHPAlly
    case selfOnly
    case allEnemies
    case enemyFrontColumn
}

public enum AbilityEffect: Sendable, Equatable {
    case damage(multiplier: Double)
    case heal(amount: Int)
    case shield(amount: Int)
}

public struct Ability: Sendable, Equatable {
    public let id: String
    public let target: TargetSelector
    public let effect: AbilityEffect

    public init(id: String, target: TargetSelector, effect: AbilityEffect) {
        self.id = id
        self.target = target
        self.effect = effect
    }
}
