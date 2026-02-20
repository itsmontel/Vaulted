import Foundation
import NaturalLanguage

// MARK: - BulletizedResult
/// Structured output: semantically grouped bullets + flat plain-text version.
struct BulletizedResult {
    enum Group: String, CaseIterable {
        case ideas     = "Ideas"
        case actions   = "Actions"
        case keyPoints = "Key Points"
        case notes     = "Notes"
    }

    struct GroupedBullets {
        let group:   Group
        let bullets: [String]
    }

    let groups:    [GroupedBullets]
    let plainText: String

    var allBullets: [String]  { groups.flatMap(\.bullets) }
    var hasGroups:  Bool      { groups.count > 1 }
    var isEmpty:    Bool      { groups.isEmpty }
}

// MARK: - TranscriptBulletizer
/// Flagship on-device extraction engine.
/// No network, no ML model download — pure NaturalLanguage + heuristics, < 100 ms.
///
/// Pipeline:
///   1. Deep clean  — fillers, hedges, discourse markers, normalization
///   2. Sentence tokenization — NLTokenizer
///   3. Compound-clause splitting — "…and we should also…" → two atomic clauses
///   4. TF-IDF + position + entity + action + deadline scoring per clause
///   5. Adaptive top-N selection scaled to transcript length
///   6. Phrase condensation — strip subject + modals, POS-guided verb extraction
///   7. Semantic deduplication — stopword-filtered Jaccard ≥ 0.60
///   8. Semantic classification — Actions / Ideas / Key Points / Notes
struct TranscriptBulletizer {

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Public API
    // ─────────────────────────────────────────────────────────────────────────

    static func bulletizeStructured(_ text: String) -> BulletizedResult {
        let cleaned = deepClean(text)
        guard cleaned.count >= 12 else {
            return singleBulletResult(cleaned.isEmpty ? text : cleaned)
        }

        let sentences = tokenizeSentences(cleaned)
        guard !sentences.isEmpty else { return singleBulletResult(cleaned) }

        // Extract numbered/bulleted list items from text (1. X, 2. Y, • Z)
        let listItems = extractListItems(cleaned)
        // Split compound sentences → atomic clauses
        var clauses = sentences.flatMap { splitIntoClauses($0) }
        // Prepend list items so they get scored and deduped with the rest (list items are high signal)
        if !listItems.isEmpty {
            clauses = listItems + clauses
        }

        // Compute corpus-level IDF for salience
        let idf = computeIDF(clauses)

        // Score every clause
        let scored = clauses.enumerated().map { idx, clause in
            scoreClause(clause, index: idx, total: clauses.count, idf: idf)
        }

        // Pick top-N adaptively
        let wc     = cleaned.split(separator: " ").count
        let target = adaptiveBulletCount(wordCount: wc)
        let selected = selectTopClauses(scored, target: target)

        // Condense each selected clause into a crisp phrase
        var bullets = selected.map { condenseToBullet($0.clause) }.filter { !$0.isEmpty }

        // Semantic deduplication, then merge near-duplicates (keep longer/more specific)
        bullets = deduplicate(bullets)
        bullets = mergeNearDuplicates(bullets)

        // Classify into groups
        let groups = classify(bullets)

        let plain = groups.flatMap(\.bullets).map { "• \($0)" }.joined(separator: "\n")
        return BulletizedResult(groups: groups, plainText: plain)
    }

    static func bulletize(_ text: String) -> String {
        bulletizeStructured(text).plainText
    }

    static func bulletizeAsync(_ text: String) async throws -> String {
        await Task.detached(priority: .userInitiated) { bulletize(text) }.value
    }

    static func bulletizeStructuredAsync(_ text: String) async throws -> BulletizedResult {
        await Task.detached(priority: .userInitiated) { bulletizeStructured(text) }.value
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Step 1 — Deep Clean
    // ─────────────────────────────────────────────────────────────────────────

    private static let fillerWords: Set<String> = [
        "um", "uh", "er", "hmm", "ah", "oh", "eh",
        "like", "basically", "literally", "honestly", "actually",
        "obviously", "clearly", "definitely", "totally", "absolutely",
        "certainly", "really", "seriously", "genuinely", "essentially",
        "generally", "supposedly", "apparently"
    ]

    private static let fillerPhrases: [String] = [
        "you know what i mean", "you know what", "i mean like",
        "sort of kind of", "kind of sort of", "you know", "i mean",
        "i guess", "i think like", "sort of", "kind of", "in a way",
        "in a sense", "at the end of the day", "the thing is",
        "long story short", "to be honest", "to be fair", "to be clear",
        "to tell you the truth", "truth be told", "believe it or not",
        "needless to say", "as i was saying", "anyway so",
        "okay so", "alright so", "right so", "so anyway", "so yeah",
        "yeah so", "so like", "like so", "okay yeah", "alright yeah",
        "right yeah", "okay okay", "alright alright"
    ]

    static func deepClean(_ raw: String) -> String {
        var t = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            // Normalize smart quotes / dashes
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: " - ")

        // Multi-word fillers first (longest-first prevents partial matches)
        for phrase in fillerPhrases.sorted(by: { $0.count > $1.count }) {
            let pattern = "(?i)\\b\(NSRegularExpression.escapedPattern(for: phrase))\\b"
            if let re = try? NSRegularExpression(pattern: pattern) {
                t = re.stringByReplacingMatches(in: t,
                                                range: NSRange(t.startIndex..., in: t),
                                                withTemplate: " ")
            }
        }

        // Single-word fillers
        for word in fillerWords {
            let pattern = "(?i)\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            if let re = try? NSRegularExpression(pattern: pattern) {
                t = re.stringByReplacingMatches(in: t,
                                                range: NSRange(t.startIndex..., in: t),
                                                withTemplate: " ")
            }
        }

        // Collapse whitespace
        t = t.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
             .trimmingCharacters(in: .whitespaces)
        return t
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Step 2 — Sentence Tokenization
    // ─────────────────────────────────────────────────────────────────────────

    private static let minClauseWords = 4

    private static func tokenizeSentences(_ text: String) -> [String] {
        let words  = text.split(separator: " ")
        let capped = words.count > 3_000
            ? words.prefix(3_000).joined(separator: " ")
            : text

        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = capped
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: capped.startIndex..<capped.endIndex) { range, _ in
            let s = String(capped[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if wordCount(s) >= minClauseWords { sentences.append(s) }
            return true
        }

        if sentences.isEmpty {
            sentences = capped
                .components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { wordCount($0) >= minClauseWords }
        }
        return sentences
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Step 2b — List Item Extraction
    // ─────────────────────────────────────────────────────────────────────────
    /// Pull out "1. …", "2. …", "• …" style items so they become first-class bullets.
    private static func extractListItems(_ text: String) -> [String] {
        var items: [String] = []
        // Split on numbered list markers: " 1. " " 2) " etc
        let numSplitPattern = #"\s*\d+[.)]\s+"#
        guard let numRe = try? NSRegularExpression(pattern: numSplitPattern) else { return [] }
        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let numMatches = numRe.matches(in: text, options: [], range: fullRange)
        if !numMatches.isEmpty {
            for (i, m) in numMatches.enumerated() {
                let start = m.range.location + m.range.length
                let end = (i + 1 < numMatches.count) ? numMatches[i + 1].range.location : ns.length
                let segRange = NSRange(location: start, length: end - start)
                if segRange.length > 0, let r = Range(segRange, in: text) {
                    let seg = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if wordCount(seg) >= minClauseWords { items.append(seg) }
                }
            }
            return items
        }
        // Bullet • or - at line start
        let bulletPattern = #"(?m)^\s*[•\-]\s+(.+?)(?=\n|$)"#
        if let bulletRe = try? NSRegularExpression(pattern: bulletPattern, options: .dotMatchesLineSeparators) {
            bulletRe.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                guard let m = match, m.numberOfRanges >= 2, let r = Range(m.range(at: 1), in: text) else { return }
                let seg = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                if wordCount(seg) >= minClauseWords { items.append(seg) }
            }
        }
        return items
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Step 3 — Compound Clause Splitting
    // ─────────────────────────────────────────────────────────────────────────
    //
    // Voice transcripts are full of run-on sentences like:
    //   "we need to update the onboarding and also add a dark mode toggle and remind me to send the proposal"
    //
    // Splitting on conjunction + new subject/verb patterns yields 3 atomic clauses instead of 1,
    // which is the single biggest quality improvement for generating more bullets.

    private static let splitPatterns: [String] = [
        // "…and also we/I/you…" or "…and also <verb>…"
        #"(?i)\s+and\s+also\s+"#,
        #"(?i)\s+and\s+then\s+(we\s+|i\s+|you\s+|they\s+)?"#,
        #"(?i)\s+and\s+(we|i|you|they)\s+(need\s+to|should|want\s+to|will|have\s+to|going\s+to|plan\s+to)\s+"#,
        #"(?i)\s+but\s+(we|i|you|they)\s+(need\s+to|should|want\s+to|have\s+to)\s+"#,
        #"(?i)\s+plus\s+(we|i|you|they)\s+"#,
        #"(?i),?\s+also\s+(we|i|you|they)\s+(should|need\s+to|want\s+to|can)\s+"#,
        #";\s*"#,
        #"(?i),\s+and\s+(also\s+)?"#,
        // First / second / third / finally — strong list boundaries
        #"(?i)\s+(second(?:ly)?|third(?:ly)?|fourth(?:ly)?|finally|last(?:ly)?)\s+"#,
        #"(?i)\s+first(?:ly)?\s+"#,
        // "one more thing", "another thing", "also important"
        #"(?i)\s+(one\s+more\s+thing|another\s+thing|one\s+thing\s+more)\s*[,:]?\s+"#,
        #"(?i)\s+also\s+important\s*[,:]?\s+"#,
        // Em dash or colon introducing new thought
        #"\s+[—–]\s+"#,
        #"(?i)\s+:\s+(?:we|i|you|they|to)\s+"#,
    ]

    private static let compiledSplitRegexes: [NSRegularExpression] = {
        splitPatterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    private static func splitIntoClauses(_ sentence: String) -> [String] {
        var clauses = [sentence]

        for regex in compiledSplitRegexes {
            var next: [String] = []
            for clause in clauses {
                let nsRange = NSRange(clause.startIndex..., in: clause)
                if let match = regex.firstMatch(in: clause, range: nsRange),
                   let swiftRange = Range(match.range, in: clause) {
                    let left  = String(clause[..<swiftRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let right = String(clause[swiftRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if wordCount(left)  >= minClauseWords { next.append(left) }
                    if wordCount(right) >= minClauseWords { next.append(right) }
                } else {
                    next.append(clause)
                }
            }
            clauses = next
        }

        return clauses.filter { wordCount($0) >= minClauseWords }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Step 4 — Scoring
    // ─────────────────────────────────────────────────────────────────────────

    private static let stopwords: Set<String> = [
        "the","a","an","and","or","but","in","on","at","to","for",
        "of","with","as","by","from","that","this","these","those",
        "it","its","i","we","you","they","he","she","what","which",
        "who","is","are","was","were","be","been","being","have",
        "has","had","do","does","did","will","would","shall","should",
        "may","might","must","can","could","not","no","nor","so",
        "yet","both","either","neither","my","our","your","their",
        "his","her","its","there","here","then","than","when","where",
        "just","also","about","after","before","over","under","up",
        "down","out","if","how","get","got","let","make","go","going",
        "come","know","want","need","very","some","any","all","each",
        "every","more","most","much","many","few","less","only","even",
        "still","already","back","away"
    ]

    private struct ScoredClause {
        let clause:        String
        let originalIndex: Int
        var score:         Double
    }

    private static func computeIDF(_ clauses: [String]) -> [String: Double] {
        let n = Double(clauses.count)
        guard n > 0 else { return [:] }
        var df: [String: Int] = [:]
        for clause in clauses {
            for word in Set(tokenWords(clause)) { df[word, default: 0] += 1 }
        }
        return df.mapValues { log((n + 1.0) / (Double($0) + 1.0)) + 1.0 }
    }

    private static let urgencyTerms: Set<String> = [
        "today","tomorrow","asap","urgent","immediately","tonight",
        "monday","tuesday","wednesday","thursday","friday","saturday","sunday",
        "deadline","eod","week","morning","afternoon","evening",
        "january","february","march","april","june","july",
        "august","september","october","november","december"
    ]

    private static let actionVerbs: Set<String> = [
        "update","add","remove","delete","fix","create","build","launch","ship",
        "send","call","email","contact","schedule","book","arrange","prepare",
        "write","review","check","verify","test","deploy","design","redesign",
        "refactor","organize","research","find","hire","interview","onboard",
        "train","present","share","upload","sync","backup","migrate","integrate",
        "publish","post","announce","confirm","approve","complete","finish",
        "start","begin","cancel","close","follow","remind","notify","setup",
        "configure","install","buy","purchase","order","reply","respond","ping",
        "reach","move","change","improve","enhance","simplify","streamline"
    ]

    private static func scoreClause(_ clause: String,
                                     index: Int,
                                     total: Int,
                                     idf: [String: Double]) -> ScoredClause {
        var score: Double = 0.0
        let words   = tokenWords(clause)
        let lower   = clause.lowercased()
        let wordSet = Set(words)

        // TF-IDF — content words with rare/salient terms score higher
        let contentWords = words.filter { !stopwords.contains($0) }
        score += contentWords.reduce(0.0) { $0 + (idf[$1] ?? 1.0) } * 0.45

        // Position — early ideas + end-of-note summaries are both important
        let pos = Double(index) / Double(max(total - 1, 1))
        if      pos < 0.20 { score += 4.0 }
        else if pos < 0.40 { score += 2.0 }
        else if pos < 0.60 { score += 0.5 }
        else if pos > 0.85 { score += 1.5 }

        // Urgency / deadline
        let urgencyHits = wordSet.intersection(urgencyTerms).count
        score += Double(urgencyHits) * 4.0

        // "by [day]" pattern
        if lower.range(of: #"\bby\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|tomorrow|eod|end)\b"#,
                       options: .regularExpression) != nil {
            score += 5.0
        }

        // Action verbs
        score += Double(wordSet.intersection(actionVerbs).count) * 2.5

        // Named entities
        score += Double(countNamedEntities(clause)) * 2.0

        // Length sweet spot
        let wc = words.count
        if      wc >= 6  && wc <= 22 { score += 2.0 }
        else if wc < 4              { score -= 2.5 }
        else if wc > 40             { score -= 1.0 }

        // Questions: downweight unless they look like key decisions (contain action/idea terms)
        if clause.hasSuffix("?") {
            let questionContent = wordSet.intersection(actionVerbs).count + wordSet.intersection(ideaSignals).count
            if questionContent == 0 { score -= 2.0 }
            else { score += 0.5 }
        }

        // Explicit task markers
        if lower.contains("remind me") || lower.contains("don't forget") || lower.contains("make sure") {
            score += 3.5
        }

        // Summary / key-point lead-ins — treat as high importance
        let summaryLead = ["bottom line", "the main point", "main point is", "key takeaway", "in summary", "to summarize", "tl;dr", "in short", "the point is", "what matters is", "most importantly"]
        if summaryLead.contains(where: { lower.contains($0) }) { score += 6.0 }

        // Meta / filler lead — downweight
        let metaLead = ["as i said", "as i mentioned", "like i said", "i was just saying", "going back to", "anyway"]
        if metaLead.contains(where: { lower.hasPrefix($0) || lower.contains(" " + $0) }) { score -= 4.0 }

        // Heavy stopword ratio → filler clause
        let stopRatio = Double(words.count - contentWords.count) / Double(max(words.count, 1))
        if stopRatio > 0.80 { score -= 3.0 }

        return ScoredClause(clause: clause, originalIndex: index, score: score)
    }

    private static func countNamedEntities(_ text: String) -> Int {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var count = 0
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                              unit: .word, scheme: .nameType,
                              options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, _ in
            if let t = tag, t != .other { count += 1 }
            return true
        }
        return count
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Step 5 — Adaptive Selection
    // ─────────────────────────────────────────────────────────────────────────

    /// Bullet count by transcript length: ≥100 words → at least 3 bullets; short notes (100–200w) in 3–7 range; cap at 15.
    private static func adaptiveBulletCount(wordCount: Int) -> Int {
        if wordCount < 100 {
            return max(1, min(2, wordCount / 50))
        }
        let target = wordCount / 25
        return min(15, max(3, target))
    }

    /// Minimum score to include a clause (drops pure filler).
    private static let minClauseScore = -2.0

    private static func selectTopClauses(_ scored: [ScoredClause], target: Int) -> [ScoredClause] {
        let aboveThreshold = scored.filter { $0.score >= minClauseScore }.sorted { $0.score > $1.score }
        let take: [ScoredClause]
        if aboveThreshold.count >= target {
            take = Array(aboveThreshold.prefix(target))
        } else if target >= 3 && aboveThreshold.count < 3 {
            take = Array(scored.sorted { $0.score > $1.score }.prefix(max(3, target)))
        } else {
            take = Array(aboveThreshold.prefix(target))
        }
        return take.sorted { $0.originalIndex < $1.originalIndex }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Step 6 — Phrase Condensation
    // ─────────────────────────────────────────────────────────────────────────

    /// Ordered by length so the longest (most specific) prefix is matched first.
    private static let subjectPhrases: [String] = ([
        // We + modal combos
        "we are going to ", "we're going to ", "we need to ", "we should ",
        "we have to ", "we want to ", "we could ", "we can ", "we will ",
        "we'll ", "we must ", "we plan to ", "we're planning to ",
        "we're trying to ", "we'd like to ",
        // I + modal combos
        "i am going to ", "i'm going to ", "i need to ", "i should ",
        "i have to ", "i want to ", "i could ", "i can ", "i will ",
        "i'll ", "i must ", "i plan to ", "i'm planning to ",
        "i'm trying to ", "i'd like to ",
        // You
        "you need to ", "you should ", "you have to ", "you want to ", "you can ",
        // Impersonal
        "it's important to ", "it is important to ",
        "it would be good to ", "it would be great to ",
        "it would help to ", "it might be good to ",
        "there is a need to ", "there's a need to ",
        "one thing we need to ", "one thing i need to ",
        // Directive imperatives that survived cleaning
        "let's make sure to ", "let's make sure we ", "let's make sure ",
        "make sure to ", "make sure we ", "make sure ",
        "remember to ", "remind me to ", "don't forget to ", "don't forget ",
        "be sure to ", "be sure we ",
        // Bare modals left over after conjunction stripping
        "need to ", "have to ", "should ", "must ", "want to ", "going to ",
        "planning to ", "trying to ", "hoping to ", "would like to ",
        // Leftover discourse connectors and hedges
        "so ", "and ", "but ", "then ", "also ", "now ", "well ",
        "the thing is ", "so basically ", "basically ", "i think ",
    ] as [String]).sorted { $0.count > $1.count }

    private static let maxBulletWords = 18

    static func condenseToBullet(_ clause: String) -> String {
        var s = clause.trimmingCharacters(in: .whitespacesAndNewlines)

        // Drop trailing subordinate clauses: ", which is…", ", and that…", ", so that…"
        let trailingSubord = [
            #",\s+which\s+.+$"#, #",\s+and\s+that\s+.+$"#, #",\s+so\s+that\s+.+$"#,
            #",\s+because\s+.+$"#, #",\s+although\s+.+$"#, #",\s+if\s+.+$"#
        ]
        for pattern in trailingSubord {
            if let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
               let r = Range(m.range, in: s) {
                s = String(s[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                if wordCount(s) < 3 { break }
            }
        }

        // Strip trailing weak punctuation
        let weakEnds = CharacterSet(charactersIn: ".,:;-–—")
        while let last = s.unicodeScalars.last, weakEnds.contains(last) {
            s = String(s.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        // Progressive subject/modal stripping until stable
        var changed = true
        while changed {
            changed = false
            let lower = s.lowercased()
            for subject in subjectPhrases {
                if lower.hasPrefix(subject) {
                    let candidate = String(s.dropFirst(subject.count)).trimmingCharacters(in: .whitespaces)
                    if wordCount(candidate) >= 2 {
                        s = candidate
                        changed = true
                        break
                    }
                }
            }
        }

        // Strip leading articles only when result is still meaningful
        let articlePrefixes = ["the ", "a ", "an "]
        let sLower = s.lowercased()
        for art in articlePrefixes where sLower.hasPrefix(art) {
            let candidate = String(s.dropFirst(art.count)).trimmingCharacters(in: .whitespaces)
            if wordCount(candidate) >= 2 { s = candidate; break }
        }

        // Capitalize first character
        if let first = s.unicodeScalars.first {
            s = String(first).uppercased() + String(s.dropFirst())
        }

        // Hard cap at maxBulletWords — find a clean break
        var words = s.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if words.count > maxBulletWords {
            words = Array(words.prefix(maxBulletWords))
            // Remove trailing weak words so bullet ends strongly
            let weakTrail = Set(["and","or","but","the","a","an","to","in","on","at","with","for","of","by"])
            while let last = words.last, weakTrail.contains(last.lowercased()), words.count > 4 {
                words.removeLast()
            }
            s = words.joined(separator: " ") + "…"
        } else {
            s = words.joined(separator: " ")
        }

        return wordCount(s) >= 2 ? s : ""
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Step 7 — Semantic Deduplication
    // ─────────────────────────────────────────────────────────────────────────

    private static func deduplicate(_ bullets: [String]) -> [String] {
        var kept:         [String]   = []
        var fingerprints: [[String]] = []

        for bullet in bullets {
            let fp = contentFingerprint(bullet)
            let isDuplicate = fingerprints.contains { existing in
                guard !fp.isEmpty, !existing.isEmpty else { return fp == existing }
                let a = Set(fp), b = Set(existing)
                let inter = Double(a.intersection(b).count)
                let union  = Double(a.union(b).count)
                if union > 0 && (inter / union) >= 0.60 { return true }
                // Containment check: one is mostly contained in the other
                if Double(a.intersection(b).count) / Double(max(a.count, 1)) >= 0.80 { return true }
                if Double(a.intersection(b).count) / Double(max(b.count, 1)) >= 0.80 { return true }
                return false
            }
            if !isDuplicate {
                kept.append(bullet)
                fingerprints.append(fp)
            }
        }
        return kept
    }

    private static func contentFingerprint(_ text: String) -> [String] {
        tokenWords(text).filter { !stopwords.contains($0) }
    }

    /// Bigrams for stricter similarity (catches "send proposal" vs "send client proposal").
    private static func contentBigrams(_ text: String) -> Set<String> {
        let words = contentFingerprint(text)
        var bigrams: Set<String> = []
        for i in 0..<(words.count - 1) {
            bigrams.insert("\(words[i]) \(words[i+1])")
        }
        return bigrams
    }

    /// When two bullets are near-duplicates, keep the longer (more specific) one.
    private static func mergeNearDuplicates(_ bullets: [String]) -> [String] {
        var kept: [String] = []
        for bullet in bullets {
            var merged = false
            for (idx, existing) in kept.enumerated() {
                let fp = Set(contentFingerprint(bullet))
                let existingFp = Set(contentFingerprint(existing))
                let jaccard = Double(fp.intersection(existingFp).count) / Double(max(fp.union(existingFp).count, 1))
                let bigrams = contentBigrams(bullet)
                let existingBigrams = contentBigrams(existing)
                let bigramOverlap = (bigrams.isEmpty && existingBigrams.isEmpty) ? jaccard
                    : Double(bigrams.intersection(existingBigrams).count) / Double(max(bigrams.union(existingBigrams).count, 1))
                if jaccard >= 0.70 || bigramOverlap >= 0.65 {
                    kept[idx] = bullet.count > existing.count ? bullet : existing
                    merged = true
                    break
                }
            }
            if !merged { kept.append(bullet) }
        }
        return kept
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Step 8 — Classification
    // ─────────────────────────────────────────────────────────────────────────

    private static let actionSignals: Set<String> = [
        "update","add","remove","delete","fix","create","build","launch","ship",
        "send","call","email","contact","schedule","book","arrange","prepare",
        "write","review","check","verify","test","deploy","design","redesign",
        "follow","confirm","approve","complete","finish","start","cancel",
        "close","publish","post","upload","remind","notify","setup","configure",
        "buy","purchase","order","reply","respond","ping","reach","move","change",
        "hire","fire","promote","present","announce","invite","decline","accept"
    ]

    private static let ideaSignals: Set<String> = [
        "idea","concept","think","thought","imagine","vision","could","might",
        "what if","maybe","perhaps","feature","experiment","prototype","try",
        "explore","investigate","consider","potential","opportunity",
        "redesign","rethink","reframe","new","different","better","improve",
        "enhance","streamline","automate","suggest","proposal"
    ]

    private static let keyPointSignals: Set<String> = [
        "important","critical","key","main","core","essential","priority","must",
        "crucial","significant","fundamental","primary","major","biggest","top",
        "focus","goal","target","objective","requirement","rule","principle",
        "insight","lesson","learning","takeaway","summary","note","remember",
        "bottom","point","matters","takeaway","tl;dr","recap","overall"
    ]

    /// Phrases that strongly indicate a summary / key-point sentence.
    private static let summaryPhrases: Set<String> = [
        "bottom line", "main point", "key takeaway", "in summary", "to summarize",
        "in short", "the point is", "what matters", "most importantly", "above all"
    ]

    private static func classify(_ bullets: [String]) -> [BulletizedResult.GroupedBullets] {
        var actions:   [String] = []
        var ideas:     [String] = []
        var keyPoints: [String] = []
        var notes:     [String] = []

        for bullet in bullets {
            let words = Set(tokenWords(bullet.lowercased()))
            let bulletLower = bullet.lowercased()

            var actionScore   = Double(words.intersection(actionSignals).count)   * 2.0
            var ideaScore     = Double(words.intersection(ideaSignals).count)     * 2.0
            var keyScore      = Double(words.intersection(keyPointSignals).count) * 2.0

            // Summary phrase in bullet → Key Points
            if summaryPhrases.contains(where: { bulletLower.contains($0) }) { keyScore += 5.0 }

            // Imperative / verb-first bullet → strong action signal
            if isFirstWordActionVerb(bullet) { actionScore += 3.0 }

            // Urgency → action
            let urgencyHits = words.intersection(urgencyTerms).count
            actionScore += Double(urgencyHits) * 2.0

            let scores: [(BulletizedResult.Group, Double)] = [
                (.actions, actionScore), (.ideas, ideaScore), (.keyPoints, keyScore)
            ]

            if let winner = scores.max(by: { $0.1 < $1.1 }), winner.1 > 0 {
                switch winner.0 {
                case .actions:   actions.append(bullet)
                case .ideas:     ideas.append(bullet)
                case .keyPoints: keyPoints.append(bullet)
                case .notes:     notes.append(bullet)
                }
            } else {
                notes.append(bullet)
            }
        }

        var result: [BulletizedResult.GroupedBullets] = []
        if !actions.isEmpty   { result.append(.init(group: .actions,   bullets: actions))   }
        if !ideas.isEmpty     { result.append(.init(group: .ideas,     bullets: ideas))     }
        if !keyPoints.isEmpty { result.append(.init(group: .keyPoints, bullets: keyPoints)) }
        if !notes.isEmpty     { result.append(.init(group: .notes,     bullets: notes))     }

        // Fallback: if everything ungrouped, use keyPoints
        if result.count == 1, result.first?.group == .notes {
            let nb = result[0].bullets
            result = [.init(group: .keyPoints, bullets: nb)]
        }
        return result
    }

    private static func isFirstWordActionVerb(_ text: String) -> Bool {
        guard let first = text.split(separator: " ").first.map(String.init) else { return false }
        if actionVerbs.contains(first.lowercased()) { return true }
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = first
        var isVerb = false
        tagger.enumerateTags(in: first.startIndex..<first.endIndex,
                              unit: .word, scheme: .lexicalClass,
                              options: [.omitWhitespace]) { tag, _ in
            if tag == .verb { isVerb = true }
            return true
        }
        return isVerb
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Utilities
    // ─────────────────────────────────────────────────────────────────────────

    private static func tokenWords(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .flatMap { $0.components(separatedBy: CharacterSet.punctuationCharacters) }
            .map    { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func wordCount(_ text: String) -> Int {
        text.split(separator: " ").count
    }

    private static func singleBulletResult(_ text: String) -> BulletizedResult {
        let b = condenseToBullet(text)
        let bullet = b.isEmpty ? text : b
        return BulletizedResult(
            groups:    [.init(group: .notes, bullets: [bullet])],
            plainText: "• \(bullet)"
        )
    }
}

// MARK: - Debug
#if DEBUG
extension TranscriptBulletizer {
    static func runDebugTests() {
        let samples: [(String, String)] = [
            ("Mixed task dump",
             "So I was thinking about the app redesign and we need to update the onboarding flow to feel more welcoming. Also we should add a dark mode toggle in settings. And remind me to send the client proposal by Friday."),

            ("300-word work brain dump",
             "Okay so the invoice for Johnson and Associates needs to go out today and I need to follow up with Sarah about the design mockups and the deadline is next Thursday. Also we need to book the conference room for the retrospective and I should update the project tracker. The marketing team wants to announce the new feature by end of month and we should put together a press release and also reach out to the beta users for feedback. And don't forget we need to hire two more engineers so I should post the job listings on LinkedIn and also update the careers page. The onboarding needs a lot of work too we should simplify the first three steps and add some tooltips and make sure the empty state looks better. Oh and we need to review the analytics dashboard and present the Q3 numbers to the board next Wednesday."),

            ("Journal entry",
             "Today was a really good day. I went to the gym in the morning and it felt great. Had a productive meeting with the team and we mapped out the roadmap for the rest of the year. I'm feeling grateful and I want to keep this momentum going. One thing I want to work on is being more consistent with deep work blocks and not checking email until noon."),

            ("Idea burst",
             "What if we added a weekly digest email showing your best notes from the past week. And maybe a streak counter for consecutive recording days. Also think it could be cool to have a private locked drawer only accessible with Face ID. And what if users could share individual notes as beautiful images on social media."),

            ("Single sentence",
             "Don't forget to call mom tomorrow.")
        ]

        print("[TranscriptBulletizer] ══════ DEBUG ══════")
        for (label, sample) in samples {
            print("\n── \(label) (\(sample.split(separator: " ").count) words) ──")
            let r = bulletizeStructured(sample)
            for g in r.groups {
                print("  [\(g.group.rawValue)]")
                g.bullets.forEach { print("    • \($0)") }
            }
        }
        print("\n══════════════════════════════════════════")
    }
}
#endif