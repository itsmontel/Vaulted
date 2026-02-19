import Foundation
import Speech

// MARK: - SpeechTranscriptionService
/// On-device speech-to-text using Apple's Speech framework.
@MainActor
final class SpeechTranscriptionService {

    static let shared = SpeechTranscriptionService()

    private init() {}

    /// Request speech recognition authorization. Call before transcribing.
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Transcribe audio file to text. Returns nil if unavailable or on error.
    func transcribe(audioURL: URL) async -> String? {
        // Try to get the best available recognizer (prefer on-device)
        let preferredLocale = Locale.current
        guard let recognizer = SFSpeechRecognizer(locale: preferredLocale),
              recognizer.isAvailable else {
            // Fallback: try to find any available recognizer
            let preferredLanguageCode: String
            if #available(iOS 16.0, *) {
                preferredLanguageCode = preferredLocale.language.languageCode?.identifier ?? ""
            } else {
                preferredLanguageCode = preferredLocale.languageCode ?? ""
            }
            
            if let fallback = SFSpeechRecognizer.supportedLocales().first(where: { locale in
                let localeLanguageCode: String
                if #available(iOS 16.0, *) {
                    localeLanguageCode = locale.language.languageCode?.identifier ?? ""
                } else {
                    localeLanguageCode = locale.languageCode ?? ""
                }
                return localeLanguageCode == preferredLanguageCode
            }) {
                guard let fallbackRecognizer = SFSpeechRecognizer(locale: fallback),
                      fallbackRecognizer.isAvailable else { return nil }
                return await performTranscription(recognizer: fallbackRecognizer, audioURL: audioURL)
            }
            return nil
        }
        
        return await performTranscription(recognizer: recognizer, audioURL: audioURL)
    }
    
    private func performTranscription(recognizer: SFSpeechRecognizer, audioURL: URL) async -> String? {
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        
        // Optimize for dictation (better for longer speech)
        request.taskHint = .dictation
        
        // Prefer on-device recognition (better privacy, often more accurate)
        // Check if on-device recognition is supported (iOS 13+)
        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        }
        
        // Don't report partial results (we want final only)
        request.shouldReportPartialResults = false
        
        // Add contextual strings to help recognition (common words in notes/journaling)
        request.contextualStrings = [
            "note", "notes", "idea", "ideas", "work", "journal", "today", "tomorrow",
            "remember", "think", "thought", "important", "meeting", "task", "todo",
            "vaulted", "inbox", "private", "voice", "recording"
        ]

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                var didResume = false
                func resumeOnce(_ value: String?) {
                    guard !didResume else { return }
                    didResume = true
                    continuation.resume(returning: value)
                }
                
                _ = recognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        // Log error for debugging but don't fail immediately
                        print("Speech recognition error: \(error.localizedDescription)")
                        // Check error domain and code (SFSpeechRecognitionError is actually NSError)
                        let nsError = error as NSError
                        if nsError.domain == "kAFAssistantErrorDomain" || nsError.domain == "com.apple.SpeechRecognition" {
                            let code = nsError.code
                            // Fail on critical errors: bad audio, unavailable engine, not available
                            if code == 216 || code == 201 || code == 209 {
                                resumeOnce(nil)
                                return
                            }
                        }
                        // Other errors might be recoverable, continue waiting
                        return
                    }
                    
                    if let result = result, result.isFinal {
                        // Use best transcription and clean it up
                        let text = result.bestTranscription.formattedString
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "  ", with: " ") // Remove double spaces
                        
                        resumeOnce(text.isEmpty ? nil : text)
                    }
                }
                
                // Increase timeout for longer recordings (up to 30 seconds)
                Task {
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    if !didResume {
                        resumeOnce(nil)
                    }
                }
            }
        } onCancel: {
            // Task cancelled
        }
    }
}
