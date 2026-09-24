//
//  KitoSearchStates.swift
//  KitoSearch
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A full-strength capsule: the text colour by default (black in light mode, white in dark), or
/// the tint when one is given.
struct KitoSearchPrimaryButtonStyle: ButtonStyle {
    var tint: Color?
    var fullWidth = false
    @Environment(\.kitoTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.typography.button)
            .foregroundStyle(tint == nil ? theme.colors.background : theme.colors.onPrimary)
            .padding(.horizontal, theme.spacing.xl)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 50)
            .background(Capsule().fill(tint ?? theme.colors.onBackground))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}

/// A capsule chip for trending searches and suggestions.
struct KitoSearchChip: View {
    let title: String
    var systemImage: String?
    var accent: Color
    let action: () -> Void
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                }
                Text(title)
                    .font(theme.typography.label)
                    .foregroundStyle(theme.colors.onSurface)
                    .lineLimit(1)
            }
            .padding(.horizontal, theme.spacing.md)
            .padding(.vertical, theme.spacing.sm)
            .background(Capsule().fill(theme.colors.surface))
            .overlay(Capsule().strokeBorder(theme.colors.border, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(KitoSearchPressStyle())
    }
}

// MARK: - Empty

/// "No results for “x”", with a spelling suggestion, other searches to try and a way out of filters.
public struct KitoSearchEmptyState: View {
    private let query: String
    private let correction: String?
    private let suggestions: [String]
    private let hasFilters: Bool
    private let tint: Color?
    private let onSelect: (String) -> Void
    private let onClearFilters: (() -> Void)?
    @Environment(\.kitoTheme) private var theme

    /// - Parameters:
    ///   - query: What was searched.
    ///   - correction: A likely spelling ("Did you mean pizza?").
    ///   - suggestions: Other searches to offer as chips.
    ///   - hasFilters: Shows "Clear filters" when filters may be hiding results.
    ///   - onSelect: Called with a correction or suggestion.
    public init(
        query: String,
        correction: String? = nil,
        suggestions: [String] = [],
        hasFilters: Bool = false,
        tint: Color? = nil,
        onSelect: @escaping (String) -> Void = { _ in },
        onClearFilters: (() -> Void)? = nil
    ) {
        self.query = query
        self.correction = correction
        self.suggestions = suggestions
        self.hasFilters = hasFilters
        self.tint = tint
        self.onSelect = onSelect
        self.onClearFilters = onClearFilters
    }

    private var accent: Color { tint ?? theme.colors.primary }

    public var body: some View {
        VStack(spacing: theme.spacing.lg) {
            KitoSearchEmptyArt(accent: accent)
            VStack(spacing: theme.spacing.sm) {
                Text(query.isEmpty ? "No results" : "No results for “\(query)”")
                    .font(theme.typography.titleMedium)
                    .foregroundStyle(theme.colors.onBackground)
                    .multilineTextAlignment(.center)
                Text(hasFilters ? "Try removing a filter, or search for something broader." : "Check the spelling, or search for something broader.")
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.onBackground.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            if let correction {
                Button { onSelect(correction) } label: {
                    Text("Did you mean ") + Text(correction).bold().foregroundColor(accent) + Text("?")
                }
                .font(theme.typography.bodyEmphasized)
                .foregroundStyle(theme.colors.onBackground)
                .buttonStyle(.plain)
            }
            if !suggestions.isEmpty {
                VStack(spacing: theme.spacing.sm) {
                    Text("Try")
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(theme.colors.onBackground.opacity(0.5))
                    KitoFlowLayout(spacing: theme.spacing.sm, lineSpacing: theme.spacing.sm) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            KitoSearchChip(title: suggestion, systemImage: "magnifyingglass", accent: accent) { onSelect(suggestion) }
                        }
                    }
                    .frame(maxWidth: 340)
                }
            }
            if hasFilters, let onClearFilters {
                Button("Clear filters", action: onClearFilters)
                    .buttonStyle(KitoSearchPrimaryButtonStyle(tint: tint))
            }
        }
        .padding(theme.spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

/// A magnifier over soft rings, gently searching back and forth.
private struct KitoSearchEmptyArt: View {
    let accent: Color
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var searching = false

    var body: some View {
        ZStack {
            Circle().fill(accent.opacity(0.06)).frame(width: 132, height: 132)
            Circle().fill(accent.opacity(0.10)).frame(width: 96, height: 96)
            Circle().fill(theme.colors.surface).frame(width: 66, height: 66)
                .shadow(color: accent.opacity(0.2), radius: 10, y: 4)
            Image(systemName: "magnifyingglass")
                .font(theme.typography.displayMedium)
                .foregroundStyle(accent)
                .rotationEffect(.degrees(searching ? 10 : -10))
                .offset(x: searching ? 4 : -4, y: searching ? -2 : 2)
            Image(systemName: "questionmark")
                .font(theme.typography.label.weight(.heavy))
                .foregroundStyle(theme.colors.onPrimary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(theme.colors.warning))
                .offset(x: 34, y: -34)
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { searching = true }
        }
    }
}

// MARK: - Error

/// "Something went wrong", the error's message and a Retry button.
public struct KitoSearchErrorState: View {
    private let message: String
    private let tint: Color?
    private let retry: () -> Void
    @Environment(\.kitoTheme) private var theme
    @State private var shake = 0

    public init(message: String, tint: Color? = nil, retry: @escaping () -> Void) {
        self.message = message
        self.tint = tint
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: theme.spacing.lg) {
            ZStack {
                Circle().fill(theme.colors.danger.opacity(0.10)).frame(width: 110, height: 110)
                Circle().fill(theme.colors.danger.opacity(0.16)).frame(width: 76, height: 76)
                Image(systemName: "wifi.exclamationmark")
                    .font(theme.typography.displayMedium)
                    .foregroundStyle(theme.colors.danger)
                    .symbolEffect(.bounce, value: shake)
            }
            .accessibilityHidden(true)
            VStack(spacing: theme.spacing.sm) {
                Text("Something went wrong")
                    .font(theme.typography.titleMedium)
                    .foregroundStyle(theme.colors.onBackground)
                Text(message)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.onBackground.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            Button {
                shake += 1
                retry()
            } label: {
                Label("Try again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(KitoSearchPrimaryButtonStyle(tint: tint))
        }
        .padding(theme.spacing.xl)
        .frame(maxWidth: .infinity)
        .onAppear { shake += 1 }
    }
}

// MARK: - Idle

/// What the screen shows before anything is typed: recents (swipe to delete), trending chips and a
/// category grid. Lives inside a `List`.
struct KitoSearchIdleSections: View {
    let recents: [String]
    let trending: [String]
    let categories: [KitoSearchCategory]
    let accent: Color
    let onSearch: (String) -> Void
    let onFill: (String) -> Void
    let onRemove: (String) -> Void
    let onClearRecents: () -> Void
    let onCategory: (KitoSearchCategory) -> Void
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        if !recents.isEmpty {
            Section {
                ForEach(recents, id: \.self) { recent in
                    recentRow(recent)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { onRemove(recent) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .accessibilityAction(named: "Delete") { onRemove(recent) }
                }
            } header: {
                KitoSearchSectionTitle(title: "Recent", systemImage: "clock", actionTitle: "Clear", action: onClearRecents)
            }
            .listRowBackground(Color.clear)
        }
        if !trending.isEmpty {
            Section {
                KitoFlowLayout(spacing: theme.spacing.sm, lineSpacing: theme.spacing.sm) {
                    ForEach(Array(trending.enumerated()), id: \.offset) { index, text in
                        KitoSearchChip(title: text, systemImage: index < 3 ? "flame.fill" : "arrow.up.right", accent: index < 3 ? theme.colors.warning : accent) {
                            onSearch(text)
                        }
                    }
                }
                .padding(.vertical, theme.spacing.xs)
                .listRowSeparator(.hidden)
            } header: {
                KitoSearchSectionTitle(title: "Trending", systemImage: "chart.line.uptrend.xyaxis")
            }
            .listRowBackground(Color.clear)
        }
        if !categories.isEmpty {
            Section {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: theme.spacing.md), GridItem(.flexible(), spacing: theme.spacing.md)], spacing: theme.spacing.md) {
                    ForEach(categories) { category in
                        KitoSearchCategoryTile(category: category) { onCategory(category) }
                    }
                }
                .padding(.vertical, theme.spacing.xs)
                .listRowSeparator(.hidden)
            } header: {
                KitoSearchSectionTitle(title: "Browse", systemImage: "square.grid.2x2")
            }
            .listRowBackground(Color.clear)
        }
    }

    private func recentRow(_ recent: String) -> some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.onSurface.opacity(0.4))
                .accessibilityHidden(true)
            Button { onSearch(recent) } label: {
                Text(recent)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button { onFill(recent) } label: {
                Image(systemName: "arrow.up.left")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.colors.onSurface.opacity(0.35))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(recent)")
        }
    }
}

/// A colourful category tile.
struct KitoSearchCategoryTile: View {
    let category: KitoSearchCategory
    let action: () -> Void
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous)
                    .fill(KitoSearchPalette.gradient(color))
                Image(systemName: category.systemImage)
                    .font(theme.typography.displayLarge)
                    .foregroundStyle(theme.colors.onPrimary.opacity(0.28))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 16, y: 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .clipped()
                Text(category.title)
                    .font(theme.typography.bodyEmphasized)
                    .foregroundStyle(theme.colors.onPrimary)
                    .padding(theme.spacing.md)
            }
            .frame(height: 84)
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous))
            .shadow(color: color.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(KitoSearchPressStyle())
        .accessibilityLabel("Browse \(category.title)")
    }

    private var color: Color { category.color ?? KitoSearchPalette.color(for: category.title, theme: theme) }
}

// MARK: - Suggestions

/// Live completions: a "Search for “x”" row, then suggestions with the matched part in bold.
struct KitoSearchSuggestionRows: View {
    let query: String
    let suggestions: [KitoSearchSuggestion]
    let accent: Color
    let onSubmit: () -> Void
    let onSearch: (String) -> Void
    let onFill: (String) -> Void
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        Button(action: onSubmit) {
            HStack(spacing: theme.spacing.md) {
                Image(systemName: "magnifyingglass")
                    .font(theme.typography.label.weight(.bold))
                    .foregroundStyle(theme.colors.onPrimary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(accent))
                Text("Search for ") + Text("“\(query)”").bold()
                Spacer(minLength: 0)
            }
            .font(theme.typography.body)
            .foregroundStyle(theme.colors.onSurface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)

        ForEach(suggestions) { suggestion in
            HStack(spacing: theme.spacing.md) {
                Image(systemName: icon(for: suggestion.source))
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.onSurface.opacity(0.4))
                    .frame(width: 30)
                    .accessibilityHidden(true)
                Button { onSearch(suggestion.text) } label: {
                    KitoHighlightedText(suggestion.text, ranges: suggestion.match.ranges, style: .bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button { onFill(suggestion.text) } label: {
                    Image(systemName: "arrow.up.left")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.colors.onSurface.opacity(0.35))
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit \(suggestion.text)")
            }
            .listRowBackground(Color.clear)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func icon(for source: KitoSearchSuggestion.Source) -> String {
        switch source {
        case .recent: "clock.arrow.circlepath"
        case .trending: "flame"
        case .suggested: "magnifyingglass"
        }
    }
}
