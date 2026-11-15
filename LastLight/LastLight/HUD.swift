import SpriteKit

final class HUD: SKNode {
    private let barBack = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 190, height: 10), cornerRadius: 3)
    private let barFill = SKSpriteNode(color: Palette.cyan, size: CGSize(width: 186, height: 6))
    private let heroName = SKLabelNode(text: "")
    private let partnerBack = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 110, height: 7), cornerRadius: 2)
    private let partnerFill = SKSpriteNode(color: Palette.cyan, size: CGSize(width: 106, height: 3))
    private let partnerName = SKLabelNode(text: "")
    private let status = SKLabelNode(text: "")
    private let banner = SKLabelNode(text: "")
    private let message = SKLabelNode(text: "")
    private let hint = SKLabelNode(text: "")
    private let damage = SKSpriteNode(color: Palette.red, size: .zero)
    private let debug = SKLabelNode(text: "")
    private let bossBack = SKShapeNode(rect: CGRect(x: -160, y: 0, width: 320, height: 9), cornerRadius: 3)
    private let bossFill = SKSpriteNode(color: Palette.red, size: CGSize(width: 316, height: 5))
    private let bossName = SKLabelNode(text: "")
    private let special = SKLabelNode(text: "")
    private let modeButton = SKLabelNode(text: "MODE")
    private let debugButton = SKLabelNode(text: "DEBUG")

    enum Action {
        case toggleMode
        case toggleDebug
    }

    override init() {
        super.init()
        zPosition = 90

        barBack.fillColor = Palette.body.withAlphaComponent(0.8)
        barBack.strokeColor = Palette.cyan.withAlphaComponent(0.5)
        barBack.lineWidth = 1
        barFill.anchorPoint = CGPoint(x: 0, y: 0)
        barFill.position = CGPoint(x: 2, y: 2)
        barBack.addChild(barFill)
        addChild(barBack)

        partnerBack.fillColor = Palette.body.withAlphaComponent(0.8)
        partnerBack.strokeColor = Palette.cyan.withAlphaComponent(0.3)
        partnerBack.lineWidth = 1
        partnerFill.anchorPoint = CGPoint(x: 0, y: 0)
        partnerFill.position = CGPoint(x: 2, y: 2)
        partnerBack.addChild(partnerFill)
        addChild(partnerBack)
        bossBack.fillColor = Palette.body.withAlphaComponent(0.85)
        bossBack.strokeColor = Palette.red.withAlphaComponent(0.6)
        bossBack.lineWidth = 1
        bossBack.isHidden = true
        bossFill.anchorPoint = CGPoint(x: 0, y: 0)
        bossFill.position = CGPoint(x: -158, y: 2)
        bossBack.addChild(bossFill)
        addChild(bossBack)
        bossName.fontName = "AvenirNext-DemiBold"
        bossName.fontSize = 10
        bossName.fontColor = Palette.red
        bossName.verticalAlignmentMode = .top
        bossName.isHidden = true
        addChild(bossName)

        special.fontName = "AvenirNext-DemiBold"
        special.fontSize = 10
        special.horizontalAlignmentMode = .left
        special.verticalAlignmentMode = .center
        addChild(special)

        partnerName.fontName = "AvenirNext-Medium"
        partnerName.fontSize = 10
        partnerName.fontColor = Palette.white.withAlphaComponent(0.6)
        partnerName.horizontalAlignmentMode = .left
        partnerName.verticalAlignmentMode = .center
        addChild(partnerName)

        for (label, size, face) in [(heroName, 12.0, "AvenirNext-DemiBold"), (status, 12.0, "AvenirNext-Medium"),
                                    (banner, 30.0, "AvenirNext-Heavy"), (message, 26.0, "AvenirNext-Heavy"),
                                    (hint, 12.0, "AvenirNext-Medium")] {
            label.fontName = face
            label.fontSize = size
            label.fontColor = Palette.white.withAlphaComponent(0.85)
            addChild(label)
        }
        heroName.horizontalAlignmentMode = .left
        status.horizontalAlignmentMode = .right
        banner.alpha = 0
        message.numberOfLines = 2
        message.verticalAlignmentMode = .center
        message.isHidden = true
        hint.fontColor = Palette.white.withAlphaComponent(0.55)

        debug.fontName = "Menlo"
        debug.fontSize = 10
        debug.fontColor = Palette.white.withAlphaComponent(0.8)
        debug.numberOfLines = 0
        debug.horizontalAlignmentMode = .right
        debug.verticalAlignmentMode = .top
        debug.isHidden = true
        addChild(debug)
        for button in [modeButton, debugButton] {
            button.fontName = "AvenirNext-DemiBold"
            button.fontSize = 10
            button.fontColor = Palette.cyan.withAlphaComponent(0.7)
            button.horizontalAlignmentMode = .right
            addChild(button)
        }

        damage.anchorPoint = .zero
        damage.alpha = 0
        damage.zPosition = -1
        addChild(damage)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func layout(size: CGSize, insets: Insets) {
        let left = max(insets.left, 16) + 8
        let right = size.width - max(insets.right, 16) - 8
        let top = size.height - max(insets.top, 10) - 14
        heroName.position = CGPoint(x: left, y: top - 6)
        barBack.position = CGPoint(x: left, y: top - 24)
        partnerBack.position = CGPoint(x: left, y: top - 40)
        partnerName.position = CGPoint(x: left + 118, y: top - 36)
        status.position = CGPoint(x: right, y: top - 6)
        banner.position = CGPoint(x: size.width / 2, y: size.height * 0.68)
        message.position = CGPoint(x: size.width / 2, y: size.height * 0.56)
        hint.position = CGPoint(x: size.width / 2, y: top - 6)
        damage.size = size
        special.position = CGPoint(x: left, y: top - 54)
        bossBack.position = CGPoint(x: size.width / 2, y: top - 30)
        bossName.position = CGPoint(x: size.width / 2, y: top - 34)
        debugButton.position = CGPoint(x: right, y: top - 26)
        modeButton.position = CGPoint(x: right - 56, y: top - 26)
        debug.position = CGPoint(x: right, y: top - 36)
    }

    /// The small text buttons under the status line.
    func action(at point: CGPoint) -> Action? {
        for (button, action) in [(modeButton, Action.toggleMode), (debugButton, .toggleDebug)] {
            let centre = CGPoint(x: button.position.x - button.frame.width / 2, y: button.position.y + 4)
            if abs(point.x - centre.x) < 28, abs(point.y - centre.y) < 18 { return action }
        }
        return nil
    }

    func setDebug(_ text: String?) {
        debug.isHidden = text == nil
        if let text, debug.text != text { debug.text = text }
    }

    /// The controlled hero gets the large bar; the partner, if there is one, the small one under it.
    func setHeroes(lead: (name: String, health: Double), partner: (name: String, health: Double)?) {
        if heroName.text != lead.name { heroName.text = lead.name }
        barFill.xScale = CGFloat(max(0, min(1, lead.health)))
        barFill.color = lead.health < 0.3 ? Palette.red : Palette.cyan

        partnerBack.isHidden = partner == nil
        partnerName.isHidden = partner == nil
        guard let partner else { return }
        let text = partner.health <= 0 ? "\(partner.name)  DOWN" : partner.name
        if partnerName.text != text { partnerName.text = text }
        partnerFill.xScale = CGFloat(max(0, min(1, partner.health)))
        partnerFill.color = partner.health < 0.3 ? Palette.red : Palette.cyan
    }

    /// The boss bar, top centre. Nil hides it.
    func setBoss(_ boss: (name: String, health: Double, open: Bool)?) {
        bossBack.isHidden = boss == nil
        bossName.isHidden = boss == nil
        guard let boss else { return }
        let text = boss.open ? "\(boss.name)   OPEN" : boss.name
        if bossName.text != text { bossName.text = text }
        bossName.fontColor = boss.open ? Palette.gold : Palette.red
        bossFill.xScale = CGFloat(max(0, min(1, boss.health)))
        bossFill.color = boss.open ? Palette.gold : Palette.red
    }

    /// The controlled hero's special: its name, and how long until it is ready again.
    func setSpecial(_ info: (name: String, cooldown: Int)?) {
        special.isHidden = info == nil
        guard let info else { return }
        let ready = info.cooldown == 0
        let text = ready ? "✦ \(info.name)" : "✦ \(info.name)  \(info.cooldown / 60 + 1)s"
        if special.text != text { special.text = text }
        special.fontColor = ready ? Palette.gold : Palette.white.withAlphaComponent(0.4)
    }

    func setStatus(_ text: String) {
        if status.text != text { status.text = text }
    }

    func announce(_ text: String) {
        banner.text = text
        banner.removeAllActions()
        banner.alpha = 0
        banner.run(.sequence([.fadeIn(withDuration: 0.12), .wait(forDuration: 0.8), .fadeOut(withDuration: 0.4)]))
    }

    func showMessage(_ text: String) {
        message.text = text
        message.isHidden = false
    }

    func hideMessage() {
        message.isHidden = true
    }

    func showHint(_ text: String) {
        hint.text = text
        hint.removeAllActions()
        hint.alpha = 1
        hint.run(.sequence([.wait(forDuration: 9), .fadeOut(withDuration: 1)]))
    }

    func flashDamage() {
        damage.removeAllActions()
        damage.alpha = 0.22
        damage.run(.fadeOut(withDuration: 0.3))
    }
}
