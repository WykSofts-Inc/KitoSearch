# KitoSearch

Search for SwiftUI: a search field in four styles, a model that debounces, cancels stale requests and
pages results, typo-tolerant local matching, and a ready-made search screen with recents, trending,
categories, suggestions, skeletons, empty and error states. Filter chips with counts and a filter
sheet with a live "Show 128 results" button. Part of the [Kito](https://github.com/WykSofts-Inc/KitoDevKit) ecosystem.

## A search screen in one view

```swift
@State private var search = KitoSearchModel<Restaurant> { request in
    let page = try await api.restaurants(matching: request.query, page: request.page)
    return KitoSearchPage(items: page.items, hasMore: page.hasNext, totalCount: page.total)
}

KitoSearchScreen(model: search, prompt: "Restaurants, dishes, areas",
                 categories: [KitoSearchCategory("Restaurants", systemImage: "fork.knife")],
                 section: { $0.neighbourhood }) { place, query in
    KitoSearchResultRow(title: place.name, subtitle: place.cuisine, detail: "1.2 km",
                        systemImage: "fork.knife", rating: place.rating, query: query)
}
```

Before anything is typed the screen shows recent searches (swipe to delete), trending chips and a
category grid. Tapping a category puts a token such as "in: Restaurants" inside the field. Results
load more as you reach the end, grouped under section headers.

## Searching an array

```swift
@State private var search = KitoSearchModel.local(restaurants, text: { $0.name },
                                                  trending: ["Nyama choma", "Pizza"])
```

`KitoFuzzy` ignores case and accents and tolerates typos, so "nyamma" finds "Nyama Mama" and
"resturant" finds "Restaurant". Use it directly too:

```swift
KitoFuzzy.match("java kil", in: "Java House Kilimani")   // score 0.88, ranges [0..<4, 11..<14]
KitoFuzzy.filter(places, query: query) { $0.name }        // best first
KitoHighlightedText("Java House Kilimani", matching: "java kil", style: .marker)
```

## The model

```swift
let search = KitoSearchModel<Product>(debounce: .milliseconds(300), pageSize: 20,
                                      trigger: .live,                  // or .onSubmit
                                      recentsKey: "shop.recents",     // UserDefaults, nil for memory only
                                      trending: ["Sneakers", "Kikoi"]) { request in … }
search.query = "sneak"        // debounced; a newer query cancels the older request
search.submit()               // now, and saved as a recent search
search.loadMore()
search.phase                  // .idle, .typing, .loading, .results, .empty, .error(message)
search.suggestions            // from recents, trending and `suggestionPool`, matched part marked
search.correction             // "Did you mean …?"
```

Inject a `KitoSearchClock` to control the debounce in tests.

## The search bar

```swift
KitoSearchBar(text: $query, prompt: "Search", style: .prominent,   // .capsule, .glass, .underlined
              tokens: $tokens, scopes: [KitoSearchScope("all"), KitoSearchScope("people")],
              scope: $scope, onSubmit: { run($0) }) {
    KitoVoiceSearchButton(isListening: listening) { toggleDictation() }
}
```

The voice button only reports taps. If you add dictation with the Speech framework, your app needs
`NSSpeechRecognitionUsageDescription` and `NSMicrophoneUsageDescription` in its Info.plist.

## Filters

```swift
let filters = KitoFilterConfiguration<Restaurant>(
    facets: [KitoFilterFacet("kenyan", title: "Kenyan") { $0.cuisine == .kenyan }],
    toggles: [KitoFilterFacet("open", title: "Open now", systemImage: "clock") { $0.isOpen }],
    price: { $0.price }, priceBounds: 0...5_000, currencyCode: "KES",
    rating: { $0.rating }, distance: { $0.distance },
    sorts: [KitoSortOption("rating", title: "Top rated") { $0.rating > $1.rating }])

KitoFilterChips(filters.options(for: state, in: restaurants), selection: $state.facets,
                activeFilters: state.activeCount) { showSheet = true }
KitoAppliedFilterPills(filters.appliedFilters(for: state),
                       onRemove: { state.reduce(.remove($0.kind)) }, onClearAll: { state.reduce(.clearAll) })
    .sheet(isPresented: $showSheet) {
        KitoFilterSheet(state: $state, configuration: filters, items: restaurants)
    }
```

`KitoFilterState` is a plain value: send it to your backend in `KitoSearchRequest.filters`, or apply
it locally with `configuration.apply(state, to: items)`.

## Migrating from 0.1

0.2.0 renames `KitoSearchField` to `KitoSearchBar`, so KitoSearch can be imported in the same file
as KitoFields (which has its own `KitoSearchField`) without "ambiguous" errors. Its initialiser is
unchanged, and `KitoSearchFieldStyle` keeps its name.

## Installation

```swift
.package(url: "https://github.com/WykSofts-Inc/KitoSearch.git", from: "0.2.0")
```

## License

MIT — see [LICENSE](LICENSE).
