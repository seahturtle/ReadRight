import AVFoundation

/// Sets up the app's audio.
///
/// Switching the audio session back and forth between "speaking" and "listening" made Pip's words
/// clip at the start or end. So the session changes only when the grown-up's listening choice changes:
/// - Listening allowed (the in-app choice is on and iOS gave microphone permission): `.playAndRecord`,
///   which plays Pip on the loudspeaker and can also listen. The microphone itself is only on while
///   a listening round runs (the glowing ear).
/// - Otherwise: `.playback`. That category can't record at all.
@MainActor
enum AudioSessionConfigurator {
    /// The grown-up's "Listen while my child reads out loud" choice. RootView keeps this in sync.
    static var listeningChosen = false

    static var listeningAllowed: Bool {
        listeningChosen && ListeningEngine.hasMicPermission
    }

    static func configure() {
        let session = AVAudioSession.sharedInstance()
        do {
            if listeningAllowed {
                if session.category != .playAndRecord {
                    try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
                }
            } else if session.category != .playback {
                try session.setCategory(.playback, mode: .spokenAudio)
            }
            try session.setActive(true)
        } catch {
            print("ReadRight audio session setup failed: \(error.localizedDescription)")
        }
    }

    /// Before Pip talks. Reactivates after an interruption such as a phone call, without changing anything else.
    static func ensureActive() {
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
