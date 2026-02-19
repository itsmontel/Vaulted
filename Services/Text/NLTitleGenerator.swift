import Foundation
import NaturalLanguage

// MARK: - Card Type Hint
enum CardTypeHint: String, CaseIterable {
    case ideas
    case work
    case journal
    case inbox
    case unknown

    static func from(systemKey: String?) -> CardTypeHint {
        guard let key = systemKey else { return .unknown }
        switch key.lowercased() {
        case "ideas": return .ideas
        case "work": return .work
        case "journal": return .journal
        case "inbox": return .inbox
        default: return .unknown
        }
    }
}

// MARK: - NL Title Generator
struct NLTitleGenerator {

    private static let fillerPhrases: Set<String> = [
        "um", "uh", "like", "you know", "basically", "literally",
        "sort of", "kind of", "i mean", "okay", "alright", "so"
    ]

    private static let stopwords: Set<String> = [
        "the", "a", "an", "and", "or", "to", "of", "in", "on", "for",
        "with", "at", "from", "this", "that", "it", "i", "we", "you", "my", "our"
    ]

    private static let workBoost: Set<String> = [
        "client", "invoice", "meeting", "deadline", "project", "email"
    ]

    private static let ideasBoost: Set<String> = [
        "idea", "app", "feature", "design", "build", "launch"
    ]

    private static let journalBoost: Set<String> = [
        "feel", "today", "grateful", "stress", "happy"
    ]

    private static let maxTitleLength = 44
    private static let analysisPrefixLength = 400
    private static let earlyBoostPrefixLength = 120
    private static let minSentenceLength = 20

    // MARK: - Public API
    static func generateTitle(
        transcript: String,
        cardTypeHint: CardTypeHint,
        fallbackDate: Date
    ) -> String {
        let cleaned = cleanTranscript(transcript)
        guard !cleaned.isEmpty else {
            return formatFallbackDate(fallbackDate)
        }
        let textForAnalysis = String(cleaned.prefix(Self.analysisPrefixLength))
        let keywords = tokenizeWithNLTagger(textForAnalysis)
        let scored = scoreTokens(keywords, text: textForAnalysis, hint: cardTypeHint)
        let title: String
        if scored.count >= 1 {
            title = buildTitleFromKeywords(scored, hint: cardTypeHint)
        } else {
            title = naturalPhraseFallback(from: cleaned, fallbackDate: fallbackDate)
        }
        return clampTitleLength(title, fallbackDate: fallbackDate)
    }

    // MARK: - A) Clean transcript
    private static func cleanTranscript(_ raw: String) -> String {
        var t = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        for phrase in fillerPhrases.sorted(by: { $0.count > $1.count }) {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: phrase) + "\\b"
            t = t.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
        }
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return t
    }

    // MARK: - B) Keyword extraction
    private static func tokenizeWithNLTagger(_ string: String) -> [(token: String, isNoun: Bool, isProperOrName: Bool, isEarly: Bool)] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = string
        let range = string.startIndex..<string.endIndex
        let earlyCutoff = string.index(string.startIndex, offsetBy: min(Self.earlyBoostPrefixLength, string.count), limitedBy: string.endIndex) ?? string.startIndex
        var results: [(token: String, isNoun: Bool, isProperOrName: Bool, isEarly: Bool)] = []
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, tokenRange in
            let word = String(string[tokenRange])
            let lower = word.lowercased()
            if word.count < 2 && lower != "ui" && lower != "api" { return true }
            if stopwordFilter(lower) { return true }
            let isNoun: Bool
            if let tag = tag {
                isNoun = (tag == .noun)
            } else {
                isNoun = false
            }
            var isProperOrName = false
            if let nameTag = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .nameType).0 {
                if nameTag == .personalName || nameTag == .placeName || nameTag == .organizationName {
                    isProperOrName = true
                }
            }
            let isEarly = tokenRange.lowerBound < earlyCutoff
            results.append((word, isNoun, isProperOrName, isEarly))
            return true
        }
        return results
    }

    static func stopwordFilter(_ lowercasedWord: String) -> Bool {
        Self.stopwords.contains(lowercasedWord) || Self.fillerPhrases.contains(lowercasedWord)
    }

    private static func scoreTokens(
        _ tokens: [(token: String, isNoun: Bool, isProperOrName: Bool, isEarly: Bool)],
        text: String,
        hint: CardTypeHint
    ) -> [(word: String, score: Double)] {
        var counts: [String: (count: Int, isNoun: Bool, isProperOrName: Bool, isEarly: Bool)] = [:]
        for t in tokens {
            let key = t.token.lowercased()
            if key.count < 3 && key != "ui" && key != "api" { continue }
            if stopwordFilter(key) { continue }
            let existing = counts[key] ?? (0, false, false, false)
            counts[key] = (
                existing.count + 1,
                existing.isNoun || t.isNoun,
                existing.isProperOrName || t.isProperOrName,
                existing.isEarly || t.isEarly
            )
        }
        let boostSet: Set<String>
        switch hint {
        case .work: boostSet = workBoost
        case .ideas: boostSet = ideasBoost
        case .journal: boostSet = journalBoost
        default: boostSet = []
        }
        return counts.map { key, val in
            var score = Double(val.count)
            if val.isEarly { score += 1.5 }
            if val.isProperOrName { score += 2.0 }
            if val.isNoun { score += 0.8 }
            if boostSet.contains(key) { score += 1.2 }
            let original = tokens.first(where: { $0.token.lowercased() == key })?.token ?? key
            return (word: original.capitalized, score: score)
        }
        .sorted(by: { $0.score > $1.score })
    }

    private static func buildTitleFromKeywords(_ scored: [(word: String, score: Double)], hint: CardTypeHint) -> String {
        let top = Array(scored.prefix(4)).map(\.word)
        switch hint {
        case .work:
            return "Work: " + (top.prefix(2).joined(separator: " "))
        case .ideas:
            return "Idea: " + (top.prefix(2).joined(separator: " "))
        case .journal:
            return "Journal: " + (top.prefix(2).joined(separator: " "))
        default:
            return top.prefix(3).joined(separator: " ")
        }
    }

    // MARK: - D) Natural phrase fallback
    private static func naturalPhraseFallback(from cleaned: String, fallbackDate: Date) -> String {
        let sentences = cleaned.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var source = sentences.first ?? cleaned
        if source.count < Self.minSentenceLength, sentences.count > 1 {
            source = (sentences.prefix(2).joined(separator: ". ") + ".").trimmingCharacters(in: .whitespaces)
        }
        let words = source.components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { !stopwordFilter($0) && $0.count >= 2 }
        let phrase = words.prefix(7).joined(separator: " ")
        let result = phrase.isEmpty ? "" : (String(phrase.prefix(1)).uppercased() + phrase.dropFirst())
        if result.isEmpty || isTooGeneric(result) {
            return formatFallbackDate(fallbackDate)
        }
        return String(result)
    }

    private static func isTooGeneric(_ title: String) -> Bool {
        let lower = title.lowercased()
        let generic = ["today", "okay", "voice note", "new card", "untitled"]
        return generic.contains { lower == $0 || lower.hasPrefix($0 + " ") }
    }

    // MARK: - E) Output polishing
    static func clampTitleLength(_ title: String, fallbackDate: Date) -> String {
        let t = title.trimmingCharacters(in: .whitespaces)
        if t.isEmpty || isTooGeneric(t) {
            return formatFallbackDate(fallbackDate)
        }
        if t.count <= Self.maxTitleLength { return t }
        let index = t.index(t.startIndex, offsetBy: Self.maxTitleLength, limitedBy: t.endIndex) ?? t.endIndex
        var last = t[..<index].lastIndex(of: " ") ?? index
        if t.distance(from: t.startIndex, to: last) < 20 {
            last = index
        }
        let trimmed = String(t[..<last]).trimmingCharacters(in: .whitespaces)
        return trimmed + "…"
    }

    static func formatFallbackDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Voice note • " + formatter.string(from: date)
    }
}

// MARK: - Debug test harness
#if DEBUG
extension NLTitleGenerator {
    static func runDebugTests() {
        let cases: [(String, CardTypeHint)] = [
            ("um okay so i need to invoice the client tomorrow morning and send the draft", .work),
            ("what if we make the drawer view weekly with a private locked drawer", .ideas),
            ("today i felt really good after the gym and i want to keep it consistent", .journal),
            ("random note with no clear keywords", .inbox),
        ]
        print("[NLTitleGenerator] Debug titles:")
        for (transcript, hint) in cases {
            let title = generateTitle(transcript: transcript, cardTypeHint: hint, fallbackDate: Date())
            print("  hint=\(hint) => \"\(title)\"")
        }
    }
}
#endif
