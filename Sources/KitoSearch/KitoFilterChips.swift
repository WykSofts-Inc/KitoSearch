//
//  KitoFilterChips.swift
//  KitoSearch
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A scrolling row of multi-select chips with result counts, optionally led by a "Filters" button
/// that shows how many filters are on.
///
/// ```swift
/// KitoFilterChips(configuration.options(for: filters, in: restaurants),
///                 selection: $filters.facets,
///                 activeFilters: filters.activeCount) { showFilters = true }
/// ```
public struct KitoFilterChips: View {
    private let options: [KitoFilterOption]
    @Binding private var selection: Set<String>
    private let tint: Color?
    private let activeFilters: Int
    private let onShowFilters: (() -> Void)?
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - options: The chips. A chip whose count is zero is dimmed unless it's selected.
    ///   - selection: Selected chip ids.
    ///   - activeFilters: The badge on the "Filters" button.
    ///   - onShowFilters: Shows a leading "Filters" button that calls this, e.g. to open `KitoFilterSheet`.
    public init(
        _ options: [KitoFilterOption],
        selection: Binding<Set<String>>,
        tint: Color? = nil,
        activeFilters: Int = 0,
        onShowFilters: (() -> Void)? = nil
    ) {
        self.options = options
        _selection = selection
        self.tint = tint
        self.activeFilters = activeFilters
        self.onShowFilters = onShowFilters
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.sm) {
                if let onShowFilters {
                    KitoFiltersButton(count: activeFilters, accent: accent, action: onShowFilters)
                    Rectangle()
                        .fill(theme.colors.border)
                        .frame(width: 1, height: 22)
                        .accessibilityHidden(true)
                }
                ForEach(options) { option in
                    KitoFilterChip(option: option, isSelected: selection.contains(option.id), accent: accent) {
                        toggle(option.id)
                    }
                }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.vertical, theme.spacing.xs)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var accent: Color { tint ?? theme.colors.primary }

    private func toggle(_ id: String) {
        withAnimation(KitoSearchMotion.snappy(reduceMotion)) {
            if selection.remove(id) == nil { selection.insert(id) }
        }
    }
}

/// One selectable chip with a count badge.
struct KitoFilterChip: View {
    let option: KitoFilterOption
    let isSelected: Bool
    let accent: Color
    let action: () -> Void
    @Environment(\.kitoTheme) private var theme

    private var isDimmed: Bool { option.count == 0 && !isSelected }

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.xs) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.heavy))
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                } else if let systemImage = option.systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
                Text(option.title)
                    .font(theme.typography.label)
                    .lineLimit(1)
                if let count = option.count {
                    countBadge(count)
                }
            }
            .foregroundStyle(isSelected ? theme.colors.onPrimary : theme.colors.onSurface)
            .padding(.leading, theme.spacing.md)
            .padding(.trailing, option.count == nil ? theme.spacing.md : theme.spacing.sm)
            .padding(.vertical, theme.spacing.sm)
            .background(chipBackground)
            .contentShape(Capsule())
        }
        .buttonStyle(KitoSearchPressStyle())
        .opacity(isDimmed ? 0.45 : 1)
        .accessibilityLabel(option.title)
        .accessibilityValue(option.count.map { "\($0) results" } ?? "")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func countBadge(_ count: Int) -> some View {
        Text(count.formatted())
            .font(theme.typography.caption.weight(.bold))
            .monospacedDigit()
            .contentTransition(.numericText())
            .padding(.horizontal, theme.spacing.xs + 2)
            .padding(.vertical, theme.spacing.xxs)
            .background(Capsule().fill(isSelected ? theme.colors.onPrimary.opacity(0.22) : theme.colors.surfaceMuted))
            .animation(.snappy, value: count)
    }

    private var chipBackground: some View {
        ZStack {
            Capsule().fill(isSelected ? AnyShapeStyle(KitoSearchPalette.gradient(accent)) : AnyShapeStyle(theme.colors.surface))
            Capsule().strokeBorder(isSelected ? Color.clear : theme.colors.border, lineWidth: 1)
        }
        .shadow(color: accent.opacity(isSelected ? 0.3 : 0), radius: 6, y: 3)
    }
}

/// "Filters" with a slider icon and a count badge.
struct KitoFiltersButton: View {
    let count: Int
    let accent: Color
    let action: () -> Void
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.xs) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption.weight(.bold))
                Text("Filters")
                    .font(theme.typography.label)
                if count > 0 {
                    Text("\(count)")
                        .font(theme.typography.caption.weight(.bold))
                        .foregroundStyle(theme.colors.onPrimary)
                        .contentTransition(.numericText())
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Circle().fill(accent))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .foregroundStyle(theme.colors.onSurface)
            .padding(.horizontal, theme.spacing.md)
            .padding(.vertical, theme.spacing.sm)
            .background(Capsule().fill(theme.colors.surfaceMuted))
            .contentShape(Capsule())
            .animation(.spring(duration: 0.3, bounce: 0.4), value: count)
        }
        .buttonStyle(KitoSearchPressStyle())
        .accessibilityLabel("Filters")
        .accessibilityValue(count == 0 ? "None" : "\(count) on")
    }
}

/// The filters that are on, as pills with a remove button, and "Clear all".
///
/// ```swift
/// KitoAppliedFilterPills(configuration.appliedFilters(for: filters),
///                        onRemove: { filters.reduce(.remove($0.kind)) },
///                        onClearAll: { filters.reduce(.clearAll) })
/// ```
public struct KitoAppliedFilterPills: View {
    private let filters: [KitoAppliedFilter]
    private let tint: Color?
    private let onRemove: (KitoAppliedFilter) -> Void
    private let onClearAll: (() -> Void)?
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        _ filters: [KitoAppliedFilter],
        tint: Color? = nil,
        onRemove: @escaping (KitoAppliedFilter) -> Void,
        onClearAll: (() -> Void)? = nil
    ) {
        self.filters = filters
        self.tint = tint
        self.onRemove = onRemove
        self.onClearAll = onClearAll
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.sm) {
                ForEach(filters) { filter in
                    pill(filter)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
                if filters.count > 1, let onClearAll {
                    Button("Clear all") {
                        withAnimation(KitoSearchMotion.snappy(reduceMotion)) { onClearAll() }
                    }
                    .font(theme.typography.label.weight(.semibold))
                    .foregroundStyle(theme.colors.onBackground.opacity(0.6))
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.vertical, theme.spacing.xs)
        }
        .animation(KitoSearchMotion.spring(reduceMotion), value: filters)
    }

    private var accent: Color { tint ?? theme.colors.primary }

    private func pill(_ filter: KitoAppliedFilter) -> some View {
        Button {
            withAnimation(KitoSearchMotion.snappy(reduceMotion)) { onRemove(filter) }
        } label: {
            HStack(spacing: theme.spacing.xs) {
                if let systemImage = filter.systemImage {
                    Image(systemName: systemImage).font(.caption2.weight(.bold))
                }
                Text(filter.title)
                    .font(theme.typography.caption.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "xmark.circle.fill")
                    .font(theme.typography.label)
                    .foregroundStyle(accent.opacity(0.55))
            }
            .foregroundStyle(accent)
            .padding(.leading, theme.spacing.sm + 2)
            .padding(.trailing, theme.spacing.xs + 2)
            .padding(.vertical, theme.spacing.xs + 2)
            .background(Capsule().fill(accent.opacity(0.12)))
            .overlay(Capsule().strokeBorder(accent.opacity(0.25), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(KitoSearchPressStyle())
        .accessibilityLabel("Remove filter \(filter.title)")
    }
}
