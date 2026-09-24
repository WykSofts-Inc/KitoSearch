//
//  KitoSearchScreen.swift
//  KitoSearch
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A complete search screen driven by a `KitoSearchModel`.
///
/// ```swift
/// KitoSearchScreen(model: search, prompt: "Restaurants, dishes, areas",
///                  categories: categories, section: \.neighbourhood) { place, query in
///     KitoSearchResultRow(title: place.name, subtitle: place.cuisine, query: query)
/// }
/// ```
///
/// - Before anything is typed: recent searches (swipe to delete), trending chips and a category grid.
/// - While typing in `.onSubmit` mode: suggestions with the matched part in bold, under a
///   "Search for “x”" row.
/// - While the first page loads: skeleton rows.
/// - Results: grouped under section headers, loading more as you reach the end.
/// - Nothing found: "No results for “x”", a spelling suggestion and other searches to try.
/// - Failure: the error and a Retry button.
public struct KitoSearchScreen<Item: Identifiable, Row: View, Header: View>: View {
    @Bindable private var model: KitoSearchModel<Item>
    private let prompt: String
    private let fieldStyle: KitoSearchFieldStyle
    private let scopes: [KitoSearchScope]
    private let categories: [KitoSearchCategory]
    private let skeletonStyle: KitoSearchResultRowStyle
    private let tint: Color?
    private let section: ((Item) -> String)?
    private let onSelect: ((Item) -> Void)?
    private let row: (Item, String) -> Row
    private let header: Header

    @State private var isFocused = false
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - model: The search state.
    ///   - prompt: Placeholder for the field.
    ///   - fieldStyle: How the field is drawn.
    ///   - scopes: Segments under the field, bound to `model.scope`.
    ///   - categories: The "Browse" grid; a tap adds the category's token.
    ///   - skeletonStyle: The shape of placeholder rows while loading; match your rows.
    ///   - tint: Accent colour. Defaults to the theme's primary.
    ///   - section: Groups results under headers.
    ///   - onSelect: Called when a result is tapped. The query is saved as a recent search.
    ///   - row: Draws a result; the second argument is the query, for highlighting.
    ///   - header: Shown under the field while searching, e.g. `KitoFilterChips`.
    public init(
        model: KitoSearchModel<Item>,
        prompt: String = "Search",
        fieldStyle: KitoSearchFieldStyle = .capsule,
        scopes: [KitoSearchScope] = [],
        categories: [KitoSearchCategory] = [],
        skeletonStyle: KitoSearchResultRowStyle = .list,
        tint: Color? = nil,
        section: ((Item) -> String)? = nil,
        onSelect: ((Item) -> Void)? = nil,
        @ViewBuilder row: @escaping (Item, String) -> Row,
        @ViewBuilder header: () -> Header
    ) {
        self.model = model
        self.prompt = prompt
        self.fieldStyle = fieldStyle
        self.scopes = scopes
        self.categories = categories
        self.skeletonStyle = skeletonStyle
        self.tint = tint
        self.section = section
        self.onSelect = onSelect
        self.row = row
        self.header = header()
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchBar
            if model.isActive {
                header.transition(.opacity.combined(with: .move(edge: .top)))
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .animation(KitoSearchMotion.snappy(reduceMotion), value: display)
        .onChange(of: model.phase) { _, phase in announce(phase) }
    }

    private var accent: Color { tint ?? theme.colors.primary }

    private var searchBar: some View {
        KitoSearchField(
            text: $model.query,
            prompt: prompt,
            style: fieldStyle,
            tokens: $model.tokens,
            scopes: scopes,
            scope: $model.scope,
            isFocused: $isFocused,
            tint: tint,
            onSubmit: { _ in model.submit() },
            onCancel: { model.clear() }
        )
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top, theme.spacing.sm)
        .padding(.bottom, theme.spacing.md)
    }

    // MARK: Content

    private enum Display: Equatable {
        case idle, suggestions, loading, results(dimmed: Bool), empty, error(String)
    }

    private var display: Display {
        guard model.isActive else { return .idle }
        switch model.phase {
        case .idle:
            return .idle
        case .typing:
            if model.trigger == .onSubmit, !model.trimmedQuery.isEmpty { return .suggestions }
            return model.results.isEmpty ? .loading : .results(dimmed: true)
        case .loading:
            return model.results.isEmpty ? .loading : .results(dimmed: true)
        case .results:
            return .results(dimmed: false)
        case .empty:
            return .empty
        case .error(let message):
            return .error(message)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch display {
        case .idle:
            idleList.transition(.opacity)
        case .suggestions:
            suggestionList.transition(.opacity)
        case .loading:
            skeletons.transition(.opacity)
        case .results(let dimmed):
            resultsList
                .opacity(dimmed ? 0.55 : 1)
                .transition(.opacity)
        case .empty:
            ScrollView { emptyState.padding(.top, theme.spacing.xl) }
                .scrollDismissesKeyboard(.immediately)
                .transition(.opacity)
        case .error(let message):
            ScrollView {
                KitoSearchErrorState(message: message, tint: tint) { model.retry() }
                    .padding(.top, theme.spacing.xl)
            }
            .transition(.opacity)
        }
    }

    private var idleList: some View {
        List {
            KitoSearchIdleSections(
                recents: model.recents.items,
                trending: model.trending,
                categories: categories,
                accent: accent,
                onSearch: { model.search($0) },
                onFill: fill,
                onRemove: { text in withAnimation(KitoSearchMotion.snappy(reduceMotion)) { model.removeRecent(text) } },
                onClearRecents: { withAnimation(KitoSearchMotion.snappy(reduceMotion)) { model.clearRecents() } },
                onCategory: { category in model.tokens = [category.token] }
            )
        }
        .kitoSearchList()
    }

    private var suggestionList: some View {
        List {
            KitoSearchSuggestionRows(
                query: model.trimmedQuery,
                suggestions: model.suggestions,
                accent: accent,
                onSubmit: { model.submit() },
                onSearch: { model.search($0) },
                onFill: fill
            )
        }
        .kitoSearchList()
    }

    private var skeletons: some View {
        ScrollView {
            VStack(spacing: theme.spacing.md) {
                ForEach(0..<6, id: \.self) { _ in
                    KitoSearchSkeletonRow(style: skeletonStyle)
                }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.top, theme.spacing.sm)
        }
        .scrollDisabled(true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading results")
    }

    private var emptyState: some View {
        KitoSearchEmptyState(
            query: model.trimmedQuery,
            correction: model.correction,
            suggestions: Array(model.trending.prefix(4)),
            hasFilters: model.filters.activeCount > 0,
            tint: tint,
            onSelect: { model.search($0) },
            onClearFilters: { model.filters = KitoFilterState() }
        )
    }

    // MARK: Results

    private var sections: [KitoSearchSection<Item>] {
        KitoSearchSection.grouped(model.results, by: section)
    }

    private var resultsList: some View {
        List {
            summary
            ForEach(sections) { group in
                Section {
                    ForEach(group.items) { item in
                        resultRow(item)
                    }
                } header: {
                    if let title = group.title {
                        KitoSearchSectionTitle(title: title)
                    }
                }
            }
            footer
        }
        .kitoSearchList()
    }

    @ViewBuilder
    private var summary: some View {
        let count = model.totalCount ?? model.results.count
        Text(count == 1 ? "1 result" : "\(count.formatted()) results")
            .font(theme.typography.caption.weight(.semibold))
            .foregroundStyle(theme.colors.onBackground.opacity(0.5))
            .contentTransition(.numericText())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    private func resultRow(_ item: Item) -> some View {
        Button {
            model.addRecent(model.trimmedQuery)
            onSelect?(item)
        } label: {
            row(item, model.trimmedQuery)
        }
        .buttonStyle(KitoSearchPressStyle(scale: 0.98))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(rowInsets)
        .onAppear { loadMoreIfLast(item) }
    }

    @ViewBuilder
    private var footer: some View {
        if model.isLoadingMore {
            KitoSearchSkeletonRow(style: skeletonStyle)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(rowInsets)
        } else if model.loadMoreFailed {
            Button { model.loadMore() } label: {
                Label("Couldn't load more. Try again", systemImage: "arrow.clockwise")
                    .font(theme.typography.label)
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(top: theme.spacing.xs, leading: theme.spacing.lg, bottom: theme.spacing.xs, trailing: theme.spacing.lg)
    }

    private func loadMoreIfLast(_ item: Item) {
        guard let last = model.results.last, last.id == item.id else { return }
        model.loadMore()
    }

    // MARK: Helpers

    private func fill(_ text: String) {
        model.query = text
        isFocused = true
    }

    private func announce(_ phase: KitoSearchPhase) {
        let message: String
        switch phase {
        case .results:
            let count = model.totalCount ?? model.results.count
            message = count == 1 ? "1 result" : "\(count) results"
        case .empty:
            message = "No results"
        case .error(let text):
            message = text
        case .idle, .typing, .loading:
            return
        }
        AccessibilityNotification.Announcement(message).post()
    }
}

public extension KitoSearchScreen where Header == EmptyView {
    /// A search screen without a header under the field.
    init(
        model: KitoSearchModel<Item>,
        prompt: String = "Search",
        fieldStyle: KitoSearchFieldStyle = .capsule,
        scopes: [KitoSearchScope] = [],
        categories: [KitoSearchCategory] = [],
        skeletonStyle: KitoSearchResultRowStyle = .list,
        tint: Color? = nil,
        section: ((Item) -> String)? = nil,
        onSelect: ((Item) -> Void)? = nil,
        @ViewBuilder row: @escaping (Item, String) -> Row
    ) {
        self.init(
            model: model, prompt: prompt, fieldStyle: fieldStyle, scopes: scopes, categories: categories,
            skeletonStyle: skeletonStyle, tint: tint, section: section, onSelect: onSelect, row: row
        ) { EmptyView() }
    }
}

extension View {
    /// The list look every search list shares: plain, on the theme background, keyboard away on scroll.
    func kitoSearchList() -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .listSectionSpacing(.compact)
    }
}
