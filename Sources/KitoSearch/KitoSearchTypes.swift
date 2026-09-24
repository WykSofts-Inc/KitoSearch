//
//  KitoSearchTypes.swift
//  KitoSearch
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI

/// Where a search is up to.
public enum KitoSearchPhase: Equatable, Hashable, Sendable {
    /// Nothing typed: show recents, trending and categories.
    case idle
    /// Text changed and the debounce is running (or, in `.onSubmit` mode, waiting for Return).
    case typing
    /// The first page is on its way.
    case loading
    /// At least one result.
    case results
    /// The search finished with nothing.
    case empty
    /// The search failed. The message is the error's `localizedDescription`.
    case error(String)
}

/// Everything a search closure needs to fetch one page.
public struct KitoSearchRequest: Equatable, Sendable {
    public let query: String
    public let page: Int
    public let pageSize: Int
    public let scope: String?
    public let tokens: [KitoSearchToken]
    public let filters: KitoFilterState

    public init(
        query: String,
        page: Int = 0,
        pageSize: Int = 20,
        scope: String? = nil,
        tokens: [KitoSearchToken] = [],
        filters: KitoFilterState = KitoFilterState()
    ) {
        self.query = query
        self.page = page
        self.pageSize = pageSize
        self.scope = scope
        self.tokens = tokens
        self.filters = filters
    }
}

/// One page of results from a search closure.
public struct KitoSearchPage<Item> {
    public var items: [Item]
    /// Whether another page exists. When unsure, pass `items.count == request.pageSize`.
    public var hasMore: Bool
    /// The full number of matches, when the backend knows it ("128 results").
    public var totalCount: Int?

    public init(items: [Item], hasMore: Bool, totalCount: Int? = nil) {
        self.items = items
        self.hasMore = hasMore
        self.totalCount = totalCount
    }
}

extension KitoSearchPage: Sendable where Item: Sendable {}
extension KitoSearchPage: Equatable where Item: Equatable {}

/// A chip that sits inside the search field and narrows the search, such as "in: Restaurants".
public struct KitoSearchToken: Identifiable, Hashable, Sendable {
    public let id: String
    /// The prefix, e.g. "in". Empty shows only the value.
    public var label: String
    /// The value, e.g. "Restaurants".
    public var value: String
    public var systemImage: String?

    public init(id: String? = nil, label: String = "in", value: String, systemImage: String? = nil) {
        self.id = id ?? "\(label):\(value)"
        self.label = label
        self.value = value
        self.systemImage = systemImage
    }

    /// "in: Restaurants".
    public var text: String { label.isEmpty ? value : "\(label): \(value)" }
}

/// One segment in the scope row under the field ("All", "People", "Places").
public struct KitoSearchScope: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var systemImage: String?

    public init(_ id: String, title: String? = nil, systemImage: String? = nil) {
        self.id = id
        self.title = title ?? id.capitalized
        self.systemImage = systemImage
    }
}

/// A tile in the "Browse" grid shown before anything is typed.
public struct KitoSearchCategory: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var systemImage: String
    /// Tile colour; `nil` picks one from the theme.
    public var color: Color?
    /// The token applied when the tile is tapped. Defaults to "in: <title>".
    public var token: KitoSearchToken

    public init(_ title: String, systemImage: String, color: Color? = nil, token: KitoSearchToken? = nil) {
        self.id = title
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.token = token ?? KitoSearchToken(label: "in", value: title, systemImage: systemImage)
    }
}

/// A completion offered while typing, with the characters that matched.
public struct KitoSearchSuggestion: Identifiable, Hashable, Sendable {
    public enum Source: Hashable, Sendable {
        case recent, trending, suggested
    }

    public var id: String { text }
    public let text: String
    public let source: Source
    public let match: KitoFuzzyMatch

    public init(text: String, source: Source, match: KitoFuzzyMatch) {
        self.text = text
        self.source = source
        self.match = match
    }
}

/// Results grouped under one header.
struct KitoSearchSection<Item>: Identifiable {
    let id: String
    let title: String?
    var items: [Item]

    /// Groups `items` by `title`, keeping the order each group first appears in and the item order
    /// inside each group. Without a `title` function everything is one untitled section.
    static func grouped(_ items: [Item], by title: ((Item) -> String)?) -> [KitoSearchSection<Item>] {
        guard let title else {
            return items.isEmpty ? [] : [KitoSearchSection(id: "", title: nil, items: items)]
        }
        var order: [String] = []
        var groups: [String: [Item]] = [:]
        for item in items {
            let key = title(item)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(item)
        }
        return order.map { KitoSearchSection(id: $0, title: $0, items: groups[$0] ?? []) }
    }
}
