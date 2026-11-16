import ActionCore
import ImageIO
import SpriteKit
import SwiftUI

/// New Game: three factions, three leads, three ways into the Foundry.
struct FactionPick: View {
    let game: Game

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Back") { game.screen = .title }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 36, alignment: .leading)
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                VStack(spacing: 2) {
                    Text("CHOOSE A FACTION")
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(3)
                        .foregroundStyle(.white)
                    Text("Three ways into the Foundry.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Color.clear.frame(width: 44, height: 1)
            }
            HStack(spacing: 12) {
                ForEach(Array(FactionCard.all.enumerated()), id: \.offset) { index, card in
                    FactionCardView(card: card, number: index + 1) { game.begin(card.faction) }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: 940)
    }
}

/// What a card says. Names, titles, themes and quotes come from the concept art; the motive lines are draft
/// writing for the creator's verdict.
struct FactionCard {
    let faction: Faction
    let name: String
    let themes: String
    let title: String
    let quote: String
    let motive: String
    let colour: Color

    static let all: [FactionCard] = [
        FactionCard(faction: .foundry, name: "THE FOUNDRY", themes: "Science · Control · Redemption",
                    title: "The Creator", quote: "I built a solution. I didn't expect it to feel like this.",
                    motive: "Wake on the line. Find out what you built.",
                    colour: Color(red: 0.35, green: 0.92, blue: 1.0)),
        FactionCard(faction: .dawnfaith, name: "THE DAWNFAITH", themes: "Faith · Sacrifice · Renewal",
                    title: "The Oracle", quote: "The light listens. Even now.",
                    motive: "Walk into the Foundry to see what it knows about the light.",
                    colour: Color(red: 1.0, green: 0.82, blue: 0.4)),
        FactionCard(faction: .lanternCities, name: "THE LANTERN CITIES", themes: "Trade · Survival · Opportunity",
                    title: "The Smuggler", quote: "The night hides more than you think.",
                    motive: "Slip in by the undercroft and bring your runners home.",
                    colour: Color(red: 0.78, green: 0.58, blue: 1.0)),
    ]
}

private struct FactionCardView: View {
    let card: FactionCard
    let number: Int
    let choose: () -> Void
    @State private var portrait: PortraitScene

    init(card: FactionCard, number: Int, choose: @escaping () -> Void) {
        self.card = card
        self.number = number
        self.choose = choose
        _portrait = State(initialValue: PortraitScene(kind: card.faction.lead))
    }

    var body: some View {
        Button(action: choose) {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.name)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(card.colour)
                Text(card.themes)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                SpriteView(scene: portrait, options: [.allowsTransparency])
                    .frame(minHeight: 56, idealHeight: 112, maxHeight: 112)
                    .frame(maxWidth: .infinity)
                    .layoutPriority(-1)
                    .allowsHitTesting(false)
                Text(card.faction.lead.rawValue.capitalized)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                Text(card.title.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(card.colour.opacity(0.85))
                Text("“\(card.quote)”")
                    .font(.system(size: 12).italic())
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                Text(card.motive)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                LinearGradient(colors: [card.colour.opacity(0.16), Color.black.opacity(0.55)],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(card.colour.opacity(0.5), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(CardPress())
        .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: [])
        .accessibilityLabel("\(card.name.capitalized), \(card.faction.lead.rawValue.capitalized), \(card.title)")
    }
}

/// A card dips slightly when pressed.
private struct CardPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// The lead standing in the card: the same figure as in the game, idling.
@MainActor
final class PortraitScene: SKScene {
    private var world: World
    private let node: FighterNode
    private let id: Int

    init(kind: FighterKind) {
        var world = World(seed: 1, arena: 0...400)
        id = world.spawn(kind, x: 200, facing: 1)
        world.control(id)
        self.world = world
        node = FighterNode(kind: kind)
        super.init(size: CGSize(width: 200, height: 112))
        scaleMode = .resizeFill
        backgroundColor = .clear
        addChild(node)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func update(_ currentTime: TimeInterval) {
        _ = world.step(.neutral)
        guard let f = world.fighter(id) else { return }
        node.sync(f, frame: world.frame)
        // `sync` places the figure at its world position; the card wants it centred, feet near the bottom,
        // with room above for a crown or hair.
        let scale = min(1.1, (size.height - 16) / (f.spec.height + 34))
        node.setScale(scale)
        node.position = CGPoint(x: size.width / 2, y: 8)
        #if DEBUG
        saveForChecking()
        #endif
    }

    #if DEBUG
    private var saved = false

    /// With `-snapshot`, saves the figure once, to check the card without a screen capture.
    private func saveForChecking() {
        guard !saved, world.frame == 90, ProcessInfo.processInfo.arguments.contains("-snapshot"),
              let image = view?.texture(from: self)?.cgImage() else { return }
        saved = true
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("snapshots")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("portrait-\(world.fighter(id)?.kind.rawValue ?? "").png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
    #endif
}
