import SwiftUI

/// Title, pause, settings and chapter list. Drawn over the game; the game is frozen behind them.
struct MenuOverlay: View {
    @Bindable var game: Game

    var body: some View {
        ZStack {
            switch game.screen {
            case .title:
                backdrop(0.72)
                TitleMenu(game: game)
            case .paused:
                backdrop(0.6)
                PauseMenu(game: game)
            case .playing:
                EmptyView()
            }
            if let panel = game.panel {
                backdrop(0.5)
                    .onTapGesture { game.panel = nil }
                Group {
                    switch panel {
                    case .settings: SettingsPanel(game: game)
                    case .chapters: ChapterPanel(game: game)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
    }

    private func backdrop(_ opacity: Double) -> some View {
        Color.black.opacity(opacity).ignoresSafeArea().transition(.opacity)
    }
}

// MARK: Pieces

private let cyan = Color(red: 0.35, green: 0.92, blue: 1.0)
private let gold = Color(red: 1.0, green: 0.82, blue: 0.4)
private let panelFill = Color(red: 0.02, green: 0.04, blue: 0.08).opacity(0.94)

private struct MenuButton: View {
    let title: String
    var primary = false
    var shortcut: KeyEquivalent?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .tracking(2)
                .foregroundStyle(primary ? Color.black : Color.white)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(primary ? cyan : cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(cyan.opacity(primary ? 0 : 0.45), lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(Shortcut(key: shortcut))
    }
}

private struct Shortcut: ViewModifier {
    let key: KeyEquivalent?

    func body(content: Content) -> some View {
        if let key { content.keyboardShortcut(key, modifiers: []) } else { content }
    }
}

private struct PanelFrame<Content: View>: View {
    let title: String
    let close: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(3)
                    .foregroundStyle(cyan)
                Spacer()
                Button("Done", action: close)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .keyboardShortcut(.escape, modifiers: [])
            }
            content
        }
        .padding(20)
        .frame(maxWidth: 440)
        .background(panelFill, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(cyan.opacity(0.35), lineWidth: 1))
        .padding(16)
    }
}

// MARK: Screens

private struct TitleMenu: View {
    let game: Game

    var body: some View {
        HStack(spacing: 40) {
            VStack(alignment: .leading, spacing: 10) {
                Text("THE LAST LIGHT")
                    .font(.system(size: 40, weight: .black))
                    .tracking(5)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("CHAPTER 1  ·  THE FOUNDRY")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(3)
                    .foregroundStyle(cyan)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                if game.hasProgress {
                    MenuButton(title: "CONTINUE", primary: true, shortcut: .return) { game.continueGame() }
                    MenuButton(title: "NEW GAME") { game.newGame() }
                } else {
                    MenuButton(title: "BEGIN", primary: true, shortcut: .return) { game.newGame() }
                }
                MenuButton(title: "CHAPTERS") { game.panel = .chapters }
                MenuButton(title: "SETTINGS") { game.panel = .settings }
            }
            .frame(width: 240)
        }
        .padding(.horizontal, 48)
        .frame(maxWidth: 900)
    }
}

private struct PauseMenu: View {
    let game: Game

    var body: some View {
        VStack(spacing: 10) {
            Text("PAUSED")
                .font(.system(size: 13, weight: .heavy))
                .tracking(4)
                .foregroundStyle(cyan)
                .padding(.bottom, 6)
            MenuButton(title: "RESUME", primary: true, shortcut: .escape) { game.resume() }
            MenuButton(title: "RETRY FROM CHECKPOINT") { game.retryFromCheckpoint() }
            MenuButton(title: "RESTART LEVEL") { game.restartLevel() }
            HStack(spacing: 10) {
                MenuButton(title: "CHAPTERS") { game.panel = .chapters }
                MenuButton(title: "SETTINGS") { game.panel = .settings }
            }
            MenuButton(title: "QUIT TO TITLE") { game.quitToTitle() }
        }
        .frame(width: 320)
    }
}

private struct SettingsPanel: View {
    @Bindable var game: Game

    var body: some View {
        PanelFrame(title: "SETTINGS", close: { game.panel = nil }) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sound")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Slider(value: $game.settings.volume, in: 0...1)
                    .tint(cyan)
            }
            #if os(iOS)
            toggle("Vibration", $game.settings.haptics)
            #endif
            toggle("Screen shake", $game.settings.screenShake)
            toggle("Debug overlay", $game.settings.debugOverlay)
        }
    }

    private func toggle(_ title: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .tint(cyan)
        .frame(minHeight: 36)
    }
}

private struct ChapterPanel: View {
    let game: Game

    var body: some View {
        PanelFrame(title: "CHAPTERS", close: { game.panel = nil }) {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(game.levelNames.enumerated()), id: \.offset) { index, name in
                        row(number: "\(index + 1)", name: name, note: index == 0 ? "movement" : nil) {
                            game.play(chapter: index)
                        }
                    }
                    row(number: "·", name: "Training Room", note: "waves") { game.trainingRoom() }
                }
            }
            .frame(maxHeight: 260)
        }
    }

    private func row(number: String, name: String, note: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(number)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(gold)
                    .frame(width: 18)
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let note {
                    Text(note)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(cyan.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
