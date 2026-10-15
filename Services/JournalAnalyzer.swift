import Foundation
import NaturalLanguage

/// What the on-device analysis found in a journal entry.
///
/// These are *approximate, language-based observations*. Apple's built-in
/// sentiment model scores the wording of text; it does not understand context,
/// sarcasm or the writer's situation, and it is not a clinical assessment.
struct JournalObservation: Equatable, Sendable {
    enum Tone: String, Sendable {
        case leaningPositive, mixedOrNeutral, leaningNegative

        var label: String {
            switch self {
            case .leaningPositive: "Wording leans positive"
            case .mixedOrNeutral: "Wording is mixed or neutral"
            case .leaningNegative: "Wording leans heavy"
            }
        }
    }

    let wordCount: Int
    /// -1 (negative wording) … +1 (positive wording); nil when unavailable for the language.
    let sentimentScore: Double?
    let tone: Tone?
    let keywords: [String]
    /// BCP-47 code of the detected language, e.g. "en".
    let languageCode: String?
    /// True when the entry is long enough for an observation to be meaningful.
    let hasEnoughText: Bool
}

/// Runs Apple's NaturalLanguage framework entirely on the device. No text is
/// sent anywhere and no model is trained by this app.
struct JournalAnalyzer {
    static let minimumWords = 8
    static let positiveThreshold = 0.2
    static let negativeThreshold = -0.2

    /// Languages for which Apple documents sentiment support. Other languages still
    /// get word counts and keywords, but no tone.
    static let sentimentLanguages: Set<NLLanguage> = [.english, .french, .german, .italian, .portuguese, .spanish]

    func analyze(_ text: String) -> JournalObservation {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = Self.words(in: trimmed)
        guard words.count >= Self.minimumWords else {
            return JournalObservation(wordCount: words.count, sentimentScore: nil, tone: nil,
                                      keywords: [], languageCode: nil, hasEnoughText: false)
        }

        let language = NLLanguageRecognizer.dominantLanguage(for: trimmed)
        var score: Double?
        if let language, Self.sentimentLanguages.contains(language) {
            score = Self.sentiment(of: trimmed)
        }
        return JournalObservation(wordCount: words.count,
                                  sentimentScore: score,
                                  tone: score.map(Self.tone(for:)),
                                  keywords: Self.keywords(in: trimmed),
                                  languageCode: language?.rawValue,
                                  hasEnoughText: true)
    }

    static func tone(for score: Double) -> JournalObservation.Tone {
        if score >= positiveThreshold { return .leaningPositive }
        if score <= negativeThreshold { return .leaningNegative }
        return .mixedOrNeutral
    }

    static func words(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex).map { String(text[$0]) }
    }

    /// Paragraph-level sentiment, averaged and weighted by paragraph length.
    static func sentiment(of text: String) -> Double? {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        var weightedTotal = 0.0
        var totalWeight = 0.0
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .paragraph,
                             scheme: .sentimentScore, options: []) { tag, range in
            if let raw = tag?.rawValue, let value = Double(raw) {
                let weight = Double(text[range].count)
                weightedTotal += value * weight
                totalWeight += weight
            }
            return true
        }
        guard totalWeight > 0 else { return nil }
        return max(-1, min(1, weightedTotal / totalWeight))
    }

    /// Nouns and adjectives (lemmatised where possible), ranked by `KeywordExtractor`.
    static func keywords(in text: String, limit: Int = 5) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text
        var candidates: [String] = []
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word,
                             scheme: .lexicalClass, options: options) { tag, range in
            if tag == .noun || tag == .adjective {
                let lemma = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue
                candidates.append(lemma ?? String(text[range]))
            }
            return true
        }
        return KeywordExtractor.topKeywords(from: candidates, limit: limit)
    }
}
