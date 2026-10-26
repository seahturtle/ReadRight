# How ReadRight's listening works

Read this before the video and before you talk to judges. If you can explain each step below in your own words, you understand the most technical part of the app.

## The big picture

```
iPhone microphone
   │  AVAudioEngine "tap": the system hands us chunks of audio (about every 20–100 ms)
   ▼
ListeningEngine ── cuts each chunk into 10 ms windows and measures loudness (dB)
   │                        │
   │                        └─▶ VoiceOnsetDetector: "when did a voice start? when did it stop?"
   │
   └─▶ (same audio) SpeechChecker ── Apple's on-device recognizer: "was the word 'frog' said?"
                                         │
ReadAloudTrial puts both together ───────┘──▶ onset time (ms) + word check (matched / unclear)
   ▼
ObservationStore saves only the numbers. The audio itself is thrown away.
```

## Step 1: loudness (`AudioLevel.swift`)

Sound is a list of numbers between -1 and 1, the "samples", 48,000 per second on most iPhones. To get loudness for a 10 ms window (480 samples), we take the **root mean square**: square every sample, average them, take the square root. Then convert to decibels: `20 × log10(rms)`.

- 0 dB is the loudest the mic can report.
- A quiet room is about -60 to -50 dB. Talking near the phone is about -35 to -20 dB.
- Decibels are a log scale: +6 dB means the sound wave is about twice as big.

The tests check this math: a full-volume sine wave should come out at about -3 dB.

## Step 2: when did the voice start? (`VoiceOnsetDetector.swift`)

This is a plain Swift struct with no audio code, so the tests can feed it made-up loudness numbers.

1. **Calibrate (0.6 s, while the light is amber).** Average the loudness before the word appears. That's this room's background noise, the "noise floor". The word isn't on screen yet, so the child is quiet. The detector ignores any sound before the green light (`listenFrom`).
2. **Threshold.** A voice has to be **15 dB louder than the floor**, and never below -50 dB. Without that minimum, breathing in a silent room could count as speech.
3. **Onset.** The voice "starts" at the first moment loudness stays above the threshold for **60 ms**. A tap on the screen or a cough click is shorter than that, so it's ignored. We record the *start* of that loud stretch, not the end.
4. **Finished.** After the onset, the child is done once it's been quiet for 0.8 s (one word) or 3 s (Firefly Dash, because kids pause between colors). "Quiet" uses a threshold 6 dB lower, so the soft end of a word still counts.

**Why these numbers?** They're reasonable starting values from basic audio practice, not scientifically validated ones. Test them yourselves in the Listening Lab, in a quiet room and a noisy one. If they need changing, edit `VoiceOnsetDetector.Settings`, then write down what you changed and why. That's a great answer to the "technical challenge" question.

## Step 3: exact timing (`ListeningEngine.swift`)

The audio system stamps each chunk with the **host time**: the iPhone's hardware clock at the moment the sound was recorded. When a word appears on screen we note the host time too (`markStimulus`). Onset time = (host time of the loud window) - (host time the word appeared).

That's why the timing is accurate even though audio reaches our code in chunks. The resolution is 10 ms. Drawing the screen adds roughly one frame (8–16 ms) between "we marked it" and "the child saw it".

The code that runs on the audio thread is a `nonisolated static` function. It only measures loudness and passes numbers back to the main thread. Audio threads must never wait on the user interface.

## Step 4: was the word right? (`SpeechChecker.swift`)

- We use Apple's `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`.
- **Privacy catch:** Apple only honors that setting if the iPhone *supports* on-device recognition. Otherwise the audio could be sent to Apple's servers. So before every word, we check `supportsOnDeviceRecognition`. If it's false, we don't recognize speech at all and use only the timing.
- We give the recognizer a hint (`contextualStrings = ["frog"]`) and accept homophones (sun/son).
- We look at every alternative the recognizer offers, not only its best guess.
- If none matches, the result is **unclear**, not "wrong". Recognizers are trained mostly on adult voices and often mishear children. A grown-up can override it with the chips under the word.

## The traffic light

Every speaking item works like a traffic light, so a child always knows when to talk:

| Light | What's happening |
|---|---|
| Lavender, "Listen to Pip…" | Pip is talking (Echo Cave puzzles). Sound isn't measured. |
| **Amber, "Get ready…"** | The microphone measures the quiet room for 0.6 s. The word is hidden. |
| **Green, "Your turn!"** | The word appears and the clock starts at that exact moment (`reveal()` in `ReadAloudTrial`). |
| Green, pulsing, "I hear you!" | A voice was detected. The light swells with the loudness. |
| Lavender, "Pip is thinking…" | The child stopped. The word check gives its answer. |

Calibrating before the word appears means the noise floor is never polluted by an eager reader. The onset time is measured from green, not from amber.

## Why Pip's voice no longer cuts off

The first version switched the iPhone's audio mode between "speaking" and "listening". Each switch reroutes the audio, which clipped the start or end of Pip's words. Now the mode is set once (`AudioSessionConfigurator.configure()`) and never switched mid-game. Each line also starts after a 0.12 s pause, so the speaker is awake before the first sound, and the voice is "warmed up" with a silent line when the app opens.

## Step 5: putting it together (`ReadAloudTrial.swift`)

One trial = one word. It starts the detector and the recognizer, waits for the voice to finish (or 8 s of silence after green, which counts as "no response"), then asks the recognizer for its final answer (up to 1.5 s). Word Woods, Echo Cave and the Listening Lab all run this same class, so what you test in the Lab is what the games do. For made-up words the recognizer is skipped entirely, because it would "correct" *zib* to *zip*. A grown-up marks those instead.

## Questions a judge might ask

- **"Can it tell if a child has dyslexia?"** It's a preliminary screener. It measures five skills that research links to dyslexia (letter sounds, phonemic awareness, word reading, made-up word decoding, and rapid naming). Then it recommends a next step: talk to a specialist, check in, or no follow-up. A doctor or specialist makes the full diagnosis. It doesn't give a probability, because we haven't yet tested it against real diagnoses. That's our next step. Even research games tested on thousands of children were only about 69% accurate for 7–8 year olds (Rello et al. 2020).
- **"Why those five skills?"** They're what the International Dyslexia Association says a K–2 screener should cover, and what California schools now screen for every year (Education Code 53008). See the Research tab in the app for sources.
- **"Why not just use the speech recognizer's timestamps?"** The recognizer isn't available on every device, and its timing isn't designed for this. Loudness works everywhere, it's fast, and we can test and explain every step.
- **"What if the room is noisy?"** The noise floor is measured fresh for every word, so the threshold moves with the room. Very loud or changing noise (a TV) can still fool it, so there's a 5-second cap and grown-up buttons.
- **"Where does the audio go?"** Nowhere. Each chunk is measured in memory and dropped. Only numbers are saved, in an encrypted file on the phone.
- **"How do you know it's accurate?"** The logic is unit-tested with made-up signals. Add what you actually tried, for example "we tested it on our phones in a quiet room and a noisy one, and onset times were within about X ms of what we expected." We have *not* checked it against professional assessments. That's the first thing a 2.0 would do, with a school or clinic.
