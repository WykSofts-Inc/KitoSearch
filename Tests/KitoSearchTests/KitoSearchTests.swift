//
//  KitoSearchTests.swift
//  KitoSearch
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
@testable import KitoSearch

// MARK: - Fuzzy matching

final class KitoFuzzyTests: XCTestCase {
    func testPrefixMatchScoresHighestWithItsRange() throws {
        let match = try XCTUnwrap(KitoFuzzy.match("nya", in: "Nyama Mama"))
        XCTAssertEqual(match.score, 1)
        XCTAssertEqual(match.ranges, [0..<3])
    }

    func testWordStartBeatsMidWord() throws {
        let wordStart = try XCTUnwrap(KitoFuzzy.match("mama", in: "Nyama Mama"))
        XCTAssertEqual(wordStart.ranges, [6..<10])
        XCTAssertEqual(wordStart.score, 0.92, accuracy: 0.0001)
        let inside = try XCTUnwrap(KitoFuzzy.match("ama", in: "Nyama"))
        XCTAssertEqual(inside.score, 0.8, accuracy: 0.0001)
        XCTAssertGreaterThan(wordStart.score, inside.score)
    }

    func testIgnoresCaseAndAccents() throws {
        let match = try XCTUnwrap(KitoFuzzy.match("CAFE", in: "Café Deli"))
        XCTAssertEqual(match.ranges, [0..<4])
        XCTAssertEqual(match.score, 1)
    }

    func testMatchesWordsSeparately() throws {
        let match = try XCTUnwrap(KitoFuzzy.match("java kil", in: "Java House Kilimani"))
        XCTAssertEqual(match.ranges, [0..<4, 11..<14])
        XCTAssertEqual(match.score, 0.8775, accuracy: 0.0001)
    }

    func testToleratesOneTypoInAMediumWord() throws {
        let match = try XCTUnwrap(KitoFuzzy.match("nyamma", in: "Nyama Mama"))
        XCTAssertEqual(match.ranges, [0..<5])
        XCTAssertEqual(match.score, 0.612, accuracy: 0.0001, "a whole-word typo")
    }

    func testToleratesAMissingLetterInALongWord() throws {
        let match = try XCTUnwrap(KitoFuzzy.match("resturant", in: "Restaurant Week"))
        XCTAssertEqual(match.ranges, [0..<10])
    }

    func testShortWordsMustBeSpelledRight() {
        XCTAssertNil(KitoFuzzy.typoMatch(Array("piz"), against: Array("pie")))
        XCTAssertEqual(KitoFuzzy.allowedTypos(forLength: 3), 0)
        XCTAssertEqual(KitoFuzzy.allowedTypos(forLength: 4), 1)
        XCTAssertEqual(KitoFuzzy.allowedTypos(forLength: 8), 2)
    }

    func testFallsBackToLettersInOrder() throws {
        let match = try XCTUnwrap(KitoFuzzy.match("jhk", in: "Java House Kilimani"))
        XCTAssertEqual(match.ranges, [0..<1, 5..<6, 11..<12])
        XCTAssertEqual(match.score, 0.2625, accuracy: 0.0001)
    }

    func testUnrelatedTextDoesNotMatch() {
        XCTAssertNil(KitoFuzzy.match("sushi", in: "Nyama Mama"))
        XCTAssertNil(KitoFuzzy.match("   ", in: "Nyama Mama"))
        XCTAssertNil(KitoFuzzy.match("a", in: ""))
    }

    func testEditDistanceCountsSwapsAsOne() {
        XCTAssertEqual(KitoFuzzy.editDistance("form", "from"), 1)
        XCTAssertEqual(KitoFuzzy.editDistance("kitten", "sitting"), 3)
        XCTAssertEqual(KitoFuzzy.editDistance("", "abc"), 3)
        XCTAssertEqual(KitoFuzzy.editDistance("same", "same"), 0)
    }

    func testFilterOrdersByScoreThenOriginalOrder() {
        let names = ["Pizzeria Lorenzo", "Spice Pizza", "Pizza Inn", "Sushi Bar", "Pizza Hut"]
        let results = KitoFuzzy.filter(names, query: "pizza") { $0 }
        XCTAssertEqual(results.map(\.item), ["Pizza Inn", "Pizza Hut", "Spice Pizza", "Pizzeria Lorenzo"])
    }

    func testFilterWithEmptyQueryKeepsEverything() {
        let results = KitoFuzzy.filter(["b", "a"], query: " ") { $0 }
        XCTAssertEqual(results.map(\.item), ["b", "a"])
        XCTAssertTrue(results.allSatisfy { $0.match.ranges.isEmpty })
    }

    func testRangesAreMergedAndClamped() {
        XCTAssertEqual(KitoFuzzy.merged([4..<6, 0..<2, 1..<3, 6..<7, 9..<9]), [0..<3, 4..<7])
        XCTAssertEqual(KitoHighlightSpans.clamped([-2..<2, 3..<50, 60..<70], count: 5), [0..<2, 3..<5])
    }
}

// MARK: - Recent searches

final class KitoRecentSearchesTests: XCTestCase {
    func testAddingTrimsDedupesAndMovesToFront() {
        var recents = KitoRecentSearches(limit: 5)
        recents.add("  pizza ")
        recents.add("sushi")
        recents.add("PIZZA")
        recents.add("")
        recents.add("   ")
        XCTAssertEqual(recents.items, ["PIZZA", "sushi"])
    }

    func testDedupeIgnoresAccents() {
        var recents = KitoRecentSearches()
        recents.add("cafe")
        recents.add("Café")
        XCTAssertEqual(recents.items, ["Café"])
    }

    func testCapsAtTheLimitDroppingTheOldest() {
        var recents = KitoRecentSearches(limit: 3)
        for query in ["a", "b", "c", "d"] { recents.add(query) }
        XCTAssertEqual(recents.items, ["d", "c", "b"])
    }

    func testInitialItemsAreNormalised() {
        let recents = KitoRecentSearches(["new", "old", "NEW", "older"], limit: 2)
        XCTAssertEqual(recents.items, ["new", "old"])
    }

    func testRemoveOneAndClearAll() {
        var recents = KitoRecentSearches(["tacos", "ramen", "pilau"])
        recents.remove("RAMEN")
        XCTAssertEqual(recents.items, ["tacos", "pilau"])
        recents.removeAll()
        XCTAssertTrue(recents.isEmpty)
    }

    func testStorePersistsAndClears() throws {
        let suite = "kito.search.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = KitoRecentSearchStore(key: "recents", defaults: defaults)

        var recents = store.load(limit: 3)
        XCTAssertTrue(recents.isEmpty)
        recents.add("nyama choma")
        recents.add("pilau")
        store.save(recents)
        XCTAssertEqual(store.load(limit: 3).items, ["pilau", "nyama choma"])
        XCTAssertEqual(store.load(limit: 1).items, ["pilau"], "a smaller limit trims on load")

        recents.removeAll()
        store.save(recents)
        XCTAssertNil(defaults.object(forKey: "recents"))
    }
}

// MARK: - Pagination and request gate

final class KitoPaginationTests: XCTestCase {
    func testPagesAdvanceAndShortPageEnds() {
        var pages = KitoPagination(pageSize: 10)
        XCTAssertEqual(pages.begin(), 0)
        XCTAssertNil(pages.begin(), "can't load the same page twice")
        pages.complete(receivedCount: 10)
        XCTAssertTrue(pages.hasMore)
        XCTAssertEqual(pages.begin(), 1)
        pages.complete(receivedCount: 4)
        XCTAssertFalse(pages.hasMore)
        XCTAssertEqual(pages.loadedCount, 14)
        XCTAssertNil(pages.begin())
    }

    func testExplicitHasMoreWins() {
        var pages = KitoPagination(pageSize: 10)
        _ = pages.begin()
        pages.complete(receivedCount: 3, hasMore: true)
        XCTAssertTrue(pages.canLoadMore)
        _ = pages.begin()
        pages.complete(receivedCount: 10, hasMore: false)
        XCTAssertFalse(pages.canLoadMore)
    }

    func testFailureAllowsRetryingTheSamePage() {
        var pages = KitoPagination(pageSize: 5)
        _ = pages.begin()
        pages.complete(receivedCount: 5)
        XCTAssertEqual(pages.begin(), 1)
        pages.fail()
        XCTAssertFalse(pages.isLoading)
        XCTAssertEqual(pages.begin(), 1)
    }

    func testCompleteWithoutBeginIsIgnoredAndResetStartsOver() {
        var pages = KitoPagination(pageSize: 5)
        pages.complete(receivedCount: 5)
        XCTAssertEqual(pages.nextPage, 0)
        _ = pages.begin()
        pages.complete(receivedCount: 5)
        pages.reset()
        XCTAssertEqual(pages, KitoPagination(pageSize: 5))
    }

    func testGateMarksOlderRequestsStale() {
        var gate = KitoRequestGate()
        let first = gate.begin()
        let second = gate.begin()
        XCTAssertFalse(gate.isCurrent(first))
        XCTAssertTrue(gate.isCurrent(second))
        gate.invalidate()
        XCTAssertFalse(gate.isCurrent(second))
    }
}

// MARK: - Filters

private struct Place: Equatable {
    let name: String
    let cuisine: String
    let price: Double
    let rating: Double
    let distance: Double
    let openNow: Bool
}

private let places = [
    Place(name: "Mama Oliech", cuisine: "Kenyan", price: 800, rating: 4.6, distance: 3.2, openNow: true),
    Place(name: "Habesha", cuisine: "Ethiopian", price: 1_200, rating: 4.4, distance: 1.1, openNow: true),
    Place(name: "Mercado", cuisine: "Mexican", price: 2_500, rating: 4.1, distance: 6.5, openNow: false),
    Place(name: "Cultiva", cuisine: "Kenyan", price: 3_500, rating: 4.8, distance: 12, openNow: true),
    Place(name: "Big Square", cuisine: "American", price: 900, rating: 3.6, distance: 2.4, openNow: false),
]

private let configuration = KitoFilterConfiguration<Place>(
    facets: [
        KitoFilterFacet("kenyan", title: "Kenyan") { $0.cuisine == "Kenyan" },
        KitoFilterFacet("ethiopian", title: "Ethiopian") { $0.cuisine == "Ethiopian" },
        KitoFilterFacet("mexican", title: "Mexican") { $0.cuisine == "Mexican" },
    ],
    toggles: [KitoFilterFacet("open", title: "Open now") { $0.openNow }],
    price: { $0.price },
    priceBounds: 0...4_000,
    currencyCode: "KES",
    rating: { $0.rating },
    distance: { $0.distance },
    sorts: [
        KitoSortOption("rating", title: "Top rated") { $0.rating > $1.rating },
        KitoSortOption("nearest", title: "Nearest") { $0.distance < $1.distance },
    ]
)

final class KitoFilterTests: XCTestCase {
    func testReduceTogglesAndCounts() {
        var state = KitoFilterState()
        state.reduce(.toggleFacet("kenyan"))
        state.reduce(.toggleFacet("mexican"))
        state.reduce(.toggle("open"))
        state.reduce(.setPrice(500...3_000))
        XCTAssertEqual(state.activeCount, 4)
        state.reduce(.toggleFacet("mexican"))
        XCTAssertEqual(state.facets, ["kenyan"])
        state.reduce(.setSort("rating"))
        XCTAssertEqual(state.activeCount, 3, "sorting isn't a filter")
        XCTAssertFalse(state.isEmpty)
    }

    func testZeroRatingMeansAny() {
        var state = KitoFilterState(minimumRating: 4)
        state.reduce(.setMinimumRating(0))
        XCTAssertNil(state.minimumRating)
        XCTAssertEqual(state.reduced(.setMinimumRating(4.5)).minimumRating, 4.5)
    }

    func testRemovingPillsAndClearingAll() {
        var state = KitoFilterState(facets: ["kenyan"], toggles: ["open"], price: 0...1_000, minimumRating: 4, maximumDistance: 5, sort: "rating")
        state.reduce(.remove(.facet("kenyan")))
        state.reduce(.remove(.price))
        state.reduce(.remove(.distance))
        XCTAssertEqual(state, KitoFilterState(toggles: ["open"], minimumRating: 4, sort: "rating"))
        state.reduce(.clearAll)
        XCTAssertTrue(state.isEmpty)
    }

    func testFacetsWidenAndTogglesNarrow() {
        let state = KitoFilterState(facets: ["kenyan", "ethiopian"], toggles: ["open"])
        let names = configuration.apply(state, to: places).map(\.name)
        XCTAssertEqual(names, ["Mama Oliech", "Habesha", "Cultiva"])
        let closed = KitoFilterState(facets: ["mexican"], toggles: ["open"])
        XCTAssertEqual(configuration.count(closed, in: places), 0)
    }

    func testRangesAndSorting() {
        let state = KitoFilterState(price: 500...3_000, minimumRating: 4, maximumDistance: 7, sort: "nearest")
        XCTAssertEqual(configuration.apply(state, to: places).map(\.name), ["Habesha", "Mama Oliech", "Mercado"])
        XCTAssertEqual(configuration.count(state, in: places), 3)
    }

    func testChipCountsIgnoreTheirOwnGroup() {
        let state = KitoFilterState(facets: ["kenyan"], toggles: ["open"])
        let counts = Dictionary(uniqueKeysWithValues: configuration.options(for: state, in: places).map { ($0.id, $0.count ?? -1) })
        XCTAssertEqual(counts, ["kenyan": 2, "ethiopian": 1, "mexican": 0])
    }

    func testAppliedFiltersBecomePills() {
        let state = KitoFilterState(facets: ["ethiopian"], toggles: ["open"], minimumRating: 4, maximumDistance: 5)
        let pills = configuration.appliedFilters(for: state)
        XCTAssertEqual(pills.map(\.kind), [.facet("ethiopian"), .toggle("open"), .rating, .distance])
        XCTAssertEqual(pills.map(\.title), ["Ethiopian", "Open now", "4.0+", "Within 5 km"])
    }

    func testHistogramBuckets() {
        let counts = KitoHistogram.counts([0, 100, 499, 500, 999, 1_000, 5_000, -3], bounds: 0...1_000, buckets: 2)
        XCTAssertEqual(counts, [4, 4])
        XCTAssertEqual(KitoHistogram.counts([1, 2], bounds: 5...5, buckets: 3), [2, 0, 0])
        XCTAssertEqual(KitoHistogram.counts([1], bounds: 0...1, buckets: 0), [])
    }

    func testRangeSliderSnapsAndClamps() {
        XCTAssertEqual(KitoRangeSliderMath.value(at: 0.337, bounds: 0...1_000, step: 50), 350)
        XCTAssertEqual(KitoRangeSliderMath.value(at: 1.4, bounds: 200...1_000, step: 100), 1_000)
        XCTAssertEqual(KitoRangeSliderMath.value(at: -1, bounds: 200...1_000, step: 100), 200)
        XCTAssertEqual(KitoRangeSliderMath.fraction(of: 600, bounds: 200...1_000), 0.5)
        XCTAssertEqual(KitoRangeSliderMath.fraction(of: 5, bounds: 5...5), 0)
    }
}

// MARK: - Sections and local search

final class KitoSearchSectionTests: XCTestCase {
    func testGroupsInOrderOfFirstAppearance() {
        let sections = KitoSearchSection.grouped(places, by: { $0.cuisine })
        XCTAssertEqual(sections.map(\.title), ["Kenyan", "Ethiopian", "Mexican", "American"])
        XCTAssertEqual(sections.first?.items.map(\.name), ["Mama Oliech", "Cultiva"])
        let flat = KitoSearchSection<Place>.grouped(places, by: nil)
        XCTAssertEqual(flat.count, 1)
        XCTAssertNil(flat.first?.title)
        XCTAssertTrue(KitoSearchSection<Place>.grouped([], by: nil).isEmpty)
    }

    func testLocalSearchFiltersThenMatchesThenSorts() {
        let request = KitoSearchRequest(query: "ma", filters: KitoFilterState(sort: "rating"))
        let names = KitoLocalSearch.run(places, request: request, text: \.name, filters: configuration, scope: nil, token: nil).map(\.name)
        XCTAssertEqual(names, ["Mama Oliech", "Mercado"])
        let scoped = KitoSearchRequest(query: "", scope: "Kenyan")
        let kenyan = KitoLocalSearch.run(places, request: scoped, text: \.name, filters: nil, scope: { $0.cuisine == $1 }, token: nil)
        XCTAssertEqual(kenyan.map(\.name), ["Mama Oliech", "Cultiva"])
    }
}

// MARK: - Model

/// A clock that only moves when the test says so.
final class ManualSearchClock: KitoSearchClock, @unchecked Sendable {
    private struct Sleeper {
        let id: UUID
        let deadline: Duration
        let continuation: CheckedContinuation<Void, Error>
    }

    private let lock = NSLock()
    private var now: Duration = .zero
    private var sleepers: [Sleeper] = []

    var sleeperCount: Int { lock.withLock { sleepers.count } }

    func sleep(for duration: Duration) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.withLock {
                    if Task.isCancelled {
                        continuation.resume(throwing: CancellationError())
                    } else {
                        sleepers.append(Sleeper(id: id, deadline: now + duration, continuation: continuation))
                    }
                }
            }
        } onCancel: {
            let cancelled: Sleeper? = lock.withLock {
                guard let index = sleepers.firstIndex(where: { $0.id == id }) else { return nil }
                return sleepers.remove(at: index)
            }
            cancelled?.continuation.resume(throwing: CancellationError())
        }
    }

    func advance(by duration: Duration) {
        let due: [Sleeper] = lock.withLock {
            now += duration
            let due = sleepers.filter { $0.deadline <= now }
            sleepers.removeAll { $0.deadline <= now }
            return due
        }
        due.forEach { $0.continuation.resume() }
    }

    func waitForSleepers(_ count: Int) async {
        for _ in 0..<10_000 {
            if sleeperCount >= count { return }
            await Task.yield()
        }
    }
}

@MainActor
private final class SearchSpy {
    var requests: [KitoSearchRequest] = []
    var held: [CheckedContinuation<Void, Never>] = []
    var holding: Set<String> = []
    var failing: Set<String> = []
    var pages: [String: Int] = [:]

    struct Failure: LocalizedError {
        var errorDescription: String? { "The network is down" }
    }

    func search(_ request: KitoSearchRequest) async throws -> KitoSearchPage<String> {
        requests.append(request)
        if holding.contains(request.query) {
            await withCheckedContinuation { held.append($0) }
        }
        if failing.contains(request.query) { throw Failure() }
        if request.query == "none" { return KitoSearchPage(items: [], hasMore: false, totalCount: 0) }
        let total = pages[request.query] ?? 1
        let items = ["\(request.query)-\(request.page)"]
        return KitoSearchPage(items: items, hasMore: request.page + 1 < total, totalCount: total)
    }

    func releaseAll() {
        let waiting = held
        held = []
        waiting.forEach { $0.resume() }
    }
}


@MainActor
private struct Harness {
    let model: KitoSearchModel<String>
    let spy: SearchSpy
    let clock: ManualSearchClock

    init(trigger: KitoSearchModel<String>.Trigger = .live, recentsKey: String? = nil, defaults: UserDefaults = .standard) {
        let spy = SearchSpy()
        let clock = ManualSearchClock()
        self.spy = spy
        self.clock = clock
        self.model = KitoSearchModel<String>(
            debounce: .milliseconds(300),
            pageSize: 1,
            trigger: trigger,
            recentsKey: recentsKey,
            defaults: defaults,
            trending: ["pizza", "pilau", "nyama choma"],
            clock: clock
        ) { request in
            try await spy.search(request)
        }
    }

    func settle() async {
        for _ in 0..<50 { await Task.yield() }
    }
}

@MainActor
final class KitoSearchModelTests: XCTestCase {
    func testDebounceWaitsForAQuietPeriod() async {
        let harness = Harness()
        let model = harness.model
        model.query = "p"
        XCTAssertEqual(model.phase, .typing)
        await harness.clock.waitForSleepers(1)
        harness.clock.advance(by: .milliseconds(200))

        model.query = "pi"
        await harness.clock.waitForSleepers(1)
        harness.clock.advance(by: .milliseconds(250))
        await harness.settle()
        XCTAssertTrue(harness.spy.requests.isEmpty, "typing again restarts the wait")

        harness.clock.advance(by: .milliseconds(50))
        await model.searchTask?.value
        XCTAssertEqual(harness.spy.requests.map(\.query), ["pi"])
        XCTAssertEqual(model.results, ["pi-0"])
        XCTAssertEqual(model.phase, .results)
    }

    func testStaleRepliesAreDropped() async {
        let harness = Harness()
        let model = harness.model
        harness.spy.holding = ["a"]
        model.query = "a"
        await harness.clock.waitForSleepers(1)
        harness.clock.advance(by: .milliseconds(300))
        for _ in 0..<1_000 where harness.spy.held.isEmpty { await Task.yield() }
        XCTAssertEqual(model.phase, .loading)
        let stale = model.searchTask

        model.query = "ab"
        await harness.clock.waitForSleepers(1)
        harness.clock.advance(by: .milliseconds(300))
        await model.searchTask?.value
        XCTAssertEqual(model.results, ["ab-0"])

        harness.spy.releaseAll()
        await stale?.value
        XCTAssertEqual(model.results, ["ab-0"], "the older reply arrived late and was ignored")
        XCTAssertEqual(model.phase, .results)
    }

    func testSubmitSkipsTheDebounceAndRemembersTheQuery() async {
        let harness = Harness()
        let model = harness.model
        model.query = "  pilau "
        model.submit()
        await model.searchTask?.value
        XCTAssertEqual(harness.spy.requests.map(\.query), ["pilau"])
        XCTAssertEqual(model.recents.items, ["pilau"])
        XCTAssertEqual(harness.clock.sleeperCount, 0)
    }

    func testOnSubmitModeDoesNotSearchWhileTyping() async {
        let harness = Harness(trigger: .onSubmit)
        let model = harness.model
        model.query = "piz"
        await harness.settle()
        XCTAssertEqual(model.phase, .typing)
        XCTAssertEqual(harness.clock.sleeperCount, 0)
        XCTAssertTrue(harness.spy.requests.isEmpty)
        XCTAssertEqual(model.suggestions.map(\.text), ["pizza"])
    }

    func testEmptyErrorAndRetry() async {
        let harness = Harness()
        let model = harness.model
        model.search("none")
        await model.searchTask?.value
        XCTAssertEqual(model.phase, .empty)

        harness.spy.failing = ["boom"]
        model.search("boom")
        await model.searchTask?.value
        XCTAssertEqual(model.phase, .error("The network is down"))

        harness.spy.failing = []
        model.retry()
        await model.searchTask?.value
        XCTAssertEqual(model.phase, .results)
        XCTAssertEqual(model.results, ["boom-0"])
    }

    func testLoadMoreAppendsUntilTheEnd() async {
        let harness = Harness()
        let model = harness.model
        harness.spy.pages = ["kebab": 3]
        model.search("kebab")
        await model.searchTask?.value
        XCTAssertTrue(model.pagination.hasMore)

        model.loadMore()
        model.loadMore()
        await model.loadMoreTask?.value
        XCTAssertEqual(model.results, ["kebab-0", "kebab-1"])
        model.loadMore()
        await model.loadMoreTask?.value
        XCTAssertEqual(model.results, ["kebab-0", "kebab-1", "kebab-2"])
        XCTAssertFalse(model.pagination.hasMore)
        XCTAssertEqual(harness.spy.requests.map(\.page), [0, 1, 2])
        XCTAssertEqual(model.totalCount, 3)
    }

    func testClearingReturnsToIdle() async {
        let harness = Harness()
        let model = harness.model
        model.search("pizza")
        await model.searchTask?.value
        model.query = ""
        XCTAssertEqual(model.phase, .idle)
        XCTAssertTrue(model.results.isEmpty)
    }

    func testTokensAloneSearchStraightAway() async {
        let harness = Harness()
        let model = harness.model
        model.tokens = [KitoSearchToken(value: "Restaurants")]
        XCTAssertTrue(model.isActive)
        await model.searchTask?.value
        XCTAssertEqual(harness.spy.requests.first?.tokens.map(\.text), ["in: Restaurants"])
        XCTAssertEqual(harness.clock.sleeperCount, 0)
    }

    func testRecentsPersistAcrossModels() async throws {
        let suite = "kito.search.model.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = Harness(recentsKey: "recents", defaults: defaults).model
        first.search("ugali")
        first.search("samosa")
        await first.searchTask?.value
        first.removeRecent("ugali")

        let second = Harness(recentsKey: "recents", defaults: defaults).model
        XCTAssertEqual(second.recents.items, ["samosa"])
        second.clearRecents()
        XCTAssertTrue(Harness(recentsKey: "recents", defaults: defaults).model.recents.isEmpty)
    }

    func testSuggestionsAndCorrection() {
        let model = Harness().model
        model.addRecent("pilau rice")
        model.query = "pil"
        XCTAssertEqual(model.suggestions.map(\.text), ["pilau rice", "pilau"])
        XCTAssertEqual(model.suggestions.first?.source, .recent)
        model.query = "piza"
        XCTAssertEqual(model.correction, "pizza")
    }
}
