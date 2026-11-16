import AVFoundation

/// Placeholder sound. Every effect is computed at launch from tones and noise, so there are no audio files
/// yet. Recorded or designed sound replaces the `render` table later without touching the callers.
@MainActor
final class Sound {
    enum Effect: CaseIterable {
        case swing, heavySwing, hit, heavyHit, hurt, blocked, parry
        case jump, land, dodge
        case pickup, secret, checkpoint, join
        case fuse, explosion, fall
        case warning, bossWake, bossDown
        case clear, down
    }

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private var next = 0
    /// The frame an effect last started on, so the same sound is not stacked many times in one instant.
    private var lastPlayed: [Effect: Int] = [:]
    private var tick = 0

    init() {
        #if os(iOS)
        // Ambient: obeys the silent switch and mixes with the owner's own music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        for _ in 0..<10 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.mainMixerNode.outputVolume = 0.7
        for effect in Effect.allCases { buffers[effect] = Self.render(effect, format: format) }
        start()
    }

    private func start() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
            players.forEach { $0.play() }
        } catch {
            // No sound is not a reason to stop the game.
        }
    }

    /// Call once per drawn frame; it only counts time for the stacking guard.
    func advance() {
        tick += 1
    }

    var volume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = newValue }
    }

    func play(_ effect: Effect, volume: Float = 1) {
        guard self.volume > 0.001 else { return }
        if let last = lastPlayed[effect], tick - last < 2 { return }
        lastPlayed[effect] = tick
        // The engine stops when audio is interrupted or the output changes.
        start()
        guard engine.isRunning, let buffer = buffers[effect] else { return }
        let player = players[next]
        next = (next + 1) % players.count
        player.volume = volume
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    // MARK: Synthesis

    private struct Noise {
        var state: UInt32 = 0x1234_5678
        var smooth: Float = 0

        /// White noise through a one-pole low-pass; `cutoff` near 1 is bright, near 0 is a rumble.
        mutating func next(cutoff: Float) -> Float {
            state = state &* 1_664_525 &+ 1_013_904_223
            let white = Float(state >> 8) / Float(1 << 23) - 1
            smooth += (white - smooth) * cutoff
            return smooth
        }
    }

    private static func buffer(
        _ seconds: Double, format: AVAudioFormat, _ sample: (_ t: Float, _ progress: Float) -> Float
    ) -> AVAudioPCMBuffer {
        let count = AVAudioFrameCount(seconds * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
        buffer.frameLength = count
        let out = buffer.floatChannelData![0]
        let rate = Float(format.sampleRate)
        for i in 0..<Int(count) {
            let progress = Float(i) / Float(count)
            // A few milliseconds of fade at both ends, so nothing clicks.
            let edge = min(1, Float(i) / 90, Float(Int(count) - i) / 200)
            out[i] = max(-1, min(1, sample(Float(i) / rate, progress))) * edge
        }
        return buffer
    }

    /// A sine whose pitch glides from `from` to `to` over the sound.
    private static func glide(_ t: Float, _ p: Float, from: Float, to: Float) -> Float {
        // Phase of a linear sweep: the integral of the frequency.
        let length = p > 0 ? t / p : 1
        return sin(2 * .pi * (from * t + (to - from) * t * t / (2 * max(length, 0.0001))))
    }

    private static func decay(_ p: Float, _ sharpness: Float) -> Float {
        exp(-sharpness * p)
    }

    private static func render(_ effect: Effect, format: AVAudioFormat) -> AVAudioPCMBuffer {
        var noise = Noise()
        switch effect {
        case .swing:
            return buffer(0.12, format: format) { _, p in
                noise.next(cutoff: 0.25 + 0.5 * p) * sin(.pi * p) * 0.5
            }
        case .heavySwing:
            return buffer(0.2, format: format) { _, p in
                noise.next(cutoff: 0.12 + 0.4 * p) * sin(.pi * p) * 0.7
            }
        case .hit:
            return buffer(0.11, format: format) { t, p in
                (glide(t, p, from: 210, to: 90) * 0.6 + noise.next(cutoff: 0.6) * 0.5) * decay(p, 6)
            }
        case .heavyHit:
            return buffer(0.22, format: format) { t, p in
                (glide(t, p, from: 150, to: 45) * 0.9 + noise.next(cutoff: 0.5) * 0.6) * decay(p, 5)
            }
        case .hurt:
            return buffer(0.26, format: format) { t, p in
                (glide(t, p, from: 320, to: 110) * 0.6 + noise.next(cutoff: 0.3) * 0.5) * decay(p, 4)
            }
        case .blocked:
            return buffer(0.18, format: format) { t, p in
                (sin(2 * .pi * 1240 * t) * 0.35 + sin(2 * .pi * 1830 * t) * 0.25 + noise.next(cutoff: 0.9) * 0.2)
                    * decay(p, 7)
            }
        case .parry:
            return buffer(0.45, format: format) { t, p in
                (sin(2 * .pi * 1760 * t) * 0.4 + sin(2 * .pi * 2640 * t) * 0.3 + sin(2 * .pi * 3520 * t) * 0.15)
                    * decay(p, 5)
            }
        case .jump:
            return buffer(0.1, format: format) { t, p in
                glide(t, p, from: 300, to: 560) * 0.25 * decay(p, 3)
            }
        case .land:
            return buffer(0.08, format: format) { t, p in
                (glide(t, p, from: 120, to: 60) * 0.4 + noise.next(cutoff: 0.2) * 0.3) * decay(p, 6)
            }
        case .dodge:
            return buffer(0.16, format: format) { _, p in
                noise.next(cutoff: 0.7 - 0.5 * p) * sin(.pi * p) * 0.45
            }
        case .pickup:
            return buffer(0.2, format: format) { t, p in
                sin(2 * .pi * (p < 0.4 ? 1320 : 1760) * t) * 0.3 * decay(p, 3)
            }
        case .secret:
            return buffer(0.5, format: format) { t, p in
                let note: Float = p < 0.25 ? 1047 : (p < 0.5 ? 1319 : (p < 0.75 ? 1568 : 2093))
                return sin(2 * .pi * note * t) * 0.3 * decay(p, 2)
            }
        case .checkpoint:
            return buffer(0.4, format: format) { t, p in
                (sin(2 * .pi * 660 * t) + sin(2 * .pi * 990 * t)) * 0.2 * decay(p, 3)
            }
        case .join:
            return buffer(0.5, format: format) { t, p in
                (sin(2 * .pi * (p < 0.5 ? 523 : 784) * t) + sin(2 * .pi * (p < 0.5 ? 659 : 1047) * t)) * 0.2
                    * decay(p, 2)
            }
        case .fuse:
            return buffer(0.3, format: format) { t, p in
                (sin(2 * .pi * 1500 * t) > 0 ? 0.2 : -0.2) * (Int(p * 6) % 2 == 0 ? 1 : 0)
            }
        case .explosion:
            return buffer(0.6, format: format) { t, p in
                (noise.next(cutoff: 0.25 - 0.2 * p) * 1.2 + glide(t, p, from: 90, to: 30) * 0.7) * decay(p, 4)
            }
        case .fall:
            return buffer(0.4, format: format) { t, p in
                glide(t, p, from: 500, to: 80) * 0.4 * decay(p, 2)
            }
        case .warning:
            return buffer(0.5, format: format) { t, p in
                (sin(2 * .pi * 110 * t) > 0 ? 0.25 : -0.25) * sin(.pi * p) + glide(t, p, from: 220, to: 440) * 0.15 * p
            }
        case .bossWake:
            return buffer(1.4, format: format) { t, p in
                (noise.next(cutoff: 0.04) * 2.5 + sin(2 * .pi * 55 * t) * 0.6 + glide(t, p, from: 80, to: 160) * 0.3)
                    * sin(.pi * p)
            }
        case .bossDown:
            return buffer(1.6, format: format) { t, p in
                (noise.next(cutoff: 0.2 - 0.18 * p) * 1.3 + glide(t, p, from: 200, to: 28) * 0.8) * decay(p, 2.5)
            }
        case .clear:
            return buffer(0.9, format: format) { t, p in
                let note: Float = p < 0.2 ? 523 : (p < 0.4 ? 659 : (p < 0.6 ? 784 : 1047))
                return (sin(2 * .pi * note * t) + sin(2 * .pi * note * 1.5 * t) * 0.4) * 0.25 * decay(p, 1.5)
            }
        case .down:
            return buffer(0.9, format: format) { t, p in
                let note: Float = p < 0.33 ? 330 : (p < 0.66 ? 262 : 196)
                return sin(2 * .pi * note * t) * 0.35 * decay(p, 1.5)
            }
        }
    }
}
