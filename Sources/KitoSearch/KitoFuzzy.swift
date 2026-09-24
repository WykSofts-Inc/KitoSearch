//
//  KitoFuzzy.swift
//  KitoSearch
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// How well a query matched a piece of text, and which characters matched.
///
/// `ranges` are character offsets into the original text (not `String.Index`), so they survive
/// being stored, compared in tests and handed to `KitoHighlightedText`.
public struct KitoFuzzyMatch: Equatable, Hashable, Sendable {
    /// 0…1. An exact prefix scores 1; a typo or a scattered match scores lower.
    public let score: Double
    /// Matched character ranges, sorted and merged.
    public let ranges: [Range<Int>]

    public init(score: Double, ranges: [Range<Int>]) {
        self.score = score
        self.ranges = KitoFuzzy.merged(ranges)
    }
}

/// One item that survived `KitoFuzzy.filter`, with how it matched.
public struct KitoFuzzyResult<Item> {
    public let item: Item
    public let match: KitoFuzzyMatch

    public init(item: Item, match: KitoFuzzyMatch) {
        self.item = item
        self.match = match
    }
}

extension KitoFuzzyResult: Sendable where Item: Sendable {}
extension KitoFuzzyResult: Equatable where Item: Equatable {}

/// Typo-tolerant matching for local search.
///
/// Matching runs in three passes, best first:
/// 1. the whole query as one run of characters ("nya" in "Nyama Mama");
/// 2. word by word, where each query word must start, sit inside, or be a small typo away from
///    a word in the text ("java kil" in "Java House Kilimani", "resturant" in "Restaurant");
/// 3. the query's letters in order anywhere in the text ("jhk" in "Java House Kilimani").
///
/// Case and accents are ignored, so "cafe" finds "Café".
public enum KitoFuzzy {

    /// Scores `query` against `text`, or returns `nil` when it doesn't match at all.
    public static func match(_ query: String, in text: String) -> KitoFuzzyMatch? {
        let needle = trimmed(normalized(query))
        let haystack = normalized(text)
        guard !needle.isEmpty, !haystack.isEmpty else { return nil }

        if let exact = contiguousMatch(needle, in: haystack) { return exact }
        if let words = wordMatch(needle, in: haystack) { return words }
        return subsequenceMatch(needle.filter { $0 != " " }, in: haystack)
    }

    /// Keeps the items whose text matches `query`, best match first. Ties keep their original
    /// order. An empty query keeps everything, unscored.
    public static func filter<Item>(
        _ items: [Item],
        query: String,
        minimumScore: Double = 0.25,
        text: (Item) -> String
    ) -> [KitoFuzzyResult<Item>] {
        let hasQuery = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasQuery else {
            return items.map { KitoFuzzyResult(item: $0, match: KitoFuzzyMatch(score: 1, ranges: [])) }
        }
        var scored: [(offset: Int, result: KitoFuzzyResult<Item>)] = []
        for (offset, item) in items.enumerated() {
            guard let match = match(query, in: text(item)), match.score >= minimumScore else { continue }
            scored.append((offset, KitoFuzzyResult(item: item, match: match)))
        }
        scored.sort { lhs, rhs in
            if lhs.result.match.score != rhs.result.match.score {
                return lhs.result.match.score > rhs.result.match.score
            }
            return lhs.offset < rhs.offset
        }
        return scored.map(\.result)
    }

    /// Optimal string alignment distance: insertions, deletions, substitutions and swapping two
    /// neighbouring letters each cost one ("form" → "from" is 1).
    public static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        editDistance(Array(lhs), Array(rhs))
    }

    // MARK: - Passes

    static func contiguousMatch(_ needle: [Character], in haystack: [Character]) -> KitoFuzzyMatch? {
        guard let start = firstOffset(of: needle, in: haystack) else { return nil }
        let score: Double
        if start == 0 {
            score = 1
        } else if isWordStart(start, in: haystack) {
            score = 0.92
        } else {
            score = 0.8
        }
        return KitoFuzzyMatch(score: score, ranges: [start..<(start + needle.count)])
    }

    static func wordMatch(_ needle: [Character], in haystack: [Character]) -> KitoFuzzyMatch? {
        let queryWords = wordRanges(in: needle).map { Array(needle[$0]) }
        let textWords = wordRanges(in: haystack)
        guard !queryWords.isEmpty, !textWords.isEmpty else { return nil }
        var total = 0.0
        var ranges: [Range<Int>] = []
        for word in queryWords {
            guard let best = bestWordMatch(word, haystack: haystack, words: textWords) else { return nil }
            total += best.score
            ranges.append(best.range)
        }
        return KitoFuzzyMatch(score: total / Double(queryWords.count) * 0.9, ranges: ranges)
    }

    static func subsequenceMatch(_ needle: [Character], in haystack: [Character]) -> KitoFuzzyMatch? {
        guard !needle.isEmpty else { return nil }
        var positions: [Int] = []
        var cursor = 0
        for character in needle {
            guard let found = haystack[cursor...].firstIndex(of: character) else { return nil }
            positions.append(found)
            cursor = found + 1
            if cursor > haystack.count { return nil }
        }
        guard let first = positions.first, let last = positions.last else { return nil }
        let density = Double(needle.count) / Double(last - first + 1)
        return KitoFuzzyMatch(score: 0.2 + 0.25 * density, ranges: positions.map { $0..<($0 + 1) })
    }

    // MARK: - Words

    private static func bestWordMatch(
        _ word: [Character],
        haystack: [Character],
        words: [Range<Int>]
    ) -> (score: Double, range: Range<Int>)? {
        var best: (score: Double, range: Range<Int>)?
        for textRange in words {
            guard let candidate = score(word, against: Array(haystack[textRange]), at: textRange.lowerBound) else { continue }
            if candidate.score > (best?.score ?? -1) { best = candidate }
        }
        return best
    }

    private static func score(_ word: [Character], against target: [Character], at offset: Int) -> (score: Double, range: Range<Int>)? {
        if target.starts(with: word) {
            let score = target.count == word.count ? 1.0 : 0.95
            return (score, offset..<(offset + word.count))
        }
        if let inner = firstOffset(of: word, in: target) {
            return (0.7, (offset + inner)..<(offset + inner + word.count))
        }
        guard let typo = typoMatch(word, against: target) else { return nil }
        let score: Double
        if typo.length == target.count {
            score = typo.distance == 1 ? 0.68 : 0.5
        } else {
            score = typo.distance == 1 ? 0.6 : 0.45
        }
        return (score, offset..<(offset + typo.length))
    }

    /// Compares `word` with the whole of `target` first ("piza" → "pizza"), then with the start of
    /// `target` at a few lengths ("resta" → "Restaurant"), and keeps the closest. A whole-word
    /// match reports `length == target.count`.
    static func typoMatch(_ word: [Character], against target: [Character]) -> (distance: Int, length: Int)? {
        let allowed = allowedTypos(forLength: word.count)
        guard allowed > 0, let first = word.first, target.first == first else { return nil }
        let whole = editDistance(word, target)
        if whole > 0, whole <= allowed { return (whole, target.count) }
        let shortest = max(1, word.count - 1)
        let longest = min(target.count, word.count + 1)
        guard shortest <= longest else { return nil }
        var best: (distance: Int, length: Int)?
        for length in shortest...longest {
            let distance = editDistance(word, Array(target.prefix(length)))
            guard let current = best else { best = (distance, length); continue }
            let closer = distance < current.distance
            let sameButTruer = distance == current.distance && length == word.count
            if closer || sameButTruer { best = (distance, length) }
        }
        guard let best, best.distance > 0, best.distance <= allowed else { return nil }
        return best
    }

    /// Short words must be spelled right; longer ones may have one typo, long ones two.
    static func allowedTypos(forLength length: Int) -> Int {
        if length >= 8 { return 2 }
        if length >= 4 { return 1 }
        return 0
    }

    // MARK: - Characters

    /// Lowercased, accent-free characters, one per original character so offsets line up.
    static func normalized(_ text: String) -> [Character] {
        text.map { character in
            let folded = String(character).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            return folded.first ?? character
        }
    }

    private static func trimmed(_ characters: [Character]) -> [Character] {
        var result = characters
        while let last = result.last, last.isWhitespace { result.removeLast() }
        while let first = result.first, first.isWhitespace { result.removeFirst() }
        return result
    }

    static func wordRanges(in characters: [Character]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var start: Int?
        for (index, character) in characters.enumerated() {
            let isWordCharacter = character.isLetter || character.isNumber
            if isWordCharacter, start == nil { start = index }
            if !isWordCharacter, let open = start {
                ranges.append(open..<index)
                start = nil
            }
        }
        if let open = start { ranges.append(open..<characters.count) }
        return ranges
    }

    private static func isWordStart(_ index: Int, in characters: [Character]) -> Bool {
        guard index > 0 else { return true }
        let previous = characters[index - 1]
        return !(previous.isLetter || previous.isNumber)
    }

    private static func firstOffset(of needle: [Character], in haystack: [Character]) -> Int? {
        guard !needle.isEmpty, needle.count <= haystack.count else { return nil }
        for start in 0...(haystack.count - needle.count) where haystack[start] == needle[0] {
            if Array(haystack[start..<(start + needle.count)]) == needle { return start }
        }
        return nil
    }

    static func editDistance(_ lhs: [Character], _ rhs: [Character]) -> Int {
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }
        let columns = rhs.count + 1
        var table = [Int](repeating: 0, count: (lhs.count + 1) * columns)
        for row in 0...lhs.count { table[row * columns] = row }
        for column in 0...rhs.count { table[column] = column }
        for row in 1...lhs.count {
            for column in 1...rhs.count {
                let cost = lhs[row - 1] == rhs[column - 1] ? 0 : 1
                let deletion = table[(row - 1) * columns + column] + 1
                let insertion = table[row * columns + column - 1] + 1
                let substitution = table[(row - 1) * columns + column - 1] + cost
                var best = min(deletion, insertion, substitution)
                let canSwap = row > 1 && column > 1 && lhs[row - 1] == rhs[column - 2] && lhs[row - 2] == rhs[column - 1]
                if canSwap { best = min(best, table[(row - 2) * columns + column - 2] + 1) }
                table[row * columns + column] = best
            }
        }
        return table[lhs.count * columns + rhs.count]
    }

    /// Sorts ranges and joins the ones that touch or overlap.
    static func merged(_ ranges: [Range<Int>]) -> [Range<Int>] {
        let sorted = ranges.filter { !$0.isEmpty }.sorted { $0.lowerBound < $1.lowerBound }
        var result: [Range<Int>] = []
        for range in sorted {
            if let last = result.last, range.lowerBound <= last.upperBound {
                result[result.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                result.append(range)
            }
        }
        return result
    }
}
