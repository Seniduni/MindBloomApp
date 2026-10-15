import Foundation

/// Picks the most repeated meaningful words from a list of (already tokenised) words.
/// Kept separate from `JournalAnalyzer` so the ranking rules can be tested
/// deterministically, independent of Apple's language models.
enum KeywordExtractor {
    static let minimumLength = 3

    /// Common English words that carry little meaning on their own.
    static let stopWords: Set<String> = [
        "the", "and", "for", "but", "with", "that", "this", "was", "were", "are", "have", "has",
        "had", "not", "you", "your", "they", "them", "their", "she", "his", "her", "its", "our",
        "from", "about", "into", "just", "really", "very", "much", "more", "some", "any", "all",
        "what", "when", "then", "than", "there", "here", "also", "too", "can", "could", "would",
        "should", "will", "did", "does", "doing", "been", "being", "get", "got", "today", "thing",
        "things", "lot", "bit", "way", "day", "feel", "felt", "like", "think", "know", "one",
        "time", "make", "made", "going", "still", "even", "because", "though", "myself", "kind"
    ]

    /// Lower-cases, drops short and stop words, then ranks by frequency.
    /// Ties are ordered alphabetically so the output is stable.
    static func topKeywords(from words: [String], limit: Int = 5) -> [String] {
        guard limit > 0 else { return [] }
        var counts: [String: Int] = [:]
        for raw in words {
            let word = raw.lowercased().trimmingCharacters(in: .punctuationCharacters)
            guard word.count >= minimumLength,
                  !stopWords.contains(word),
                  word.rangeOfCharacter(from: .letters) != nil else { continue }
            counts[word, default: 0] += 1
        }
        return counts
            .sorted { lhs, rhs in lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value }
            .prefix(limit)
            .map(\.key)
    }
}
