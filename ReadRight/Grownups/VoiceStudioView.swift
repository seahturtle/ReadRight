import AVFoundation
import SwiftUI

/// Record Pip's lines in a real, friendly voice. Lines without a recording use the iPhone voice.
/// These are a grown-up's or the team's recordings, not the child's, and they never leave the
/// iPhone unless someone copies them out through the Files app.
struct VoiceStudioView: View {
    @State private var studio = VoiceStudioModel()

    private let lines = PipLines.catalog

    var body: some View {
        List {
            Section {
                Text("Kids listen best to a warm, real voice. Record Pip's lines yourself, and the games will play your voice instead of the iPhone's.")
                    .themed(.body, 15)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tips").themed(.display, 15)
                    Text("Find a quiet room. Smile while you talk, it really changes how you sound. Speak a little slower than normal, about a hand's length from the iPhone. Tap Record, say the line, then tap Stop.")
                        .themed(.body, 14)
                        .foregroundStyle(Theme.inkSoft)
                }
                LabeledContent("Recorded", value: "\(studio.recordedCount(lines)) of \(lines.count) lines")
                if let error = studio.errorText {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
            }

            ForEach(groups, id: \.self) { group in
                Section(group) {
                    ForEach(lines.filter { $0.group == group }) { line in
                        LineRow(line: line, studio: studio)
                    }
                }
            }

            Section("Ship your recordings inside the app") {
                Text("Recordings live on this iPhone in Files → On My iPhone → ReadRight → PipVoice. To put them in the app for everyone, connect the iPhone to your Mac, open it in Finder → Files → ReadRight, drag the PipVoice folder into the ReadRight folder of the Xcode project, and build again.")
                    .themed(.body, 14)
            }
        }
        .navigationTitle("Voice Studio")
        .onAppear { studio.prepare() }
        .onDisappear { studio.finish() }
    }

    private var groups: [String] {
        var seen: [String] = []
        for line in lines where !seen.contains(line.group) { seen.append(line.group) }
        return seen
    }
}

private struct LineRow: View {
    let line: PipLines.Line
    let studio: VoiceStudioModel

    var body: some View {
        let recording = studio.recordingText == line.text
        let recorded = studio.isRecorded(line.text)
        VStack(alignment: .leading, spacing: 8) {
            Text(line.text).themed(.body, 16).foregroundStyle(Theme.ink)
            HStack(spacing: 8) {
                Button {
                    Task { await studio.toggleRecording(line.text) }
                } label: {
                    pill(recording ? "Stop" : (recorded ? "Redo" : "Record"), recording ? "stop.fill" : "mic.fill", text: .white, fill: recording ? .red : Theme.earth)
                }
                .buttonStyle(.borderless)

                Button {
                    studio.play(line.text)
                } label: {
                    pill("Play", "play.fill", text: Theme.earth, fill: Theme.soft)
                }
                .buttonStyle(.borderless)
                .disabled(recording)

                if recorded, !recording {
                    Button {
                        studio.delete(line.text)
                    } label: {
                        pill(nil, "trash", text: .red, fill: Theme.soft)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Delete recording")
                }
                Spacer()
                Text(recorded ? "Your voice" : "iPhone voice")
                    .font(.caption)
                    .foregroundStyle(recorded ? Theme.mintDark : Theme.muted)
            }
        }
        .padding(.vertical, 4)
    }

    private func pill(_ title: String?, _ icon: String, text: Color, fill: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            if let title { Text(title) }
        }
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .foregroundStyle(text)
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(fill))
    }
}

@MainActor
@Observable
final class VoiceStudioModel {
    private(set) var recordingText: String?
    var errorText: String?
    /// Bumped whenever a file changes, so rows re-check whether their line is recorded.
    private var changes = 0

    @ObservationIgnored private var recorder: AVAudioRecorder?

    func isRecorded(_ text: String) -> Bool {
        _ = changes
        return FileManager.default.fileExists(atPath: VoiceClips.recordedURL(for: text).path())
    }

    func recordedCount(_ lines: [PipLines.Line]) -> Int {
        lines.filter { isRecorded($0.text) }.count
    }

    /// Recording needs a session that can use the microphone. It's put back when leaving the studio.
    func prepare() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)
    }

    func finish() {
        stopRecording()
        Speaker.shared.stop()
        AudioSessionConfigurator.configure()
    }

    func toggleRecording(_ text: String) async {
        if recordingText == text {
            stopRecording()
            return
        }
        stopRecording()
        errorText = nil
        guard await AVAudioApplication.requestRecordPermission() else {
            errorText = "Microphone access is off for ReadRight. Turn it on in the Settings app → ReadRight."
            return
        }
        Speaker.shared.stop()
        prepare()
        do {
            try FileManager.default.createDirectory(at: VoiceClips.folder, withIntermediateDirectories: true)
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: VoiceClips.recordedURL(for: text), settings: settings)
            guard recorder.record() else {
                errorText = "Recording didn't start. Try again."
                return
            }
            self.recorder = recorder
            recordingText = text
        } catch {
            errorText = "Recording didn't start: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        guard let recorder else { return }
        let url = recorder.url
        recorder.stop()
        self.recorder = nil
        recordingText = nil
        VoiceClips.trimSilence(at: url)
        changes += 1
    }

    func play(_ text: String) {
        Task { await Speaker.shared.say(text, essential: true) }
    }

    func delete(_ text: String) {
        try? FileManager.default.removeItem(at: VoiceClips.recordedURL(for: text))
        changes += 1
    }
}
