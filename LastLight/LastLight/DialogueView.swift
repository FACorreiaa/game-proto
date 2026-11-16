import ActionCore
import SwiftUI

/// The panel a scene is read in. It sits over the paused game: a tap anywhere continues, and a line
/// with answers waits until one is picked.
struct DialogueView: View {
    let story: StoryPresenter

    var body: some View {
        if let runner = story.runner, let line = runner.line {
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.35)
                    .contentShape(Rectangle())
                    .onTapGesture { story.advance() }
                panel(line, choices: runner.choices)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
            .ignoresSafeArea()
            .transition(.opacity)
        }
    }

    /// Each speaker in their faction's light.
    static func colour(for speaker: String) -> Color {
        switch speaker {
        case "CAELEN": Color.white.opacity(0.85)
        case "SERAPHINE": Color(red: 1.0, green: 0.82, blue: 0.4)
        case "NIMUE": Color(red: 0.78, green: 0.58, blue: 1.0)
        case "LAMPLIGHTER": Color(red: 1.0, green: 0.62, blue: 0.3)
        case "LAST ORACLE": Color(red: 0.93, green: 0.89, blue: 0.8)
        default: cyan
        }
    }

    private func panel(_ line: StoryLine, choices: [StoryChoice]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(line.speaker)
                .font(.system(size: 12, weight: .heavy))
                .tracking(2)
                .foregroundStyle(Self.colour(for: line.speaker))
            Text(line.text)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            if choices.isEmpty {
                Button { story.advance() } label: {
                    Text("continue  ▸")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])
            } else {
                ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                    Button { story.choose(index) } label: {
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(Self.cyan)
                            Text(choice.text)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Self.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Self.cyan.opacity(0.5), lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [])
                }
            }
        }
        .padding(18)
        .frame(maxWidth: 620, alignment: .leading)
        .background(Color(red: 0.02, green: 0.04, blue: 0.08).opacity(0.94), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Self.cyan.opacity(0.35), lineWidth: 1))
    }

    private static let cyan = Color(red: 0.35, green: 0.92, blue: 1.0)
}
