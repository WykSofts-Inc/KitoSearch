//
//  KitoSearchModel.swift
//  KitoSearch
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
import Observation

/// The state behind a search screen: the query, a debounce, the request in flight, pages of
/// results, recent searches and suggestions.
///
/// ```swift
/// @State private var search = KitoSearchModel<Restaurant> { request in
///     let page = try await api.restaurants(matching: request.query, page: request.page)
///     return KitoSearchPage(items: page.items, hasMore: page.hasNext, totalCount: page.total)
/// }
/// ```
///
/// Typing restarts the debounce; when it runs out the search closure is called with a
/// `KitoSearchRequest`. A newer query cancels the older request, and any reply that still
/// arrives late is dropped, so results never flash back to an older query.
@MainActor
@Observable
public final class KitoSearchModel<Item> {

    /// When a search runs.
    public enum Trigger: Sendable {
        /// As you type, after the debounce.
        case live
        /// Only on Return, a suggestion tap or `submit()`. Typing shows suggestions.
        case onSubmit
    }

    public typealias Search = @MainActor (KitoSearchRequest) async throws -> KitoSearchPage<Item>

    // MARK: Input

    /// The text in the field. Setting it restarts the debounce.
    public var query: String {
        get { queryStorage }
        set {
            guard newValue != queryStorage else { return }
            queryStorage = newValue
            inputsChanged(debounced: true)
        }
    }

    /// Chips inside the field ("in: Restaurants"). Changing them searches straight away.
    public var tokens: [KitoSearchToken] {
        get { tokensStorage }
        set {
            guard newValue != tokensStorage else { return }
            tokensStorage = newValue
            inputsChanged(debounced: false)
        }
    }

    /// The selected scope id. Changing it searches straight away.
    public var scope: String? {
        get { scopeStorage }
        set {
            guard newValue != scopeStorage else { return }
            scopeStorage = newValue
            inputsChanged(debounced: false)
        }
    }

    /// Applied filters, sent with every request. Changing them searches straight away.
    public var filters: KitoFilterState {
        get { filtersStorage }
        set {
            guard newValue != filtersStorage else { return }
            filtersStorage = newValue
            inputsChanged(debounced: false)
        }
    }

    // MARK: Output

    public private(set) var phase: KitoSearchPhase = .idle
    public private(set) var results: [Item] = []
    /// The backend's total, when it sent one.
    public private(set) var totalCount: Int?
    public private(set) var pagination: KitoPagination
    /// The last load-more request failed; `loadMore()` tries again.
    public private(set) var loadMoreFailed = false
    public private(set) var recents: KitoRecentSearches

    /// Popular searches shown as chips before anything is typed.
    public var trending: [String]
    /// Extra completions offered while typing, alongside recents and trending.
    public var suggestionPool: [String]

    // MARK: Settings

    public var debounce: Duration
    public var trigger: Trigger
    public var suggestionLimit: Int

    // MARK: Private

    private var queryStorage = ""
    private var tokensStorage: [KitoSearchToken] = []
    private var scopeStorage: String?
    private var filtersStorage = KitoFilterState()

    @ObservationIgnored private let perform: Search
    @ObservationIgnored private let clock: any KitoSearchClock
    @ObservationIgnored private let store: KitoRecentSearchStore?
    @ObservationIgnored private var gate = KitoRequestGate()
    @ObservationIgnored private(set) var searchTask: Task<Void, Never>?
    @ObservationIgnored private(set) var loadMoreTask: Task<Void, Never>?

    /// - Parameters:
    ///   - debounce: How long typing must pause before a search runs.
    ///   - pageSize: Sent in each request; a shorter page ends pagination unless `hasMore` says otherwise.
    ///   - trigger: `.live` searches as you type; `.onSubmit` waits for Return.
    ///   - recentsKey: `UserDefaults` key for recent searches; `nil` keeps them in memory only.
    ///   - recentsLimit: How many recent searches to keep.
    ///   - defaults: Where recents are saved.
    ///   - trending: Popular searches shown before anything is typed.
    ///   - suggestions: Extra completions offered while typing.
    ///   - clock: What the debounce waits on. Inject your own in tests.
    ///   - search: Fetches one page.
    public init(
        debounce: Duration = .milliseconds(300),
        pageSize: Int = 20,
        trigger: Trigger = .live,
        recentsKey: String? = "kito.search.recents",
        recentsLimit: Int = 8,
        defaults: UserDefaults = .standard,
        trending: [String] = [],
        suggestions: [String] = [],
        suggestionLimit: Int = 6,
        clock: any KitoSearchClock = KitoContinuousSearchClock(),
        search: @escaping Search
    ) {
        self.debounce = debounce
        self.trigger = trigger
        self.pagination = KitoPagination(pageSize: pageSize)
        self.trending = trending
        self.suggestionPool = suggestions
        self.suggestionLimit = suggestionLimit
        self.clock = clock
        self.perform = search
        let store = recentsKey.map { KitoRecentSearchStore(key: $0, defaults: defaults) }
        self.store = store
        self.recents = store?.load(limit: recentsLimit) ?? KitoRecentSearches(limit: recentsLimit)
    }

    // MARK: Derived

    /// The query without surrounding whitespace.
    public var trimmedQuery: String { queryStorage.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Whether there's anything to search for: text, or at least one token.
    public var isActive: Bool { !trimmedQuery.isEmpty || !tokensStorage.isEmpty }

    public var isLoadingMore: Bool { pagination.isLoading && phase == .results }

    /// Completions for the current text from recents, trending and `suggestionPool`, best first.
    public var suggestions: [KitoSearchSuggestion] {
        let text = trimmedQuery
        guard !text.isEmpty else { return [] }
        let key = KitoRecentSearches.key(text)
        let sources: [(KitoSearchSuggestion.Source, [String])] = [
            (.recent, recents.items), (.trending, trending), (.suggested, suggestionPool),
        ]
        var seen: Set<String> = [key]
        var found: [(offset: Int, suggestion: KitoSearchSuggestion)] = []
        for (source, candidates) in sources {
            for candidate in candidates {
                let candidateKey = KitoRecentSearches.key(candidate)
                guard !seen.contains(candidateKey), let match = KitoFuzzy.match(text, in: candidate), match.score >= 0.4 else { continue }
                seen.insert(candidateKey)
                found.append((found.count, KitoSearchSuggestion(text: candidate, source: source, match: match)))
            }
        }
        found.sort { lhs, rhs in
            if lhs.suggestion.match.score != rhs.suggestion.match.score {
                return lhs.suggestion.match.score > rhs.suggestion.match.score
            }
            return lhs.offset < rhs.offset
        }
        return found.prefix(max(0, suggestionLimit)).map(\.suggestion)
    }

    /// A likely spelling for the current text ("Did you mean pizza?"), when one is close.
    public var correction: String? {
        suggestions.first { $0.match.score >= 0.45 }?.text
    }

    // MARK: Actions

    /// Searches now, skipping the debounce, and remembers the text as a recent search.
    public func submit() {
        guard isActive else { return }
        addRecent(trimmedQuery)
        startSearch(debounced: false)
    }

    /// Puts `text` in the field and searches it straight away.
    public func search(_ text: String) {
        queryStorage = text
        submit()
    }

    /// Runs the last search again, or the failed page of it.
    public func retry() {
        if phase == .results, loadMoreFailed {
            loadMore()
        } else if isActive {
            startSearch(debounced: false)
        }
    }

    /// Loads the next page, if there is one and none is loading.
    public func loadMore() {
        guard phase == .results, let page = pagination.begin() else { return }
        loadMoreFailed = false
        let generation = gate.current
        let request = makeRequest(page: page)
        loadMoreTask = Task { [weak self] in
            await self?.runNextPage(request, generation: generation)
        }
    }

    /// Empties the field and tokens and returns to the idle state.
    public func clear() {
        queryStorage = ""
        tokensStorage = []
        inputsChanged(debounced: false)
    }

    public func addRecent(_ text: String) {
        recents.add(text)
        store?.save(recents)
    }

    public func removeRecent(_ text: String) {
        recents.remove(text)
        store?.save(recents)
    }

    public func clearRecents() {
        recents.removeAll()
        store?.save(recents)
    }

    // MARK: Running

    private func inputsChanged(debounced: Bool) {
        cancelInFlight()
        guard isActive else {
            results = []
            totalCount = nil
            loadMoreFailed = false
            pagination.reset()
            phase = .idle
            return
        }
        if debounced, trigger == .onSubmit {
            // Waiting for Return, unless the text was just emptied and only tokens are left.
            if trimmedQuery.isEmpty {
                startSearch(debounced: false)
            } else {
                phase = .typing
            }
            return
        }
        startSearch(debounced: debounced)
    }

    private func startSearch(debounced: Bool) {
        cancelInFlight()
        if debounced { phase = .typing }
        let delay = debounced ? debounce : .zero
        let clock = self.clock
        searchTask = Task { [weak self] in
            if delay > .zero {
                do { try await clock.sleep(for: delay) } catch { return }
            }
            guard !Task.isCancelled else { return }
            await self?.runFirstPage()
        }
    }

    private func cancelInFlight() {
        searchTask?.cancel()
        loadMoreTask?.cancel()
        searchTask = nil
        loadMoreTask = nil
        gate.invalidate()
    }

    private func runFirstPage() async {
        let generation = gate.begin()
        pagination.reset()
        _ = pagination.begin()
        loadMoreFailed = false
        phase = .loading
        do {
            let page = try await perform(makeRequest(page: 0))
            guard gate.isCurrent(generation), !Task.isCancelled else { return }
            results = page.items
            totalCount = page.totalCount
            pagination.complete(receivedCount: page.items.count, hasMore: page.hasMore)
            phase = page.items.isEmpty ? .empty : .results
        } catch {
            guard gate.isCurrent(generation), !Task.isCancelled, !(error is CancellationError) else { return }
            pagination.fail()
            phase = .error(error.localizedDescription)
        }
    }

    private func runNextPage(_ request: KitoSearchRequest, generation: Int) async {
        do {
            let page = try await perform(request)
            guard gate.isCurrent(generation), !Task.isCancelled else { return }
            results.append(contentsOf: page.items)
            totalCount = page.totalCount ?? totalCount
            pagination.complete(receivedCount: page.items.count, hasMore: page.hasMore)
        } catch {
            guard gate.isCurrent(generation), !Task.isCancelled, !(error is CancellationError) else { return }
            pagination.fail()
            loadMoreFailed = true
        }
    }

    private func makeRequest(page: Int) -> KitoSearchRequest {
        KitoSearchRequest(
            query: trimmedQuery,
            page: page,
            pageSize: pagination.pageSize,
            scope: scopeStorage,
            tokens: tokensStorage,
            filters: filtersStorage
        )
    }
}

public extension KitoSearchModel {
    /// A model that searches an in-memory array with `KitoFuzzy`, so it tolerates typos.
    ///
    /// ```swift
    /// @State private var search = KitoSearchModel.local(restaurants, text: \.name)
    /// ```
    ///
    /// - Parameters:
    ///   - items: Everything that can be found.
    ///   - text: The text each item is matched on.
    ///   - filters: Applies `model.filters` before matching, and the chosen sort after.
    ///   - scope: Whether an item belongs in the selected scope.
    ///   - token: Whether an item matches a token in the field.
    ///   - latency: A pretend network delay, to show loading states in demos.
    static func local(
        _ items: [Item],
        text: @escaping (Item) -> String,
        filters: KitoFilterConfiguration<Item>? = nil,
        scope: ((Item, String) -> Bool)? = nil,
        token: ((Item, KitoSearchToken) -> Bool)? = nil,
        pageSize: Int = 20,
        debounce: Duration = .milliseconds(250),
        latency: Duration = .zero,
        trigger: Trigger = .live,
        recentsKey: String? = nil,
        trending: [String] = [],
        suggestions: [String] = [],
        clock: any KitoSearchClock = KitoContinuousSearchClock()
    ) -> KitoSearchModel<Item> {
        KitoSearchModel(
            debounce: debounce,
            pageSize: pageSize,
            trigger: trigger,
            recentsKey: recentsKey,
            trending: trending,
            suggestions: suggestions,
            clock: clock
        ) { request in
            if latency > .zero { try await clock.sleep(for: latency) }
            let matched = KitoLocalSearch.run(
                items, request: request, text: text, filters: filters, scope: scope, token: token
            )
            let start = request.page * request.pageSize
            let slice = Array(matched.dropFirst(start).prefix(request.pageSize))
            return KitoSearchPage(items: slice, hasMore: start + slice.count < matched.count, totalCount: matched.count)
        }
    }
}

/// The matching behind `KitoSearchModel.local`, kept apart so it can be tested without a model.
enum KitoLocalSearch {
    static func run<Item>(
        _ items: [Item],
        request: KitoSearchRequest,
        text: (Item) -> String,
        filters: KitoFilterConfiguration<Item>?,
        scope: ((Item, String) -> Bool)?,
        token: ((Item, KitoSearchToken) -> Bool)?
    ) -> [Item] {
        var pool = items
        if let scope, let id = request.scope { pool = pool.filter { scope($0, id) } }
        if let token {
            for current in request.tokens { pool = pool.filter { token($0, current) } }
        }
        if let filters { pool = filters.apply(request.filters, to: pool) }
        guard !request.query.isEmpty else { return pool }
        let matched = KitoFuzzy.filter(pool, query: request.query, text: text).map(\.item)
        guard let filters, let sort = filters.sortOption(for: request.filters) else { return matched }
        return matched.sorted(by: sort.areInIncreasingOrder)
    }
}
