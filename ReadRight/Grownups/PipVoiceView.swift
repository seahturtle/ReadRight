import AVFoundation
import SwiftUI

/// Choose Pip's voice. Premium and Enhanced voices sound much warmer than the standard ones.
struct PipVoiceView: View {
    @AppStorage(PipVoice.defaultsKey) private var chosenID = ""
    @State private var voices: [AVSpeechSynthesisVoice] = []

    var body: some View {
        List {
            Section {
                Text("Pick the voice that sounds friendliest. Tap the speaker to hear Pip.")
                    .themed(.body, 15)
            }
            Section("Voices on this iPhone") {
                ForEach(voices, id: \.identifier) { voice in
                    HStack(spacing: 12) {
                        Button {
                            chosenID = voice.identifier
                        } label: {
                            HStack {
                                Image(systemName: isChosen(voice) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isChosen(voice) ? Theme.mintDark : Theme.muted)
                                VStack(alignment: .leading) {
                                    Text(voice.name).themed(.body, 17)
                                    Text(PipVoice.qualityLabel(voice)).themed(.body, 13).foregroundStyle(Theme.muted)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Button {
                            preview(voice)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.earth)
                        .accessibilityLabel("Hear \(voice.name)")
                    }
                }
            }
            Section("Get a warmer voice") {
                Text("Download a Premium voice for free: open the Settings app → Accessibility → Spoken Content → Voices → English, then pick a voice such as Zoe or Ava and choose Premium. Come back here and select it. (On newer iPhones the menu may be called Read & Speak.)")
                    .themed(.body, 14)
            }
        }
        .navigationTitle("Pip's voice")
        .onAppear { voices = PipVoice.choices }
    }

    private func isChosen(_ voice: AVSpeechSynthesisVoice) -> Bool {
        chosenID.isEmpty ? voice.identifier == PipVoice.current?.identifier : chosenID == voice.identifier
    }

    /// Hearing a voice doesn't choose it. Tapping the voice's name does.
    private func preview(_ voice: AVSpeechSynthesisVoice) {
        Task {
            await Speaker.shared.say("Hi, I'm Pip! Let's walk through Letterwood together.", essential: true, voice: voice)
        }
    }
}
