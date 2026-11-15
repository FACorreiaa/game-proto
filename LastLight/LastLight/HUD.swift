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

        damage.anchorPoint = .zero
        damage.alpha = 0
        damage.zPosition = -1
        addChild(damage)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func layout(size: CGSize, insets: UIEdgeInsets) {
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

    func setStatus(wave: Int, kills: Int) {
        let text = wave == 0 ? "TRAINING" : "WAVE \(wave)   KILLS \(kills)"
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
