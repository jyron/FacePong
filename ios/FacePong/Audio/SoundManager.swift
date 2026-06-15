// SoundManager.swift — audio + haptics for FacePong. Matches sfx.ts behaviour
// exactly: pitch-ramping paddle blips, randomised wall bounce, success/error
// notification haptics on score events, and selection haptic on countdown ticks.
//
// Architecture:
//   AVAudioEngine with one AVAudioPlayerNode + AVAudioUnitVarispeed pair per
//   logical sound. The paddle channel uses two such pairs round-robined so
//   rapid p1/p2 exchanges never cut each other off (mirrors the two-player
//   array in sfx.ts). All nodes are wired to the engine's mainMixerNode so
//   the whole graph shares one output tap.
//
//   Every public call is fire-and-forget and silently no-ops if the engine
//   or a buffer is missing — gameplay continues muted rather than crashing.

import AVFoundation
import UIKit

// MARK: - Internal channel

private final class SoundChannel {
    let player = AVAudioPlayerNode()
    let varispeed = AVAudioUnitVarispeed()
    var buffer: AVAudioPCMBuffer?
}

// MARK: - SoundManager

enum Sound {

    // MARK: public API

    /// Configure the AVAudioSession and preload all buffers. Call once at app
    /// start (e.g. in FacePongApp.init or scene(_:willConnectTo:)).
    static func prepare() {
        configureSession()
        buildEngine()
        prepareHaptics()
    }

    /// Paddle hit. Pitch climbs with the rally and p2 sits a minor third lower.
    static func paddle(_ slot: Slot, rally: Int) {
        let baseRate = min(1.0 + Float(rally) * 0.035, 1.7)
        let rate = slot == .p1 ? baseRate : baseRate * 0.82
        play(channel: nextPaddleChannel(), rate: rate, volume: 1.0)
        switch slot {
        case .p1: impactMedium.impactOccurred()
        case .p2: impactLight.impactOccurred()
        }
    }

    /// Wall bounce. Slight pitch randomisation keeps repeated hits from sounding robotic.
    static func wall() {
        let rate = Float.random(in: 0.9 ..< 1.15)
        play(channel: wallChannel, rate: rate, volume: 0.7)
    }

    /// Local player scored a point.
    static func score() {
        play(channel: scoreChannel, rate: 1.0, volume: 1.0)
        notificationSuccess.notificationOccurred(.success)
    }

    /// Local player lost a point.
    static func lose() {
        play(channel: loseChannel, rate: 1.0, volume: 1.0)
        notificationError.notificationOccurred(.error)
    }

    /// Milestone reached (e.g. match point).
    static func milestone() {
        play(channel: milestoneChannel, rate: 1.0, volume: 1.0)
        impactHeavy.impactOccurred()
    }

    /// Countdown tick. `go` plays the blip a fifth up (rate 1.5).
    static func tick(go: Bool) {
        play(channel: tickChannel, rate: go ? 1.5 : 1.0, volume: 1.0)
        selectionFeedback.selectionChanged()
    }

    /// Win fanfare at match end.
    static func fanfare() {
        play(channel: fanfareChannel, rate: 1.0, volume: 1.0)
        notificationSuccess.notificationOccurred(.success)
    }

    // MARK: - engine

    private static let engine = AVAudioEngine()

    /// Two paddle channels round-robined — mirrors the JS paddle array so a p1
    /// blip and a p2 return never cancel each other during fast rallies.
    private static var paddleChannels: [SoundChannel] = []
    private static var paddleIdx = 0

    private static var wallChannel     = SoundChannel()
    private static var scoreChannel    = SoundChannel()
    private static var loseChannel     = SoundChannel()
    private static var milestoneChannel = SoundChannel()
    private static var tickChannel     = SoundChannel()
    private static var fanfareChannel  = SoundChannel()

    private static var engineReady = false

    // MARK: - haptic generators (pre-warmed for low latency)

    private static let impactLight   = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium  = UIImpactFeedbackGenerator(style: .medium)
    private static let impactHeavy   = UIImpactFeedbackGenerator(style: .heavy)
    private static let notificationSuccess = UINotificationFeedbackGenerator()
    private static let notificationError   = UINotificationFeedbackGenerator()
    private static let selectionFeedback   = UISelectionFeedbackGenerator()

    // MARK: - session

    private static func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playback category plays through the iOS silent switch.
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            // Non-fatal: audio will simply respect the silent switch.
        }
    }

    // MARK: - engine setup

    private static func buildEngine() {
        // Build two paddle channels.
        paddleChannels = [SoundChannel(), SoundChannel()]

        let allChannels: [SoundChannel] = paddleChannels + [
            wallChannel, scoreChannel, loseChannel,
            milestoneChannel, tickChannel, fanfareChannel,
        ]

        let fileNames: [String] = [
            "paddle", "paddle",
            "wall", "score", "lose",
            "milestone", "tick", "fanfare",
        ]

        let mixer = engine.mainMixerNode

        for (idx, channel) in allChannels.enumerated() {
            // Load buffer first so we can connect with its native format.
            let name = fileNames[idx]
            channel.buffer = loadBuffer(named: name)

            // Attach nodes.
            engine.attach(channel.player)
            engine.attach(channel.varispeed)

            // Chain: player → varispeed → mixer.
            // Use the buffer's processing format for the player→varispeed leg so
            // AVAudioEngine doesn't have to guess; pass nil on the varispeed→mixer
            // leg and let the engine insert a format converter if needed.
            let bufFormat = channel.buffer?.format
            engine.connect(channel.player,    to: channel.varispeed, format: bufFormat)
            engine.connect(channel.varispeed, to: mixer,             format: nil)
        }

        do {
            try engine.start()
            engineReady = true
        } catch {
            // Audio unavailable — all play() calls will no-op.
            engineReady = false
        }
    }

    /// Load a wav from the app bundle into a PCM buffer.
    private static func loadBuffer(named name: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                        frameCapacity: frameCount) else { return nil }
        do {
            try file.read(into: buf)
        } catch {
            return nil
        }
        return buf
    }

    // MARK: - playback

    private static func nextPaddleChannel() -> SoundChannel {
        let ch = paddleChannels[paddleIdx]
        paddleIdx = (paddleIdx + 1) % paddleChannels.count
        return ch
    }

    private static func play(channel: SoundChannel, rate: Float, volume: Float) {
        guard engineReady, let buffer = channel.buffer else { return }

        // Varispeed rate: 1.0 = normal, 2.0 = double speed / octave up.
        channel.varispeed.rate = rate

        // Volume via player volume property.
        channel.player.volume = volume

        // Schedule buffer for immediate one-shot playback.
        // Using scheduleBuffer without a completion handler keeps this fire-and-
        // forget; interrupting a still-playing node is intentional for short SFX
        // (except paddle where two nodes prevent that).
        channel.player.stop()
        channel.player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        channel.player.play()
    }

    // MARK: - haptics warmup

    private static func prepareHaptics() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationSuccess.prepare()
        notificationError.prepare()
        selectionFeedback.prepare()
    }
}
