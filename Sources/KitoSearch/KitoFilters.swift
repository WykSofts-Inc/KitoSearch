//
//  KitoFilters.swift
//  KitoSearch
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// The filters a person has picked. Plain values, so it can be saved, compared, sent to a
/// backend in `KitoSearchRequest`, or applied locally with `KitoFilterConfiguration`.
public struct KitoFilterState: Equatable, Hashable, Sendable {
    /// Selected chip ids. Several chips widen the search (Italian *or* Ethiopian).
    public var facets: Set<String>
    /// Switched-on toggle ids. Each one narrows the search (open now *and* delivers).
    public var toggles: Set<String>
    /// `nil` means any price.
    public var price: ClosedRange<Double>?
    /// `nil` means any rating.
    public var minimumRating: Double?
    /// `nil` means any distance.
    public var maximumDistance: Double?
    /// The chosen sort option id; `nil` keeps the search's own order.
    public var sort: String?

    public init(
        facets: Set<String> = [],
        toggles: Set<String> = [],
        price: ClosedRange<Double>? = nil,
        minimumRating: Double? = nil,
        maximumDistance: Double? = nil,
        sort: String? = nil
    ) {
        self.facets = facets
        self.toggles = toggles
        self.price = price
        self.minimumRating = minimumRating
        self.maximumDistance = maximumDistance
        self.sort = sort
    }

    /// How many filters are on — what the badge on a "Filters" button shows. Sorting isn't a filter.
    public var activeCount: Int {
        var count = facets.count + toggles.count
        if price != nil { count += 1 }
        if minimumRating != nil { count += 1 }
        if maximumDistance != nil { count += 1 }
        return count
    }

    /// No filters and no sort.
    public var isEmpty: Bool { activeCount == 0 && sort == nil }

    public mutating func reduce(_ action: KitoFilterAction) {
        switch action {
        case .toggleFacet(let id):
            if facets.remove(id) == nil { facets.insert(id) }
        case .toggle(let id):
            if toggles.remove(id) == nil { toggles.insert(id) }
        case .setPrice(let range):
            price = range
        case .setMinimumRating(let rating):
            minimumRating = (rating ?? 0) > 0 ? rating : nil
        case .setMaximumDistance(let distance):
            maximumDistance = distance
        case .setSort(let id):
            sort = id
        case .remove(let kind):
            remove(kind)
        case .clearAll:
            self = KitoFilterState()
        }
    }

    /// A copy with `action` applied.
    public func reduced(_ action: KitoFilterAction) -> KitoFilterState {
        var copy = self
        copy.reduce(action)
        return copy
    }

    private mutating func remove(_ kind: KitoAppliedFilter.Kind) {
        switch kind {
        case .facet(let id): facets.remove(id)
        case .toggle(let id): toggles.remove(id)
        case .price: price = nil
        case .rating: minimumRating = nil
        case .distance: maximumDistance = nil
        }
    }
}

/// Everything that can change a `KitoFilterState`.
public enum KitoFilterAction: Equatable, Sendable {
    case toggleFacet(String)
    case toggle(String)
    case setPrice(ClosedRange<Double>?)
    /// Zero or `nil` means any rating.
    case setMinimumRating(Double?)
    case setMaximumDistance(Double?)
    case setSort(String?)
    /// Removes one applied filter, as its pill's close button does.
    case remove(KitoAppliedFilter.Kind)
    /// Removes every filter and the sort.
    case clearAll
}

/// One filter that's on, as a removable pill ("Open now", "4.0+ ★", "Within 5 km").
public struct KitoAppliedFilter: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case facet(String), toggle(String), price, rating, distance
    }

    public var id: Kind { kind }
    public let kind: Kind
    public let title: String
    public let systemImage: String?

    public init(kind: Kind, title: String, systemImage: String? = nil) {
        self.kind = kind
        self.title = title
        self.systemImage = systemImage
    }
}

/// A chip as `KitoFilterChips` draws it, with the number of results it would show.
public struct KitoFilterOption: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var systemImage: String?
    /// Shown as a badge; `nil` hides it.
    public var count: Int?

    public init(_ id: String, title: String? = nil, systemImage: String? = nil, count: Int? = nil) {
        self.id = id
        self.title = title ?? id
        self.systemImage = systemImage
        self.count = count
    }
}

/// A yes/no test on an item — a chip ("Italian") or a toggle ("Open now").
public struct KitoFilterFacet<Item>: Identifiable {
    public let id: String
    public var title: String
    public var systemImage: String?
    public var matches: (Item) -> Bool

    public init(_ id: String, title: String? = nil, systemImage: String? = nil, matches: @escaping (Item) -> Bool) {
        self.id = id
        self.title = title ?? id
        self.systemImage = systemImage
        self.matches = matches
    }
}

/// One way to order results.
public struct KitoSortOption<Item>: Identifiable {
    public let id: String
    public var title: String
    public var systemImage: String?
    public var areInIncreasingOrder: (Item, Item) -> Bool

    public init(_ id: String, title: String? = nil, systemImage: String? = nil, by areInIncreasingOrder: @escaping (Item, Item) -> Bool) {
        self.id = id
        self.title = title ?? id
        self.systemImage = systemImage
        self.areInIncreasingOrder = areInIncreasingOrder
    }
}

/// Describes which filters exist for `Item` and how to read them, so a `KitoFilterState` can be
/// applied locally, counted live ("Show 128 results") and shown as pills.
public struct KitoFilterConfiguration<Item> {
    public var facetsTitle: String
    public var facets: [KitoFilterFacet<Item>]
    public var toggles: [KitoFilterFacet<Item>]
    public var price: ((Item) -> Double)?
    public var priceBounds: ClosedRange<Double>
    public var priceStep: Double
    /// ISO 4217 code used to format prices, e.g. "KES".
    public var currencyCode: String
    public var rating: ((Item) -> Double)?
    /// The "3.5+" style choices offered for rating.
    public var ratingSteps: [Double]
    public var distance: ((Item) -> Double)?
    public var distanceBounds: ClosedRange<Double>
    public var distanceUnit: String
    public var sorts: [KitoSortOption<Item>]

    public init(
        facetsTitle: String = "Categories",
        facets: [KitoFilterFacet<Item>] = [],
        toggles: [KitoFilterFacet<Item>] = [],
        price: ((Item) -> Double)? = nil,
        priceBounds: ClosedRange<Double> = 0...10_000,
        priceStep: Double = 100,
        currencyCode: String = "USD",
        rating: ((Item) -> Double)? = nil,
        ratingSteps: [Double] = [3, 3.5, 4, 4.5],
        distance: ((Item) -> Double)? = nil,
        distanceBounds: ClosedRange<Double> = 1...25,
        distanceUnit: String = "km",
        sorts: [KitoSortOption<Item>] = []
    ) {
        self.facetsTitle = facetsTitle
        self.facets = facets
        self.toggles = toggles
        self.price = price
        self.priceBounds = priceBounds
        self.priceStep = max(priceStep, .ulpOfOne)
        self.currencyCode = currencyCode
        self.rating = rating
        self.ratingSteps = ratingSteps
        self.distance = distance
        self.distanceBounds = distanceBounds
        self.distanceUnit = distanceUnit
        self.sorts = sorts
    }

    /// The items that pass `state`, in the chosen sort order.
    public func apply(_ state: KitoFilterState, to items: [Item]) -> [Item] {
        let kept = items.filter { passes($0, state, ignoringFacets: false) }
        guard let sort = sortOption(for: state) else { return kept }
        return kept.sorted(by: sort.areInIncreasingOrder)
    }

    /// How many items pass `state`.
    public func count(_ state: KitoFilterState, in items: [Item]) -> Int {
        items.reduce(0) { passes($1, state, ignoringFacets: false) ? $0 + 1 : $0 }
    }

    /// The chips, each counting the items it would show alongside every other filter that's on.
    public func options(for state: KitoFilterState, in items: [Item]) -> [KitoFilterOption] {
        let base = items.filter { passes($0, state, ignoringFacets: true) }
        return facets.map { facet in
            let count = base.reduce(0) { facet.matches($1) ? $0 + 1 : $0 }
            return KitoFilterOption(facet.id, title: facet.title, systemImage: facet.systemImage, count: count)
        }
    }

    /// The filters that are on, as pills.
    public func appliedFilters(for state: KitoFilterState) -> [KitoAppliedFilter] {
        var pills: [KitoAppliedFilter] = []
        for facet in facets where state.facets.contains(facet.id) {
            pills.append(KitoAppliedFilter(kind: .facet(facet.id), title: facet.title, systemImage: facet.systemImage))
        }
        for toggle in toggles where state.toggles.contains(toggle.id) {
            pills.append(KitoAppliedFilter(kind: .toggle(toggle.id), title: toggle.title, systemImage: toggle.systemImage))
        }
        if let range = state.price {
            pills.append(KitoAppliedFilter(kind: .price, title: priceText(range), systemImage: "banknote"))
        }
        if let rating = state.minimumRating {
            pills.append(KitoAppliedFilter(kind: .rating, title: ratingText(rating), systemImage: "star.fill"))
        }
        if let distance = state.maximumDistance {
            pills.append(KitoAppliedFilter(kind: .distance, title: distanceText(distance), systemImage: "location"))
        }
        return pills
    }

    public func sortOption(for state: KitoFilterState) -> KitoSortOption<Item>? {
        guard let id = state.sort else { return nil }
        return sorts.first { $0.id == id }
    }

    // MARK: Text

    public func priceText(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode).precision(.fractionLength(0)))
    }

    public func priceText(_ range: ClosedRange<Double>) -> String {
        "\(priceText(range.lowerBound))–\(priceText(range.upperBound))"
    }

    public func ratingText(_ rating: Double) -> String {
        "\(rating.formatted(.number.precision(.fractionLength(1))))+"
    }

    public func distanceText(_ distance: Double) -> String {
        "Within \(distance.formatted(.number.precision(.fractionLength(0...1)))) \(distanceUnit)"
    }

    // MARK: Matching

    func passes(_ item: Item, _ state: KitoFilterState, ignoringFacets: Bool) -> Bool {
        if !ignoringFacets, !passesFacets(item, state) { return false }
        for toggle in toggles where state.toggles.contains(toggle.id) {
            if !toggle.matches(item) { return false }
        }
        if let range = state.price, let price, !range.contains(price(item)) { return false }
        if let minimum = state.minimumRating, let rating, rating(item) < minimum { return false }
        if let maximum = state.maximumDistance, let distance, distance(item) > maximum { return false }
        return true
    }

    private func passesFacets(_ item: Item, _ state: KitoFilterState) -> Bool {
        let selected = facets.filter { state.facets.contains($0.id) }
        guard !selected.isEmpty else { return true }
        return selected.contains { $0.matches(item) }
    }
}

/// Bucket counts for the little histogram drawn behind a price range slider.
public enum KitoHistogram {
    public static func counts(_ values: [Double], bounds: ClosedRange<Double>, buckets: Int) -> [Int] {
        guard buckets > 0 else { return [] }
        var counts = [Int](repeating: 0, count: buckets)
        let width = bounds.upperBound - bounds.lowerBound
        guard width > 0 else {
            counts[0] = values.count
            return counts
        }
        for value in values {
            let clamped = min(max(value, bounds.lowerBound), bounds.upperBound)
            let position = (clamped - bounds.lowerBound) / width * Double(buckets)
            counts[min(buckets - 1, Int(position))] += 1
        }
        return counts
    }
}

/// Maps between a slider position (0…1) and a stepped value.
public enum KitoRangeSliderMath {
    public static func value(at fraction: Double, bounds: ClosedRange<Double>, step: Double) -> Double {
        let clampedFraction = min(max(fraction, 0), 1)
        let width = bounds.upperBound - bounds.lowerBound
        let raw = clampedFraction * width
        let snapped = step > 0 ? (raw / step).rounded() * step : raw
        return min(max(bounds.lowerBound + snapped, bounds.lowerBound), bounds.upperBound)
    }

    public static func fraction(of value: Double, bounds: ClosedRange<Double>) -> Double {
        let width = bounds.upperBound - bounds.lowerBound
        guard width > 0 else { return 0 }
        return min(max((value - bounds.lowerBound) / width, 0), 1)
    }
}
