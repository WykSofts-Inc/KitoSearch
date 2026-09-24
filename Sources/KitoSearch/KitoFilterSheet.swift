//
//  KitoFilterSheet.swift
//  KitoSearch
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A filter sheet: sort, chips with counts, a price range over a histogram, minimum rating,
/// distance and toggles — with "Clear all" and a button that counts the results live
/// ("Show 128 results") as you change things.
///
/// Changes are a draft until the button is pressed, so dismissing the sheet discards them.
///
/// ```swift
/// .sheet(isPresented: $showFilters) {
///     KitoFilterSheet(state: $search.filters, configuration: configuration, items: restaurants)
/// }
/// ```
///
/// Only the sections the configuration describes are shown (no `price` reader, no price section).
public struct KitoFilterSheet<Item>: View {
    @Binding private var state: KitoFilterState
    private let configuration: KitoFilterConfiguration<Item>
    private let items: [Item]
    private let title: String
    private let tint: Color?
    private let onApply: ((KitoFilterState) -> Void)?

    @State private var draft: KitoFilterState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - state: The applied filters; written when the results button is pressed.
    ///   - configuration: Which filters exist and how to read them.
    ///   - items: Counted live against the draft.
    ///   - onApply: Called with the new filters after they're applied.
    public init(
        state: Binding<KitoFilterState>,
        configuration: KitoFilterConfiguration<Item>,
        items: [Item],
        title: String = "Filters",
        tint: Color? = nil,
        onApply: ((KitoFilterState) -> Void)? = nil
    ) {
        _state = state
        _draft = State(initialValue: state.wrappedValue)
        self.configuration = configuration
        self.items = items
        self.title = title
        self.tint = tint
        self.onApply = onApply
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.xl) {
                    if !configuration.sorts.isEmpty { sortSection }
                    if !configuration.facets.isEmpty { facetSection }
                    if configuration.price != nil { priceSection }
                    if configuration.rating != nil { ratingSection }
                    if configuration.distance != nil { distanceSection }
                    if !configuration.toggles.isEmpty { toggleSection }
                }
                .padding(theme.spacing.lg)
                .padding(.bottom, theme.spacing.xl)
            }
            applyBar
        }
        .background(theme.colors.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.selection, trigger: draft)
    }

    private var accent: Color { tint ?? theme.colors.primary }
    private var liveCount: Int { configuration.count(draft, in: items) }

    private func update(_ action: KitoFilterAction) {
        withAnimation(KitoSearchMotion.snappy(reduceMotion)) { draft.reduce(action) }
    }

    // MARK: Header and footer

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(theme.typography.label.weight(.bold))
                    .foregroundStyle(theme.colors.onSurface)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(theme.colors.surfaceMuted))
            }
            .buttonStyle(KitoSearchPressStyle(scale: 0.9))
            .accessibilityLabel("Close")
            Spacer()
            Text(title)
                .font(theme.typography.titleMedium)
                .foregroundStyle(theme.colors.onBackground)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("Clear all") { update(.clearAll) }
                .font(theme.typography.label.weight(.semibold))
                .foregroundStyle(draft.isEmpty ? theme.colors.onBackground.opacity(0.3) : accent)
                .disabled(draft.isEmpty)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top, theme.spacing.lg)
        .padding(.bottom, theme.spacing.md)
    }

    private var applyBar: some View {
        let count = liveCount
        return Button {
            state = draft
            onApply?(draft)
            dismiss()
        } label: {
            Text(count == 0 ? "No results" : (count == 1 ? "Show 1 result" : "Show \(count.formatted()) results"))
                .contentTransition(.numericText(value: Double(count)))
                .animation(KitoSearchMotion.snappy(reduceMotion), value: count)
        }
        .buttonStyle(KitoSearchPrimaryButtonStyle(tint: tint, fullWidth: true))
        .disabled(count == 0)
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top, theme.spacing.md)
        .padding(.bottom, theme.spacing.sm)
        .background(applyBarBackground)
    }

    private var applyBarBackground: some View {
        theme.colors.background
            .shadow(color: theme.colors.onBackground.opacity(0.08), radius: 10, y: -4)
            .ignoresSafeArea()
    }

    // MARK: Sections

    private func sectionTitle(_ text: String, value: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(theme.typography.bodyEmphasized)
                .foregroundStyle(theme.colors.onBackground)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let value {
                Text(value)
                    .font(theme.typography.label)
                    .foregroundStyle(theme.colors.onBackground.opacity(0.6))
                    .contentTransition(.numericText())
            }
        }
    }

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            sectionTitle("Sort by")
            KitoFlowLayout(spacing: theme.spacing.sm, lineSpacing: theme.spacing.sm) {
                ForEach(configuration.sorts) { sort in
                    let option = KitoFilterOption(sort.id, title: sort.title, systemImage: sort.systemImage)
                    KitoFilterChip(option: option, isSelected: draft.sort == sort.id, accent: accent) {
                        update(.setSort(draft.sort == sort.id ? nil : sort.id))
                    }
                }
            }
        }
    }

    private var facetSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            sectionTitle(configuration.facetsTitle)
            KitoFlowLayout(spacing: theme.spacing.sm, lineSpacing: theme.spacing.sm) {
                ForEach(configuration.options(for: draft, in: items)) { option in
                    KitoFilterChip(option: option, isSelected: draft.facets.contains(option.id), accent: accent) {
                        update(.toggleFacet(option.id))
                    }
                }
            }
        }
    }

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            sectionTitle("Price", value: draft.price.map { configuration.priceText($0) } ?? "Any price")
            KitoFilterHistogram(counts: priceCounts, selection: priceFractions, accent: accent)
                .frame(height: 44)
                .padding(.horizontal, KitoRangeSlider.thumbSize / 2)
            KitoRangeSlider(
                range: priceBinding,
                in: configuration.priceBounds,
                step: configuration.priceStep,
                tint: tint,
                valueText: { configuration.priceText($0) }
            )
            HStack {
                Text(configuration.priceText(configuration.priceBounds.lowerBound))
                Spacer()
                Text(configuration.priceText(configuration.priceBounds.upperBound) + "+")
            }
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.onBackground.opacity(0.5))
        }
    }

    private var priceBinding: Binding<ClosedRange<Double>> {
        let bounds = configuration.priceBounds
        return Binding(
            get: { draft.price ?? bounds },
            set: { range in draft.reduce(.setPrice(range == bounds ? nil : range)) }
        )
    }

    private var priceCounts: [Int] {
        guard let price = configuration.price else { return [] }
        return KitoHistogram.counts(items.map(price), bounds: configuration.priceBounds, buckets: 24)
    }

    private var priceFractions: ClosedRange<Double> {
        let range = draft.price ?? configuration.priceBounds
        let lower = KitoRangeSliderMath.fraction(of: range.lowerBound, bounds: configuration.priceBounds)
        let upper = KitoRangeSliderMath.fraction(of: range.upperBound, bounds: configuration.priceBounds)
        return lower...max(lower, upper)
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            sectionTitle("Rating")
            KitoFlowLayout(spacing: theme.spacing.sm, lineSpacing: theme.spacing.sm) {
                KitoFilterChip(option: KitoFilterOption("any", title: "Any"), isSelected: draft.minimumRating == nil, accent: accent) {
                    update(.setMinimumRating(nil))
                }
                ForEach(configuration.ratingSteps, id: \.self) { step in
                    let option = KitoFilterOption("rating-\(step)", title: configuration.ratingText(step), systemImage: "star.fill")
                    KitoFilterChip(option: option, isSelected: draft.minimumRating == step, accent: accent) {
                        update(.setMinimumRating(step))
                    }
                }
            }
        }
    }

    private var distanceSection: some View {
        let bounds = configuration.distanceBounds
        return VStack(alignment: .leading, spacing: theme.spacing.md) {
            sectionTitle("Distance", value: draft.maximumDistance.map { configuration.distanceText($0) } ?? "Any distance")
            Slider(value: distanceBinding, in: bounds, step: distanceStep) {
                Text("Distance")
            } minimumValueLabel: {
                Image(systemName: "figure.walk").foregroundStyle(theme.colors.onBackground.opacity(0.5))
            } maximumValueLabel: {
                Image(systemName: "car.fill").foregroundStyle(theme.colors.onBackground.opacity(0.5))
            }
            .tint(accent)
            .accessibilityValue(draft.maximumDistance.map { configuration.distanceText($0) } ?? "Any distance")
        }
    }

    private var distanceStep: Double {
        let width = configuration.distanceBounds.upperBound - configuration.distanceBounds.lowerBound
        return width > 10 ? 1 : 0.5
    }

    private var distanceBinding: Binding<Double> {
        let upper = configuration.distanceBounds.upperBound
        return Binding(
            get: { draft.maximumDistance ?? upper },
            set: { value in draft.reduce(.setMaximumDistance(value >= upper ? nil : value)) }
        )
    }

    private var toggleSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            sectionTitle("More")
            VStack(spacing: 0) {
                ForEach(Array(configuration.toggles.enumerated()), id: \.element.id) { index, toggle in
                    toggleRow(toggle)
                    if index < configuration.toggles.count - 1 {
                        Rectangle().fill(theme.colors.border).frame(height: 1).padding(.leading, 52)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).fill(theme.colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous).strokeBorder(theme.colors.border, lineWidth: 1)
            )
        }
    }

    private func toggleRow(_ toggle: KitoFilterFacet<Item>) -> some View {
        let binding = Binding(
            get: { draft.toggles.contains(toggle.id) },
            set: { _ in update(.toggle(toggle.id)) }
        )
        return Toggle(isOn: binding) {
            HStack(spacing: theme.spacing.md) {
                Image(systemName: toggle.systemImage ?? "checkmark.circle")
                    .font(theme.typography.label.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: theme.radii.sm, style: .continuous).fill(accent.opacity(0.12)))
                Text(toggle.title)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.onSurface)
            }
        }
        .tint(accent)
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.sm)
    }
}

/// Bars showing how items spread across the price range, filled inside the selection.
struct KitoFilterHistogram: View {
    let counts: [Int]
    let selection: ClosedRange<Double>
    let accent: Color
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        let tallest = max(1, counts.max() ?? 1)
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(counts.enumerated()), id: \.offset) { index, count in
                UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                    .fill(isInside(index) ? accent.opacity(0.75) : theme.colors.border)
                    .frame(height: barHeight(count, tallest: tallest))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .animation(.snappy, value: selection)
        .accessibilityHidden(true)
    }

    private func barHeight(_ count: Int, tallest: Int) -> CGFloat {
        let fraction = CGFloat(count) / CGFloat(tallest)
        return max(3, fraction * 44)
    }

    private func isInside(_ index: Int) -> Bool {
        guard !counts.isEmpty else { return false }
        let centre = (Double(index) + 0.5) / Double(counts.count)
        return selection.contains(centre)
    }
}

/// A slider with two thumbs for picking a range.
///
/// ```swift
/// KitoRangeSlider(range: $price, in: 0...5_000, step: 100) { "KSh \(Int($0))" }
/// ```
///
/// Each thumb is its own adjustable element for VoiceOver ("Minimum, KSh 500").
public struct KitoRangeSlider: View {
    static let thumbSize: CGFloat = 28

    @Binding private var range: ClosedRange<Double>
    private let bounds: ClosedRange<Double>
    private let step: Double
    private let tint: Color?
    private let valueText: (Double) -> String

    @State private var dragging: Thumb?
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Thumb { case lower, upper }

    public init(
        range: Binding<ClosedRange<Double>>,
        in bounds: ClosedRange<Double>,
        step: Double = 1,
        tint: Color? = nil,
        valueText: @escaping (Double) -> String = { $0.formatted() }
    ) {
        _range = range
        self.bounds = bounds
        self.step = max(step, .ulpOfOne)
        self.tint = tint
        self.valueText = valueText
    }

    public var body: some View {
        GeometryReader { proxy in
            let track = max(1, proxy.size.width - Self.thumbSize)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.colors.surfaceMuted)
                    .frame(height: 6)
                    .padding(.horizontal, Self.thumbSize / 2)
                Capsule()
                    .fill(KitoSearchPalette.gradient(accent))
                    .frame(width: fillWidth(track), height: 6)
                    .offset(x: position(of: range.lowerBound, track: track) + Self.thumbSize / 2)
                thumb(.lower, track: track)
                thumb(.upper, track: track)
            }
            .frame(maxHeight: .infinity)
            .coordinateSpace(name: "KitoRangeSlider")
        }
        .frame(height: Self.thumbSize + 8)
        .sensoryFeedback(.selection, trigger: range)
    }

    private var accent: Color { tint ?? theme.colors.primary }

    private func position(of value: Double, track: CGFloat) -> CGFloat {
        CGFloat(KitoRangeSliderMath.fraction(of: value, bounds: bounds)) * track
    }

    private func fillWidth(_ track: CGFloat) -> CGFloat {
        max(0, position(of: range.upperBound, track: track) - position(of: range.lowerBound, track: track))
    }

    private func thumb(_ which: Thumb, track: CGFloat) -> some View {
        let value = which == .lower ? range.lowerBound : range.upperBound
        let isDragging = dragging == which
        return Circle()
            .fill(theme.colors.surface)
            .overlay(Circle().strokeBorder(accent, lineWidth: isDragging ? 3 : 2))
            .shadow(color: theme.colors.onBackground.opacity(0.18), radius: isDragging ? 8 : 4, y: 2)
            .frame(width: Self.thumbSize, height: Self.thumbSize)
            .scaleEffect(isDragging && !reduceMotion ? 1.15 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: isDragging)
            .offset(x: position(of: value, track: track))
            .gesture(drag(which, track: track))
            .accessibilityElement()
            .accessibilityLabel(which == .lower ? "Minimum" : "Maximum")
            .accessibilityValue(valueText(value))
            .accessibilityAdjustableAction { direction in adjust(which, direction) }
    }

    private func drag(_ which: Thumb, track: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("KitoRangeSlider"))
            .onChanged { gesture in
                dragging = which
                let fraction = Double((gesture.location.x - Self.thumbSize / 2) / track)
                move(which, to: KitoRangeSliderMath.value(at: fraction, bounds: bounds, step: step))
            }
            .onEnded { _ in dragging = nil }
    }

    private func move(_ which: Thumb, to value: Double) {
        switch which {
        case .lower:
            let lower = min(value, range.upperBound - step)
            range = max(bounds.lowerBound, lower)...range.upperBound
        case .upper:
            let upper = max(value, range.lowerBound + step)
            range = range.lowerBound...min(bounds.upperBound, upper)
        }
    }

    private func adjust(_ which: Thumb, _ direction: AccessibilityAdjustmentDirection) {
        let delta: Double
        switch direction {
        case .increment: delta = step
        case .decrement: delta = -step
        @unknown default: return
        }
        let current = which == .lower ? range.lowerBound : range.upperBound
        move(which, to: current + delta)
    }
}
