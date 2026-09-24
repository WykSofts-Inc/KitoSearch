# ``KitoSearch``

Search for SwiftUI, from a styled search field and a debouncing model to typo-tolerant matching and a ready-made search screen.

## Overview

``KitoSearchModel`` drives a search: it debounces typing, cancels stale
requests, drops late replies, pages results and keeps recent searches. Give it
an async closure that turns a ``KitoSearchRequest`` into a ``KitoSearchPage``
for a remote backend, or use `KitoSearchModel.local(_:text:)` to search an
in-memory array with ``KitoFuzzy``, which ignores case and accents and tolerates
typos.

``KitoSearchScreen`` renders the whole experience from a model. Before anything
is typed it shows recent searches, trending chips and a category grid; while
searching it shows skeletons, suggestions, results grouped under section
headers, and empty and error states.

```swift
@State private var search = KitoSearchModel.local(restaurants, text: { $0.name },
                                                  trending: ["Nyama choma", "Pizza"])

var body: some View {
    KitoSearchScreen(model: search, prompt: "Restaurants, dishes, areas") { place, query in
        KitoSearchResultRow(title: place.name, subtitle: place.cuisine,
                            systemImage: "fork.knife", query: query)
    }
}
```

The building blocks are available on their own: ``KitoSearchField`` in four
styles with tokens and scopes, ``KitoHighlightedText`` for marking matched
text, and a filtering layer — ``KitoFilterConfiguration``, ``KitoFilterChips``
and ``KitoFilterSheet`` — whose ``KitoFilterState`` is a plain value you can
send to a backend or apply locally.

## Topics

### Search Model

- ``KitoSearchModel``
- ``KitoSearchRequest``
- ``KitoSearchPage``
- ``KitoSearchPhase``
- ``KitoSearchSuggestion``
- ``KitoSearchClock``
- ``KitoContinuousSearchClock``

### Search Screen

- ``KitoSearchScreen``
- ``KitoSearchResultRow``
- ``KitoSearchResultRowStyle``
- ``KitoSearchSkeletonRow``
- ``KitoSearchEmptyState``
- ``KitoSearchErrorState``
- ``KitoSearchCategory``

### Search Field

- ``KitoSearchField``
- ``KitoSearchFieldStyle``
- ``KitoSearchToken``
- ``KitoSearchScope``
- ``KitoSearchScopeBar``
- ``KitoVoiceSearchButton``

### Fuzzy Matching

- ``KitoFuzzy``
- ``KitoFuzzyMatch``
- ``KitoFuzzyResult``
- ``KitoHighlightedText``
- ``KitoHighlightStyle``

### Filters and Sorting

- ``KitoFilterConfiguration``
- ``KitoFilterState``
- ``KitoFilterAction``
- ``KitoFilterFacet``
- ``KitoFilterOption``
- ``KitoSortOption``
- ``KitoAppliedFilter``
- ``KitoFilterChips``
- ``KitoAppliedFilterPills``
- ``KitoFilterSheet``
- ``KitoRangeSlider``

### Recents and Paging

- ``KitoRecentSearches``
- ``KitoRecentSearchStore``
- ``KitoPagination``
- ``KitoRequestGate``
