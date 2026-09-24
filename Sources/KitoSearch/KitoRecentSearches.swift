//
//  KitoRecentSearches.swift
//  KitoSearch
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// A short, newest-first list of past searches.
///
/// Adding trims whitespace, ignores empty text, moves a repeat (compared without case or accents)
/// to the front instead of listing it twice, and drops the oldest entry past `limit`.
public struct KitoRecentSearches: Equatable, Sendable {
    public private(set) var items: [String]
    public let limit: Int

    public init(_ items: [String] = [], limit: Int = 8) {
        self.limit = max(1, limit)
        self.items = []
        for item in items.reversed() { add(item) }
    }

    public var isEmpty: Bool { items.isEmpty }

    public mutating func add(_ query: String) {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        items.removeAll { Self.key($0) == Self.key(text) }
        items.insert(text, at: 0)
        if items.count > limit { items.removeLast(items.count - limit) }
    }

    public mutating func remove(_ query: String) {
        let key = Self.key(query.trimmingCharacters(in: .whitespacesAndNewlines))
        items.removeAll { Self.key($0) == key }
    }

    public mutating func removeAll() {
        items.removeAll()
    }

    static func key(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

/// Saves recent searches in `UserDefaults` under one key.
public struct KitoRecentSearchStore {
    public let key: String
    private let defaults: UserDefaults

    public init(key: String = "kito.search.recents", defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
    }

    public func load(limit: Int = 8) -> KitoRecentSearches {
        KitoRecentSearches(defaults.stringArray(forKey: key) ?? [], limit: limit)
    }

    public func save(_ recents: KitoRecentSearches) {
        if recents.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(recents.items, forKey: key)
        }
    }
}
