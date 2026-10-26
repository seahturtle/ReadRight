import AVFoundation

/// Recordings of Pip's lines in a real person's voice, made in the Voice Studio.
///
/// Each line's file is named from its text, so the app finds the right recording automatically.
/// Recordings made on the iPhone are kept in the "PipVoice" folder that ReadRight shares in the
/// Files app. Copy that folder into the Xcode project (ReadRight/PipVoice) and the recordings
/// ship inside the app for everyone.
enum VoiceClips {
    static var folder: URL {
        URL.documentsDirectory.appending(path: "PipVoice", directoryHint: .isDirectory)
    }

    /// A readable, stable file name: the start of the line plus a short hash of the whole line.
    static func key(for text: String) -> String {
        var slug = ""
        for character in text.lowercased() {
            if character.isLetter || character.isNumber {
                slug.append(character)
            } else if slug.last != "-" {
                slug.append("-")
            }
        }
        slug = String(slug.trimmingCharacters(in: CharacterSet(charactersIn: "-")).prefix(40))
        // FNV-1a hash, so two lines that start the same still get different files.
        var hash: UInt32 = 2_166_136_261
        for byte in text.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return "\(slug)-\(String(hash, radix: 16))"
    }

    static func recordedURL(for text: String) -> URL {
        folder.appending(path: key(for: text) + ".m4a")
    }

    /// A recording for this line, if there is one: made on this iPhone first, then shipped in the app.
    static func url(for text: String) -> URL? {
        let recorded = recordedURL(for: text)
        if FileManager.default.fileExists(atPath: recorded.path()) { return recorded }
        let name = key(for: text)
        return Bundle.main.url(forResource: name, withExtension: "m4a")
            ?? Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "PipVoice")
    }

    /// Cuts the quiet before and after the words, so Pip doesn't pause before talking and
    /// Sound Springs' timing starts right when the word ends.
    static func trimSilence(at url: URL, thresholdDB: Float = -42, padding: TimeInterval = 0.06) {
        guard let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil,
              let samples = buffer.floatChannelData?[0]
        else { return }

        let total = Int(buffer.frameLength)
        let sampleRate = file.processingFormat.sampleRate
        let window = max(1, Int(sampleRate / 100))
        var first: Int?
        var last = 0
        var start = 0
        while start < total {
            let count = min(window, total - start)
            if AudioLevel.rmsDB(UnsafeBufferPointer(start: samples + start, count: count)) > thresholdDB {
                if first == nil { first = start }
                last = start + count
            }
            start += count
        }
        guard let first else { return }
        let pad = Int(padding * sampleRate)
        let from = max(0, first - pad)
        let to = min(total, last + pad)
        guard to > from, from > 0 || to < total else { return }

        guard let trimmed = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(to - from)) else { return }
        trimmed.frameLength = AVAudioFrameCount(to - from)
        for channel in 0..<Int(file.processingFormat.channelCount) {
            guard let source = buffer.floatChannelData?[channel], let destination = trimmed.floatChannelData?[channel] else { continue }
            destination.update(from: source + from, count: to - from)
        }
        let temporary = url.deletingLastPathComponent().appending(path: "trimming-\(UUID().uuidString).m4a")
        do {
            let output = try AVAudioFile(forWriting: temporary, settings: file.fileFormat.settings)
            try output.write(from: trimmed)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            return
        }
        _ = try? FileManager.default.replaceItemAt(url, withItemAt: temporary)
    }
}
