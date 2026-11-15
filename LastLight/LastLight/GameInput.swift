import ActionCore
import GameController

/// Keyboard and controller, polled once per rendered frame.
/// Keyboard: A/D or arrows move, Space jumps, J attacks, K dodges, I uses the special, L switches hero, R restarts,
/// M changes between the level and the training room, P shows or hides the debug overlay.
struct HardwareInput {
    private var wasDown: Set<String> = []

    struct Reading {
        var moveX = 0.0
        var jumpHeld = false
        var jump = false
        var attack = false
        var dodge = false
        var special = false
        var switchHero = false
        var restart = false
        var mode = false
        var debug = false
    }

    mutating func poll() -> Reading {
        var down: Set<String> = []
        var reading = Reading()

        if let keys = GCKeyboard.coalesced?.keyboardInput {
            func held(_ code: GCKeyCode) -> Bool { keys.button(forKeyCode: code)?.isPressed ?? false }
            if held(.keyA) || held(.leftArrow) { reading.moveX -= 1 }
            if held(.keyD) || held(.rightArrow) { reading.moveX += 1 }
            if held(.spacebar) || held(.keyW) || held(.upArrow) { down.insert("jump") }
            if held(.keyJ) { down.insert("attack") }
            if held(.keyK) || held(.leftShift) { down.insert("dodge") }
            if held(.keyI) || held(.keyE) { down.insert("special") }
            if held(.keyL) || held(.tab) { down.insert("switch") }
            if held(.keyR) { down.insert("restart") }
            if held(.keyM) { down.insert("mode") }
            if held(.keyP) { down.insert("debug") }
        }

        if let pad = GCController.current?.extendedGamepad {
            let stick = Double(pad.leftThumbstick.xAxis.value)
            let dpad = Double(pad.dpad.xAxis.value)
            let x = abs(stick) > abs(dpad) ? stick : dpad
            if abs(x) > 0.2 { reading.moveX = x }
            if pad.buttonA.isPressed { down.insert("jump") }
            if pad.buttonX.isPressed { down.insert("attack") }
            if pad.buttonB.isPressed || pad.rightShoulder.isPressed { down.insert("dodge") }
            if pad.buttonY.isPressed { down.insert("switch") }
            if pad.leftShoulder.isPressed || pad.rightTrigger.isPressed { down.insert("special") }
            if pad.buttonMenu.isPressed { down.insert("restart") }
        }

        reading.moveX = max(-1, min(1, reading.moveX))
        reading.jumpHeld = down.contains("jump")
        reading.jump = down.contains("jump") && !wasDown.contains("jump")
        reading.attack = down.contains("attack") && !wasDown.contains("attack")
        reading.dodge = down.contains("dodge") && !wasDown.contains("dodge")
        reading.special = down.contains("special") && !wasDown.contains("special")
        reading.switchHero = down.contains("switch") && !wasDown.contains("switch")
        reading.restart = down.contains("restart") && !wasDown.contains("restart")
        reading.mode = down.contains("mode") && !wasDown.contains("mode")
        reading.debug = down.contains("debug") && !wasDown.contains("debug")
        wasDown = down
        return reading
    }
}

/// Plays the feel slice badly but busily, so the scene can be watched and screenshotted without hands.
enum DemoBot {
    static func input(for world: World) -> InputFrame {
        guard let hero = world.controlled else { return .neutral }
        let enemies = world.fighters.filter { $0.team == .enemy && $0.isAlive }
        let live = enemies.filter { !$0.spec.immortal }
        guard let target = (live.isEmpty ? enemies : live)
            .min(by: { abs($0.pos.x - hero.pos.x) < abs($1.pos.x - hero.pos.x) }) else { return .neutral }

        let dx = target.pos.x - hero.pos.x
        let dir: Double = dx >= 0 ? 1 : -1
        var inp = InputFrame()
        inp.switchHero = world.frame % 600 == 599

        if target.state == .fuse, abs(dx) < 150 {
            inp.moveX = -dir
            return inp
        }
        if let attack = target.currentAttack, target.attackPhase == .windup,
           attack.windup - target.stateFrame <= 5, abs(dx) < 150 {
            inp.moveX = dir
            // Alternates between parrying and dodging through.
            if (world.frame / 240) % 2 == 0 { inp.attack = true } else { inp.dodge = true }
            return inp
        }
        if abs(dx) > 88 {
            inp.moveX = dir
            inp.jump = world.frame % 170 == 0
            inp.jumpHeld = true
        } else {
            inp.moveX = dir * 0.02
            inp.attack = world.frame % 9 == 0
        }
        return inp
    }
}
