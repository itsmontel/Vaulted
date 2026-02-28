import AVFoundation
import Foundation
import Speech

// MARK: - SpeechTranscriptionService
/// On-device speech-to-text using Apple's Speech framework.
/// Audio is always split into 25-second chunks because the framework silently drops the
/// beginning of single-file requests longer than ~30 seconds (confirmed behaviour
/// where e.g. a 52-second file only returns seconds 30–52).
@MainActor
final class SpeechTranscriptionService {

    static let shared = SpeechTranscriptionService()

    /// Chunk length in seconds. Reduced to 25s for more reliable recognition.
    private static let chunkDuration: TimeInterval = 25
    /// 2-second overlap so words at a chunk boundary are never cut off.
    private static let chunkOverlap: TimeInterval = 2
    /// Minimum segment length - very short to capture all audio including brief endings.
    private static let minimumSegmentDuration: TimeInterval = 0.3

    private init() {}
    
    /// Extended vocabulary hints to improve recognition accuracy.
    private static let contextualVocabulary: [String] = [
        // App-specific
        "vaulted", "inbox", "ideas", "work", "journal", "note", "notes", "voice", "recording",
        // Common action words
        "remember", "remind", "reminder", "todo", "to-do", "task", "tasks", "meeting", "meetings",
        "call", "email", "text", "message", "send", "buy", "get", "pick up", "finish", "complete",
        "start", "begin", "schedule", "plan", "cancel", "reschedule", "follow up", "check",
        // Time expressions
        "today", "tomorrow", "yesterday", "tonight", "morning", "afternoon", "evening", "night",
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "january", "february", "march", "april", "may", "june", "july", "august",
        "september", "october", "november", "december",
        "next week", "this week", "last week", "next month", "this month",
        // Numbers (spoken)
        "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
        "eleven", "twelve", "thirteen", "fourteen", "fifteen", "twenty", "thirty", "hundred",
        // Common phrases
        "don't forget", "need to", "want to", "have to", "going to",
        "important", "urgent", "deadline", "priority",
        // Thinking words
        "think", "thought", "idea", "maybe", "probably", "definitely", "actually", "basically",
        // Connectors
        "and", "but", "also", "however", "because", "first", "second", "then", "next", "finally",
        // Places
        "home", "office", "store", "doctor", "gym", "airport", "restaurant",
        // Objects
        "phone", "laptop", "car", "keys", "wallet", "appointment", "package"
    ]

    /// Request speech recognition authorization. Call before transcribing.
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Transcribe audio file to text. Returns nil if unavailable or on error.
    /// All audio — even short clips — goes through the chunking pipeline so that
    /// the framework's leading-drop bug never affects the result.
    func transcribe(audioURL: URL) async -> String? {
        let duration = Self.audioDuration(url: audioURL) ?? 0

        let preferredLocale = Locale.current
        guard let recognizer = SFSpeechRecognizer(locale: preferredLocale),
              recognizer.isAvailable else {
            let preferredLanguageCode: String
            if #available(iOS 16.0, *) {
                preferredLanguageCode = preferredLocale.language.languageCode?.identifier ?? ""
            } else {
                preferredLanguageCode = preferredLocale.languageCode ?? ""
            }
            if let fallback = SFSpeechRecognizer.supportedLocales().first(where: { locale in
                let code: String
                if #available(iOS 16.0, *) { code = locale.language.languageCode?.identifier ?? "" }
                else { code = locale.languageCode ?? "" }
                return code == preferredLanguageCode
            }),
               let fallbackRecognizer = SFSpeechRecognizer(locale: fallback),
               fallbackRecognizer.isAvailable {
                return await transcribeInChunks(recognizer: fallbackRecognizer, audioURL: audioURL, duration: duration)
            }
            return nil
        }

        // Always chunk — even a 10-second clip goes through the same safe path.
        return await transcribeInChunks(recognizer: recognizer, audioURL: audioURL, duration: duration)
    }

    // MARK: - Chunked transcription

    /// Split audio into chunks, transcribe each with retries, stitch together.
    private func transcribeInChunks(recognizer: SFSpeechRecognizer, audioURL: URL, duration: TimeInterval) async -> String? {
        let step = Self.chunkDuration - Self.chunkOverlap
        var start: TimeInterval = 0
        var parts: [String] = []
        var chunkIndex = 0

        while start < duration {
            let chunkEnd = min(start + Self.chunkDuration, duration)
            let segmentDuration = chunkEnd - start
            
            // Only skip extremely short segments
            guard segmentDuration >= Self.minimumSegmentDuration else {
                start += step
                continue
            }

            guard let segmentURL = await exportSegment(from: audioURL, start: start, duration: segmentDuration) else {
                // Retry export once before giving up on this chunk
                try? await Task.sleep(nanoseconds: 200_000_000)
                if let retryURL = await exportSegment(from: audioURL, start: start, duration: segmentDuration) {
                    defer { try? FileManager.default.removeItem(at: retryURL) }
                    if let text = await transcribeChunkWithRetry(recognizer: recognizer, audioURL: retryURL, duration: segmentDuration, chunkIndex: chunkIndex) {
                        parts.append(text)
                    }
                }
                start += step
                chunkIndex += 1
                continue
            }
            defer { try? FileManager.default.removeItem(at: segmentURL) }

            if let text = await transcribeChunkWithRetry(recognizer: recognizer, audioURL: segmentURL, duration: segmentDuration, chunkIndex: chunkIndex) {
                parts.append(text)
            }
            
            start += step
            chunkIndex += 1
            
            // Small delay between chunks to let the recognizer reset
            if start < duration {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        guard !parts.isEmpty else { return nil }
        return censorProfanity(stitchParts(parts))
    }
    
    /// Replaces profanity in transcript with asterisk versions (e.g. f*ck). Whole-word, case-insensitive.
    private func censorProfanity(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        let pairs: [(word: String, replacement: String)] = [
            ("fucking", "f*cking"), ("fucker", "f*cker"), ("fucked", "f*cked"), ("fuck", "f*ck"),
            ("shit", "sh*t"), ("shitty", "sh*tty"), ("bullshit", "bullsh*t"),
            ("bitch", "b*tch"), ("bitches", "b*tches"),
            ("asshole", "a*shole"), ("ass", "a*s"),
            ("damn", "d*mn"), ("damned", "d*mned"),
            ("crap", "cr*p"),
            ("dick", "d*ck"), ("dicks", "d*cks"),
            ("cock", "c*ck"), ("cocks", "c*cks"),
            ("piss", "p*ss"), ("pissed", "p*ssed"), ("pissing", "p*ssing"),
            ("slut", "sl*t"), ("sluts", "sl*ts"),
            ("whore", "wh*re"), ("whores", "wh*res"),
            ("bastard", "b*stard"), ("bastards", "b*stards"),
            ("dumbass", "dumba*s"), ("badass", "bada*s"),
            ("dipshit", "dipsh*t"), ("dipshits", "dipsh*ts"),
        ]
        var result = text
        for (word, replacement) in pairs.sorted(by: { $0.word.count > $1.word.count }) {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: replacement
            )
        }
        return result
    }
    
    /// Transcribe a single chunk with up to 3 retry attempts.
    private func transcribeChunkWithRetry(recognizer: SFSpeechRecognizer, audioURL: URL, duration: TimeInterval, chunkIndex: Int) async -> String? {
        for attempt in 1...3 {
            if let text = await performTranscription(recognizer: recognizer, audioURL: audioURL, duration: duration),
               !text.isEmpty {
                return text
            }
            if attempt < 3 {
                // Exponential backoff: 300ms, 600ms
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 300_000_000)
            }
        }
        return nil
    }

    /// Join chunk transcriptions, removing words duplicated by the 2-second overlap.
    private func stitchParts(_ parts: [String]) -> String {
        var joined = parts[0]
        for i in 1..<parts.count {
            let next = parts[i]
            let prevWords = joined.split(separator: " ").map(String.init)
            let nextWords = next.split(separator: " ").map(String.init)
            
            // 2-second overlap at normal speaking pace = ~5-8 words; search up to 15.
            let window = min(15, min(prevWords.count, nextWords.count))
            var overlapCount = 0
            
            // Try exact match first
            for length in stride(from: window, through: 1, by: -1) {
                let tail = Array(prevWords.suffix(length)).map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
                let head = Array(nextWords.prefix(length)).map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
                if tail == head {
                    overlapCount = length
                    break
                }
            }
            
            // If no exact match, try fuzzy match (at least 70% of words match)
            if overlapCount == 0 && window >= 3 {
                for length in stride(from: min(8, window), through: 3, by: -1) {
                    let tail = Array(prevWords.suffix(length)).map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
                    let head = Array(nextWords.prefix(length)).map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
                    let matches = zip(tail, head).filter { $0 == $1 }.count
                    if Double(matches) / Double(length) >= 0.7 {
                        overlapCount = length
                        break
                    }
                }
            }
            
            let trimmed = overlapCount > 0
                ? nextWords.dropFirst(overlapCount).joined(separator: " ")
                : next
            if !trimmed.isEmpty {
                // Add proper spacing, handling punctuation
                let needsSpace = !joined.hasSuffix(" ") && !trimmed.hasPrefix(" ")
                joined += (needsSpace ? " " : "") + trimmed
            }
        }
        return joined
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Audio utilities

    private static func audioDuration(url: URL) -> TimeInterval? {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let d = asset.duration
        guard d.isNumeric else { return nil }
        return CMTimeGetSeconds(d)
    }

    /// Export [start, start+duration) of audio to a temporary M4A file.
    private func exportSegment(from sourceURL: URL, start: TimeInterval, duration: TimeInterval) async -> URL? {
        let asset = AVURLAsset(url: sourceURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        guard let exportSession = AVAssetExportSession(asset: asset,
                                                       presetName: AVAssetExportPresetAppleM4A)
        else { return nil }

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        exportSession.outputURL      = outURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange      = CMTimeRange(
            start:    CMTime(seconds: start,    preferredTimescale: 600),
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )
        try? await exportSession.export()
        guard exportSession.status == .completed else { return nil }
        return outURL
    }

    // MARK: - Core recognition

    private func performTranscription(recognizer: SFSpeechRecognizer,
                                      audioURL: URL,
                                      duration: TimeInterval = 0) async -> String? {
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.taskHint = .dictation
        request.shouldReportPartialResults = true
        request.contextualStrings = Self.contextualVocabulary
        
        // Enable automatic punctuation for better readability (iOS 16+)
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }

        // Timeout = chunk duration + 30-second grace, clamped to [40s, 90s] for reliability.
        let timeoutSecs = min(90.0, max(40.0, duration + 30.0))
        let timeoutNanoseconds = UInt64(timeoutSecs) * 1_000_000_000

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                var didResume = false
                var bestPartial = ""
                var lastUpdateTime = Date()

                func resumeOnce(_ value: String?) {
                    guard !didResume else { return }
                    didResume = true
                    continuation.resume(returning: value)
                }

                let task = recognizer.recognitionTask(with: request) { result, error in
                    if let result = result {
                        let text = result.bestTranscription.formattedString
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "  ", with: " ")
                        if !text.isEmpty {
                            bestPartial = text
                            lastUpdateTime = Date()
                        }
                        if result.isFinal {
                            resumeOnce(text.isEmpty ? nil : text)
                            return
                        }
                    }

                    if let error = error {
                        let nsError = error as NSError
                        // Known error codes that indicate unrecoverable failures
                        let isFatal = (nsError.domain == "kAFAssistantErrorDomain" ||
                                       nsError.domain == "com.apple.SpeechRecognition") &&
                                      [216, 201, 209, 1110].contains(nsError.code)
                        // Return best partial even on errors - don't lose transcribed content
                        resumeOnce(isFatal && bestPartial.isEmpty ? nil : bestPartial.isEmpty ? nil : bestPartial)
                    }
                }

                // Timeout watchdog - also checks for stalled recognition
                Task {
                    var elapsedWithoutUpdate: TimeInterval = 0
                    let checkInterval: UInt64 = 2_000_000_000 // 2 seconds
                    
                    while !didResume {
                        try? await Task.sleep(nanoseconds: checkInterval)
                        guard !didResume else { return }
                        
                        let totalElapsed = Date().timeIntervalSince(lastUpdateTime)
                        elapsedWithoutUpdate = totalElapsed
                        
                        // If we have content and no updates for 8+ seconds, recognition likely done
                        if !bestPartial.isEmpty && elapsedWithoutUpdate > 8.0 {
                            task.cancel()
                            resumeOnce(bestPartial)
                            return
                        }
                        
                        // Hard timeout
                        if elapsedWithoutUpdate > timeoutSecs {
                            task.cancel()
                            resumeOnce(bestPartial.isEmpty ? nil : bestPartial)
                            return
                        }
                    }
                }
            }
        } onCancel: { }
    }
}