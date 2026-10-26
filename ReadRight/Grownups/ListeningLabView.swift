import AVFoundation
import Speech
import SwiftUI

/// A testing screen for the microphone, the voice-onset detector and the on-device word check.
/// It runs the same `ReadAloudTrial` (and the same traffic light) that the games use. Nothing here is saved.
struct ListeningLabView: View {
    @Environment(ListeningEngine.self) private var engine
    @Environment(ProfileStore.self) private var profiles
    @State private var lab = ListeningLabModel()
    @State private var micPermission = AVAudioApplication.shared.recordPermission
    @State private var speechPermission = SFSpeechRecognizer.authorizationStatus()

    var body: some View {
        Form {
            Section {
                Text("Check that listening works on this iPhone. Nothing on this screen is saved.")
                if !profiles.profile.listenToReading {
                    Text("The games won't listen until you turn on “Listen while my child reads out loud” in Grown-ups → Settings.")
                        .font(.footnote)
                        .foregroundStyle(Theme.warnInk)
                }
            }

            Section("Permissions") {
                LabeledContent("Microphone", value: micLabel)
                if micPermission == .undetermined {
                    Button("Allow microphone") {
                        Task {
                            _ = await AVAudioApplication.requestRecordPermission()
                            micPermission = AVAudioApplication.shared.recordPermission
                            AudioSessionConfigurator.configure()
                        }
                    }
                }
                LabeledContent("Speech recognition", value: speechLabel)
                if speechPermission == .notDetermined {
                    Button("Allow speech recognition") {
                        Task { speechPermission = await SpeechChecker.requestAuthorization() }
                    }
                }
                if micPermission == .denied || speechPermission == .denied {
                    Text("To turn it back on, open the Settings app → ReadRight.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Word check") {
                if lab.speech.isOnDeviceAvailable {
                    Label("On-device word check is ready", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.mintDark)
                } else {
                    Label("Word check unavailable. Games will use voice timing only.", systemImage: "info.circle")
                }
                #if targetEnvironment(simulator)
                Text("You're in the Simulator. Apple's speech recognizer often fails here (error 1107), so test the word check on a real iPhone. Voice timing works with your Mac's microphone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                #endif
            }

            Section {
                TalkLight(state: lab.talkState, levelDB: engine.levelDB, speakNowText: "Your turn! Read it now.", offText: "Tap the button to start.")
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 4, trailing: 12))
                WordCard(word: lab.showsWord ? lab.word : nil, green: lab.talkState == .speakNow || lab.talkState == .hearing)
                Button(lab.running ? "Listening…" : "Show a word and time me") {
                    Task { await lab.tryWord(engine: engine) }
                }
                .disabled(lab.running || micPermission != .granted)
                LabeledContent("Voice started after green", value: lab.onsetMs.map { "\($0) ms" } ?? "–")
                LabeledContent("Word check", value: lab.check?.rawValue ?? "–")
                LabeledContent("Recognizer heard", value: lab.transcript.isEmpty ? "–" : lab.transcript)
                if let error = lab.errorText {
                    Text(error).foregroundStyle(.red)
                }
            } header: {
                Text("Try a word")
            } footer: {
                Text("Wait for green, then read the word out loud. \"Recognizer heard\" is shown here for testing and is never saved.")
            }

            Section("Live loudness") {
                LevelMeter(levelDB: engine.levelDB, floorDB: lab.floorDB, thresholdDB: lab.thresholdDB)
                    .padding(.vertical, 6)
                LabeledContent("Level", value: engine.isListening ? "\(Int(engine.levelDB)) dB" : "–")
                if let floor = lab.floorDB, let threshold = lab.thresholdDB {
                    LabeledContent("Room noise / voice threshold", value: "\(Int(floor)) dB / \(Int(threshold)) dB")
                }
                Button(engine.isListening ? "Stop listening" : "Start listening") {
                    if engine.isListening {
                        lab.cancel()
                        engine.stop()
                    } else {
                        lab.errorText = nil
                        do { try engine.start() } catch { lab.errorText = error.localizedDescription }
                    }
                }
                .disabled(micPermission != .granted)
            }
        }
        .navigationTitle("Listening Lab")
        .onDisappear {
            lab.cancel()
            engine.stop()
        }
    }

    private var micLabel: String {
        switch micPermission {
        case .granted: "Allowed"
        case .denied: "Not allowed"
        case .undetermined: "Not asked yet"
        @unknown default: "Unknown"
        }
    }

    private var speechLabel: String {
        switch speechPermission {
        case .authorized: "Allowed"
        case .denied: "Not allowed"
        case .restricted: "Restricted on this device"
        case .notDetermined: "Not asked yet"
        @unknown default: "Unknown"
        }
    }
}

@MainActor
@Observable
final class ListeningLabModel {
    private(set) var word = "cat"
    private(set) var running = false
    private(set) var talkState: TalkState = .off
    private(set) var floorDB: Float?
    private(set) var thresholdDB: Float?
    private(set) var onsetMs: Int?
    private(set) var check: WordCheck?
    private(set) var transcript = ""
    var errorText: String?

    let speech = SpeechChecker()
    @ObservationIgnored private var nextIndex = 0
    @ObservationIgnored private var trial: ReadAloudTrial?

    var showsWord: Bool {
        talkState == .speakNow || talkState == .hearing || talkState == .thinking || (!running && check != nil)
    }

    func tryWord(engine: ListeningEngine) async {
        guard !running else { return }
        errorText = nil
        if !engine.isListening {
            do { try engine.start() } catch {
                errorText = error.localizedDescription
                return
            }
        }
        let items = ItemBank.wordWoods(for: .sevenToEight).filter { $0.checkWithRecognizer }
        let item = items[nextIndex % items.count]
        nextIndex += 1
        word = item.target
        onsetMs = nil
        check = nil
        transcript = ""
        running = true
        talkState = .getReady

        speech.onTranscript = { [weak self] text in self?.transcript = text }
        let trial = ReadAloudTrial(engine: engine, speech: speech.isOnDeviceAvailable ? speech : nil)
        self.trial = trial
        let outcome = await trial.run(word: item.target, alsoAccept: item.alsoAccept) { [weak self] progress in
            switch progress {
            case .speakNow(let floor, let threshold):
                self?.floorDB = floor
                self?.thresholdDB = threshold
                self?.talkState = .speakNow
            case .voiceStarted(let ms):
                self?.onsetMs = ms
                self?.talkState = .hearing
            case .voiceEnded:
                self?.talkState = .thinking
            }
        }
        onsetMs = outcome.onsetMs
        check = outcome.wordCheck
        talkState = .off
        running = false
    }

    func cancel() {
        trial?.cancel()
        speech.cancel()
    }
}
