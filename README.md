# ReadRight

ReadRight is an iPhone game that works as a preliminary screener for early signs of dyslexia and other reading and listening difficulties. It measures the early skills reading specialists check, using on-device timing and speech recognition, and recommends when a family should see a doctor or specialist for a full diagnosis.

Children walk through Letterwood with Pip and visit four islands. Each island observes one or two of the skills that research links to dyslexia:

| Island | What the child does | Skill specialists look at | What the app observes |
|---|---|---|---|
| **Sound Springs** | Sees a picture, hears its word, taps the first letter | Letter–sound knowledge | First-try match, mirror-image (b/d) or sound-alike (b/p) mix-ups, time to first tap |
| **Echo Cave** | Two practice puzzles, then says words without their first sound (snail → nail) | Phonemic awareness | Time from the green light to the answer, on-device word check, single sounds vs blends |
| **Word Woods** | Reads real words and made-up creature names | Word reading and decoding (nonword reading) | Time to start reading, word check for real words, a grown-up's marks for made-up words |
| **Firefly Dash** | Names 20 fireflies carrying pictures (ages 5–6) or letters (ages 7–8) as fast as they can | Rapid automatized naming (RAN) | Time to the first name, total naming time, whether all 20 were named |

A **traffic light** tells the child when to talk. Amber ("Get ready…") means the microphone is learning the room's quiet. Green ("Your turn!") means the word is on screen and timing has started.

The **grown-up area** opens with a **screening result**: "Recommended: talk to a specialist", "Worth checking in", or "No signs that need follow-up today". It lists the reasons and who to see: a teacher or school psychologist, a pediatrician, a dyslexia specialist, and a hearing check or speech-language pathologist when the listening results call for it. Below that come an "At a glance" table, a card for each skill with a bar per item (compared only with the child's own middle time), patterns that happened twice or more, and a **Share** button that sends the results to the family's doctor or specialist. The recommendation rules are at the top of `SummaryBuilder.referral`. The summary doesn't estimate how likely a condition is, because the games haven't been tested against real diagnoses yet.

Built for the 2026 Congressional App Challenge (CA-10). The design comes from the team's web prototype.

## Run it

**Simulator.** Open `ReadRight.xcodeproj`, choose an iPhone simulator, and press ⌘R.
- First launch shows the grown-up setup. Turn on "Listen while my child reads out loud" to allow the microphone.
- Voice timing works with your Mac's microphone. Apple's speech recognizer usually fails in the Simulator (error 1107), so the word check falls back to timing only. That's expected.

**Real iPhone (needed to test the word check and Pip's real voice).**
1. Xcode → Settings → Accounts → add your Apple ID. A free account works.
2. Click the blue ReadRight project → target **ReadRight** → **Signing & Capabilities** → set **Team** to your Personal Team. If the bundle ID is taken, change `com.kiraniyer.ReadRight` to something unique.
3. On the iPhone: Settings → Privacy & Security → **Developer Mode** → on, then restart.
4. Plug the iPhone in, choose it at the top of Xcode, and press ⌘R.
5. The first time, trust the developer: Settings → General → VPN & Device Management.

**Tests.** Press ⌘U. There are 46 test cases: the voice-onset detector (including the traffic light), loudness math, word matching, item lists, Echo Cave practice, the recording catalog, the data store, the grown-up gate, and the family summary and referral rules.

**Testing flags** (Edit Scheme → Run → Arguments):
- `-skipSetup` skips the grown-up setup.
- `-screen lab` opens a screen directly. Other values: `soundSprings`, `echoCave`, `wordWoods`, `fireflyDash`, `grownUps`, `log`, `voice`.
- `-silent` mutes Pip.
- `-autostart` skips game intros.
- `-sampleSummary` shows the summary's labeled layout example.

## Make Pip sound friendlier

**Best: record Pip yourselves.** Grown-ups → Settings → **Record Pip's voice**. Every line Pip says is listed, with Record and Play buttons. Silence before and after each take is trimmed automatically. Any line you don't record uses the iPhone voice. Recordings are kept in Files → On My iPhone → ReadRight → PipVoice. To ship them inside the app, connect the iPhone, open it in Finder → Files → ReadRight, and drag the PipVoice folder into the `ReadRight/` folder of this project.

**Otherwise, a better iPhone voice.** The built-in "standard" voices can sound robotic. On the iPhone, download a free Premium voice: Settings → Accessibility → Spoken Content → Voices → English → pick **Zoe** or **Ava** → Premium. (On newer iPhones the menu may be called Read & Speak.) Then in ReadRight, open Grown-ups → Settings → **Choose an iPhone voice for Pip** and select it. ReadRight picks the best installed voice automatically, and leaves out novelty voices.

## Check that listening works (5 minutes)

1. Grown-ups → Settings → turn on **Listen while my child reads out loud** (iOS asks for permission).
2. Grown-ups → Settings → **Listening Lab** → **Show a word and time me**. Wait for green, then read the word. You'll see "Voice started after ___ ms" and the word check.
3. Turn on **Show listening numbers during games**, then play Word Woods.
4. **Raw observations** shows exactly what was saved.

## Who built what

The Congressional App Challenge rules allow AI tools if **all AI use is disclosed**, and AI can't be all of the technical work. Judges may ask for the source code and ask you to explain it. Read [`docs/HOW-THE-AUDIO-WORKS.md`](docs/HOW-THE-AUDIO-WORKS.md) and the summary rules at the top of `SummaryBuilder.swift`.

| Part | Built by |
|---|---|
| Original concept, the web prototype's design (look, Pip, path, islands, summary layout) | Your friend, with Claude (claude.ai) |
| `Audio/`: listening engine, traffic light, voice-onset detector, on-device speech check, Pip's voice | Claude Code (Opus 5.5), Oct 25 |
| `Games/`: all four islands, item lists, shared game pieces | Claude Code, Oct 25 |
| `World/`: map, welcome and setup, Pip, path scene, island art (ported from the prototype) | Claude Code, Oct 25 |
| `Grownups/`: family summary and its rules, activities and research tabs, settings, voice picker, Listening Lab, raw log | Claude Code, Oct 25, with research gathered by a Claude subagent |
| `Models/`, tests, Xcode project | Claude Code, Oct 25 |
| Grown-up gate (`Grownups/ParentGateView.swift`) and privacy page (`Grownups/PrivacyView.swift`) | Claude Code, Oct 26, at the team's request |
| **Pip's recorded voice** (Voice Studio) | Team (TODO) |
| App icon; testing on real iPhones and tuning; the demo video; the written answers | Team (TODO) |

Before submitting, add a line to the AI-use log for anything you change yourselves.
## AI-use log

Keep adding to this. Short and honest is better than vague.

- **2026-10-25, Claude (claude.ai):** brainstormed the ReadRight idea and built the web prototype (your friend's chat).
- **2026-10-25, Claude Code:** researched the CAC rules and past CA-10 winners, wrote the build plan, ran a security and privacy review.
- **2026-10-25, Claude Code:** wrote the audio engine, the first three games, the data store, testing screens, tests and the Xcode project. Ran an automated code review and fixed what it found.
- **2026-10-25, Claude Code:** redesigned the app to match the prototype. Added the traffic light, the Echo Cave and made-up-word activities, the family summary, research and settings, and a friendlier voice picker. Researched dyslexia indicators with sources.
- **2026-10-25, Claude Code:** replaced Pip with a gentler firefly design. Added the Voice Studio for recording Pip's lines, Echo Cave practice puzzles, more made-up words, a fourth letter choice, pictures and letters instead of colors in Firefly Dash, and an "At a glance" summary. Saved the first git version.
- **2026-10-26, Claude Code:** added the screening result and referral at the top of the summary, then ran a security check against the Challenge rules. Built the grown-up gate and the privacy page at the team's request, and pushed the project to GitHub.
- *(add your entries: what you asked, what you used, what you changed)*

## Privacy design

- The app never sends anything anywhere: no accounts, no server, no analytics, no third-party code.
- Everything starts off. A grown-up turns on the notebook, listening and sharing in setup.
- Speech recognition is on-device only. Before every request, the app checks `supportsOnDeviceRecognition`. If the iPhone can't recognize speech on its own, the word check turns off. There is no server fallback. Made-up words are never sent to the recognizer at all.
- Audio is never saved. Microphone buffers are measured in memory and dropped. Only numbers and short labels are stored.
- The microphone is on only during a listening round (Echo Cave, Word Woods, Firefly Dash, the Lab), and the glowing ear and traffic light show it. It turns off when the app goes to the background.
- Data is JSON files in Application Support: observations, plus the nickname, choices and optional background. They're encrypted while the phone is locked (`.completeFileProtection`), excluded from backups, and observations are deleted after 90 days. Grown-ups → Settings → **Erase everything** removes all of it.

## Known limitations

- Nothing has been checked against professional assessments. These are observations, not a test, and there are no age norms.
- English only. Word lists should be reviewed by a teacher or reading specialist.
- Speech recognizers are trained mostly on adult voices, which is why a mismatch counts as "unclear" and isn't counted.
- One Firefly Dash per visit. Real rapid-naming tests average two tries.
