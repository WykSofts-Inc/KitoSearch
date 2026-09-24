//
//  KitoSearchPaging.swift
//  KitoSearch
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// Where a paged search is up to: the next page to ask for, whether there is one, and whether a
/// request is already out (so scrolling to the bottom twice doesn't load the same page twice).
public struct KitoPagination: Equatable, Sendable {
    public let pageSize: Int
    public private(set) var nextPage: Int = 0
    public private(set) var hasMore: Bool = true
    public private(set) var isLoading: Bool = false
    public private(set) var loadedCount: Int = 0

    public init(pageSize: Int = 20) {
        self.pageSize = max(1, pageSize)
    }

    public var canLoadMore: Bool { hasMore && !isLoading }

    /// Starts loading and returns the page to request, or `nil` when there's nothing to load or a
    /// request is already out.
    public mutating func begin() -> Int? {
        guard canLoadMore else { return nil }
        isLoading = true
        return nextPage
    }

    /// Records a page that arrived. Without an explicit `hasMore`, a short page means the end.
    public mutating func complete(receivedCount: Int, hasMore: Bool? = nil) {
        guard isLoading else { return }
        isLoading = false
        loadedCount += max(0, receivedCount)
        nextPage += 1
        self.hasMore = hasMore ?? (receivedCount >= pageSize)
    }

    /// The request failed: the same page can be asked for again.
    public mutating func fail() {
        isLoading = false
    }

    public mutating func reset() {
        self = KitoPagination(pageSize: pageSize)
    }
}

/// Hands out a number for each request, so a reply that arrives after a newer request started
/// can be recognised and dropped even when the work behind it ignored cancellation.
public struct KitoRequestGate: Equatable, Sendable {
    public private(set) var current: Int = 0

    public init() {}

    /// Starts a new request; every earlier number becomes stale.
    public mutating func begin() -> Int {
        current += 1
        return current
    }

    /// Makes every number handed out so far stale, without starting a request.
    public mutating func invalidate() {
        current += 1
    }

    public func isCurrent(_ request: Int) -> Bool {
        request == current
    }
}
