# How ReadRight listens

ReadRight times how quickly a child starts speaking, and checks whether they said the right word, without ever recording or sending their voice. This page explains how, step by step.

## The big picture

```
iPhone microphone
   │  AVAudioEngine "tap": iOS hands over chunks of audio (about every 20–100 ms)
   ▼
ListeningEngine ── cuts each chunk into 10 ms windows and measures loudness (dB)
   │                        │
   │                        └─▶ VoiceOnsetDetector: "When did a voice start? When did it stop?"
   │
   └─▶ (same audio) SpeechChecker ── Apple's on-device recognizer: "Was the word 'frog' said?"
                                         │
ReadAloudTrial puts both together ───────┘──▶ onset time (ms) + word check (matched / unclear)
   ▼
ObservationStore saves only the numbers. The audio itself is thrown away.
```

## Step 1: loudness (`AudioLevel.swift`)

Sound arrives as numbers between -1 and 1 called samples, 48,000 per second on most iPhones. To get the loudness of a 10 ms window (480 samples), ReadRight takes the **root mean square**: square every sample, average them, and take the square root. Then it converts to decibels: `20 × log10(rms)`.

- 0 dB is the loudest the microphone can report.
- A quiet room is about -60 to -50 dB. Talking near the phone is about -35 to -20 dB.
- Decibels are a log scale: +6 dB means the sound wave is about twice as big.

A unit test checks this math: a full-volume sine wave should come out at about -3 dB.

## Step 2: when did the voice start? (`VoiceOnsetDetector.swift`)

This is a plain Swift struct with no audio code in it, so the tests can feed it made-up loudness numbers.

1. **Calibrate (0.6 s, while the light is amber).** The detector measures the room before the word appears and uses its quietest fifth as the noise floor. If a child talks during this time, the floor still stays at the quiet room, so their voice can't be mistaken for background noise.
2. **Threshold.** A voice has to be **15 dB louder than the floor**, and never quieter than -50 dB. Without that minimum, breathing in a silent room could count as speech.
3. **Onset.** The voice starts at the first moment loudness stays above the threshold for **60 ms**. A tap or a click is shorter than that, so it's ignored. The onset is the *start* of that loud stretch. Sound before the green light doesn't count (`listenFrom`). If a child is already talking when the light turns green, the detector waits for a pause, because that isn't a reaction time of zero.
4. **Finished.** For a single word, the child is done after 0.8 s of quiet. "Quiet" uses a threshold 6 dB lower, so the soft end of a word still counts. In Firefly Dash, the child taps "I'm done" (or 90 seconds pass), because a child who pauses to think shouldn't look faster than they were.

**Why these numbers?** They're reasonable starting values from basic audio practice, not scientifically validated ones. They're all in `VoiceOnsetDetector.Settings`, and the in-app Listening Lab shows the live loudness, noise floor and threshold for tuning.

## Step 3: exact timing (`ListeningEngine.swift`)

iOS stamps each audio chunk with the **host time**, the iPhone's hardware clock at the moment the sound was recorded. When the light turns green, ReadRight notes the host time too. Onset time = (host time of the loud window) − (host time the light turned green).

That's why the timing is accurate even though audio arrives in chunks. The resolution is 10 ms. Drawing the screen adds roughly one frame (8–16 ms) between noting the time and the child seeing the word.

The code that runs on the audio thread is a `nonisolated static` function. It only measures loudness and hands the numbers to the main thread, because audio threads must never wait on the user interface.

## Step 4: was the word right? (`SpeechChecker.swift`)

- ReadRight uses Apple's `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`.
- **The privacy catch:** Apple only honors that setting if the iPhone *supports* on-device recognition. Otherwise, audio could be sent to Apple's servers. So before every word, ReadRight checks `supportsOnDeviceRecognition`. If it's false, speech isn't recognized at all and only timing is used.
- The recognizer gets a hint (`contextualStrings = ["frog"]`), and homophones are accepted (sun/son).
- Every alternative the recognizer offers is checked, not only its best guess.
- If none matches, the result is **unclear**, never "wrong." Recognizers are trained mostly on adult voices and often mishear children, so a grown-up can override the result.
- Made-up words (zib, vog) never go to the recognizer, because it would "correct" *zib* to *zip*. A grown-up marks those.

## Step 5: the traffic light (`ReadAloudTrial.swift`)

Each spoken item is one trial, shown to the child as a traffic light:

| Light | What's happening |
|---|---|
| Lavender, "Listen to Pip…" | Pip is talking (Echo Cave puzzles). Sound isn't measured. |
| **Amber, "Get ready…"** | The microphone measures the quiet room for 0.6 s. The word is hidden. |
| **Green, "Your turn!"** | The word appears and timing starts at that exact moment (`reveal()`). |
| Green, pulsing, "I hear you!" | A voice was detected. The light swells with the loudness. |
| Lavender, "Pip is thinking…" | The child stopped. The word check gives its answer (within 1.5 s). |

If no voice starts within 8 s of green, the item is marked "no answer," which is never counted as wrong. The microphone turns off between items. Word Woods, Echo Cave and the Listening Lab all use this same class, so what the Lab shows is exactly what the games do.

## Why Pip's voice doesn't cut off

An early version switched the iPhone's audio mode between "speaking" and "listening." Each switch rerouted the audio, which clipped the start or end of Pip's words. Now the mode is set once, when the grown-up's listening choice changes (`AudioSessionConfigurator.configure()`), and never switched mid-game. Each line also starts after a 0.12 s pause so the speaker is awake before the first sound. When someone has recorded a line in the Voice Studio, ReadRight plays that recording instead, with the silence at each end trimmed.

## FAQ

- **Can it tell if a child has dyslexia?** It's a preliminary screener. It measures five skills that research links to dyslexia (letter sounds, phonemic awareness, word reading, made-up word decoding, and rapid naming), then recommends a next step: talk to a specialist, check in, or no follow-up. A doctor or specialist makes the full diagnosis. It doesn't give a probability, because it hasn't been tested against real diagnoses yet. Even research games tested on thousands of children were about 69% accurate for 7–8 year olds (Rello et al. 2020).
- **Why those five skills?** They're what the International Dyslexia Association says a K–2 screener should cover, and what California public schools now screen for every year (Education Code 53008). The app's Research tab lists the sources.
- **Why not use the speech recognizer's timestamps?** The recognizer isn't available on every device, and its timing isn't designed for this. Loudness works everywhere, it's fast, and every step can be tested and explained.
- **What if the room is noisy?** The noise floor is measured fresh for every word, so the threshold moves with the room. Very loud or changing noise, like a TV, can still fool it, so there's a 5-second cap and grown-up buttons.
- **Where does the audio go?** Nowhere. Each chunk is measured in memory and dropped. Only numbers are saved, in an encrypted file on the phone.
- **How accurate is the timing?** The logic is unit-tested with synthetic signals, and timing comes from the audio hardware's clock at 10 ms resolution. It hasn't been checked against professional assessments yet. A pilot with a school or clinic is the next step.
