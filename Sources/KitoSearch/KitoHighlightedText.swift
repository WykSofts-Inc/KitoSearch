//
//  KitoHighlightedText.swift
//  KitoSearch
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// How matched characters stand out.
public enum KitoHighlightStyle: Sendable {
    /// Matched characters bold, the rest softer — the usual look for suggestions.
    case bold
    /// Matched characters bold in the tint colour.
    case tint
    /// A highlighter-pen wash behind matched characters.
    case marker
}

/// Text with some characters highlighted, such as the part of a result that matched the query.
///
/// ```swift
/// KitoHighlightedText("Java House Kilimani", matching: "java kil")
/// KitoHighlightedText(suggestion.text, ranges: suggestion.match.ranges, style: .marker)
/// ```
public struct KitoHighlightedText: View {
    private let text: String
    private let ranges: [Range<Int>]
    private let style: KitoHighlightStyle
    private let font: Font?
    private let tint: Color?
    @Environment(\.kitoTheme) private var theme

    /// Highlights the given character ranges.
    public init(_ text: String, ranges: [Range<Int>], style: KitoHighlightStyle = .bold, font: Font? = nil, tint: Color? = nil) {
        self.text = text
        self.ranges = ranges
        self.style = style
        self.font = font
        self.tint = tint
    }

    /// Highlights whatever part of `text` matches `query`, typos included.
    public init(_ text: String, matching query: String, style: KitoHighlightStyle = .bold, font: Font? = nil, tint: Color? = nil) {
        self.init(text, ranges: KitoFuzzy.match(query, in: text)?.ranges ?? [], style: style, font: font, tint: tint)
    }

    public var body: some View {
        Text(attributed)
            .accessibilityLabel(text)
    }

    private var attributed: AttributedString {
        let base = font ?? theme.typography.body
        let accent = tint ?? theme.colors.primary
        let spans = KitoHighlightSpans.clamped(ranges, count: text.count)
        var result = AttributedString(text)
        result.font = base
        result.foregroundColor = spans.isEmpty || style != .bold ? theme.colors.onSurface : theme.colors.onSurface.opacity(0.62)
        for span in spans {
            let lower = result.index(result.startIndex, offsetByCharacters: span.lowerBound)
            let upper = result.index(result.startIndex, offsetByCharacters: span.upperBound)
            apply(to: &result[lower..<upper], base: base, accent: accent)
        }
        return result
    }

    private func apply(to run: inout AttributedSubstring, base: Font, accent: Color) {
        switch style {
        case .bold:
            run.font = base.bold()
            run.foregroundColor = theme.colors.onSurface
        case .tint:
            run.font = base.bold()
            run.foregroundColor = accent
        case .marker:
            run.backgroundColor = accent.opacity(0.22)
            run.foregroundColor = theme.colors.onSurface
        }
    }
}

enum KitoHighlightSpans {
    /// Drops empty and out-of-bounds ranges and trims the rest to the text.
    static func clamped(_ ranges: [Range<Int>], count: Int) -> [Range<Int>] {
        let trimmed = ranges.compactMap { range -> Range<Int>? in
            let lower = max(0, range.lowerBound)
            let upper = min(count, range.upperBound)
            return lower < upper ? lower..<upper : nil
        }
        return KitoFuzzy.merged(trimmed)
    }
}
