/// A chapter: its levels, in the order a lead plays them, and the story file that goes with them. Chapter 1 is
/// the first content pack in all but name; a second pack is another chapter.
public struct Chapter: Sendable, Identifiable {
    /// Stable, saved, and the stem of the chapter's story file (`chapter1.json`).
    public let id: String
    public let number: Int
    public let title: String
    /// The line on the results screen after the chapter's last level.
    public let ending: String
    private let route: @Sendable (FighterKind) -> [Level]

    public init(id: String, number: Int, title: String, ending: String,
                route: @escaping @Sendable (FighterKind) -> [Level]) {
        self.id = id
        self.number = number
        self.title = title
        self.ending = ending
        self.route = route
    }

    /// The levels as this lead plays them.
    public func levels(for lead: FighterKind) -> [Level] { route(lead) }

    public static let foundry = Chapter(
        id: "chapter1", number: 1, title: "The Foundry",
        ending: "The Protocol is silent. It was only a voice. The Eclipse Engine has not stopped.",
        route: { Level.chapter1(for: $0) })

    public static let lanternCities = Chapter(
        id: "chapter2", number: 2, title: "The Lantern Cities",
        ending: "The Cinder King is beaten. His ledgers are not finished.",
        route: { _ in [.emberMarket, .tollCanal, .lanternRoofs, .lampRow, .cinderDocks, .cinderVault] })

    public static let dawnfaith = Chapter(
        id: "chapter3", number: 3, title: "The Dawnfaith",
        ending: "The Last Oracle is beaten. She still believes the ending is coming.",
        route: { _ in [.pilgrimRoad, .sunCloister, .choirStair, .oracleTerrace] })

    /// Every chapter, in play order.
    public static let all: [Chapter] = [.foundry, .lanternCities, .dawnfaith]

    public static func named(_ id: String) -> Chapter? { all.first { $0.id == id } }
}
