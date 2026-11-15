import SpriteKit

/// A floating stick on the left half of the screen and three buttons on the right.
final class TouchControls: SKNode {
    enum Button: CaseIterable {
        case attack
        case dodge
        case jump
    }

    private(set) var moveX = 0.0
    private(set) var jumpHeld = false
    /// Presses since the last time they were taken.
    private var pressed: Set<Button> = []

    private var stickTouch: UITouch?
    private var stickOrigin = CGPoint.zero
    private var stickRest = CGPoint.zero
    private var buttonTouches: [UITouch: Button] = [:]

    private let stickBase = SKShapeNode(circleOfRadius: 52)
    private let stickKnob = SKShapeNode(circleOfRadius: 24)
    private var buttonNodes: [Button: SKShapeNode] = [:]
    private var sceneSize = CGSize.zero

    private let stickRange: CGFloat = 46
    private let deadZone: CGFloat = 8

    override init() {
        super.init()
        zPosition = 100

        stickBase.strokeColor = Palette.white.withAlphaComponent(0.22)
        stickBase.lineWidth = 2
        stickBase.fillColor = Palette.white.withAlphaComponent(0.04)
        stickKnob.strokeColor = .clear
        stickKnob.fillColor = Palette.white.withAlphaComponent(0.25)
        addChild(stickBase)
        addChild(stickKnob)

        for (button, radius, glyph) in [(Button.attack, 42.0, "⚔︎"), (.dodge, 32.0, "»"), (.jump, 32.0, "▲")] {
            let node = SKShapeNode(circleOfRadius: radius)
            node.strokeColor = Palette.white.withAlphaComponent(0.3)
            node.lineWidth = 2
            node.fillColor = Palette.white.withAlphaComponent(0.06)
            let label = SKLabelNode(text: glyph)
            label.fontName = "AvenirNext-Bold"
            label.fontSize = radius * 0.8
            label.fontColor = Palette.white.withAlphaComponent(0.6)
            label.verticalAlignmentMode = .center
            node.addChild(label)
            addChild(node)
            buttonNodes[button] = node
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func layout(size: CGSize, insets: UIEdgeInsets) {
        sceneSize = size
        let left = max(insets.left, 16)
        let right = max(insets.right, 16)
        let bottom = max(insets.bottom, 12)
        stickRest = CGPoint(x: left + 86, y: bottom + 84)
        if stickTouch == nil { showStick(at: stickRest, knob: stickRest) }

        let edge = size.width - right
        buttonNodes[.attack]?.position = CGPoint(x: edge - 62, y: bottom + 66)
        buttonNodes[.jump]?.position = CGPoint(x: edge - 158, y: bottom + 50)
        buttonNodes[.dodge]?.position = CGPoint(x: edge - 82, y: bottom + 156)
    }

    func takePresses() -> Set<Button> {
        defer { pressed = [] }
        return pressed
    }

    // MARK: Touches (locations are in scene coordinates)

    func began(_ touch: UITouch, at point: CGPoint) {
        if let button = button(at: point) {
            buttonTouches[touch] = button
            pressed.insert(button)
            if button == .jump { jumpHeld = true }
            highlight(button, true)
        } else if point.x < sceneSize.width / 2, stickTouch == nil {
            stickTouch = touch
            stickOrigin = point
            showStick(at: point, knob: point)
        }
    }

    func moved(_ touch: UITouch, to point: CGPoint) {
        guard touch === stickTouch else { return }
        let dx = point.x - stickOrigin.x
        let dy = point.y - stickOrigin.y
        // The base follows a thumb that drags past its edge, so reversing direction is always quick.
        if abs(dx) > stickRange { stickOrigin.x = point.x - (dx > 0 ? stickRange : -stickRange) }
        let x = point.x - stickOrigin.x
        moveX = abs(x) < deadZone ? 0 : Double(max(-1, min(1, x / stickRange)))
        let clampedY = max(-stickRange, min(stickRange, dy))
        showStick(at: stickOrigin, knob: CGPoint(x: stickOrigin.x + x, y: stickOrigin.y + clampedY))
    }

    func ended(_ touch: UITouch) {
        if touch === stickTouch {
            stickTouch = nil
            moveX = 0
            showStick(at: stickRest, knob: stickRest)
        }
        if let button = buttonTouches.removeValue(forKey: touch) {
            if button == .jump { jumpHeld = buttonTouches.values.contains(.jump) }
            highlight(button, buttonTouches.values.contains(button))
        }
    }

    private func button(at point: CGPoint) -> Button? {
        // Generous targets: the nearest button within 1.5 times its radius.
        var best: (Button, CGFloat)?
        for (button, node) in buttonNodes {
            let radius = node.frame.width / 2
            let distance = hypot(point.x - node.position.x, point.y - node.position.y)
            if distance <= radius * 1.5, distance < (best?.1 ?? .infinity) { best = (button, distance) }
        }
        return best?.0
    }

    private func showStick(at base: CGPoint, knob: CGPoint) {
        stickBase.position = base
        stickKnob.position = knob
    }

    private func highlight(_ button: Button, _ on: Bool) {
        buttonNodes[button]?.fillColor = Palette.white.withAlphaComponent(on ? 0.28 : 0.06)
    }
}
