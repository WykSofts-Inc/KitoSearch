//
//  KitoSearchClock.swift
//  KitoSearch
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// What the search model waits on for its debounce. Swap in your own to control time in tests.
///
/// `sleep(for:)` must throw `CancellationError` when the waiting task is cancelled, so a query
/// typed over the top of another cancels the older wait.
public protocol KitoSearchClock: Sendable {
    func sleep(for duration: Duration) async throws
}

/// Real time, via `Task.sleep`.
public struct KitoContinuousSearchClock: KitoSearchClock {
    public init() {}

    public func sleep(for duration: Duration) async throws {
        guard duration > .zero else {
            try Task.checkCancellation()
            return
        }
        try await Task.sleep(for: duration)
    }
}
