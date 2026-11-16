/// The three civilizations. Choosing one at the start chooses the lead hero and their opening; every
/// opening leads into the same Foundry levels.
public enum Faction: String, Sendable, CaseIterable {
    case foundry
    case dawnfaith
    case lanternCities

    /// The faction a hero leads. Anyone who isn't a Dawnfaith or Lantern Cities lead plays the Foundry route.
    public init(lead: FighterKind) {
        switch lead {
        case .seraphine: self = .dawnfaith
        case .nimue: self = .lanternCities
        default: self = .foundry
        }
    }

    public var lead: FighterKind {
        switch self {
        case .foundry: .caelen
        case .dawnfaith: .seraphine
        case .lanternCities: .nimue
        }
    }

    public var opening: Level {
        switch self {
        case .foundry: .awakening
        case .dawnfaith: .sunGauges
        case .lanternCities: .undercroft
        }
    }
}
