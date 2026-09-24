//
//  KitoSearchResultRow.swift
//  KitoSearch
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// How a `KitoSearchResultRow` is laid out.
public enum KitoSearchResultRowStyle: Sendable, CaseIterable {
    /// A compact row with a small tile, for long lists.
    case list
    /// A raised card with a rating and badge.
    case card
    /// A wide picture on top, for grids and visual results.
    case media
}

/// A search result: artwork, a title with the matched part highlighted, and supporting details.
///
/// ```swift
/// KitoSearchResultRow(title: place.name, subtitle: place.area, detail: "1.2 km",
///                     systemImage: "fork.knife", rating: 4.6, query: model.query, style: .card)
/// ```
public struct KitoSearchResultRow: View {
    private let title: String
    private let subtitle: String?
    private let detail: String?
    private let badge: String?
    private let systemImage: String
    private let image: Image?
    private let rating: Double?
    private let query: String
    private let style: KitoSearchResultRowStyle
    private let highlight: KitoHighlightStyle
    private let tint: Color?
    @Environment(\.kitoTheme) private var theme

    /// - Parameters:
    ///   - title: Highlighted where it matches `query`.
    ///   - subtitle: A second line, e.g. cuisine and area.
    ///   - detail: A short trailing value, e.g. "1.2 km" or "KSh 1,200".
    ///   - badge: A small label such as "Open" or "New".
    ///   - systemImage: Drawn on a colour tile when there's no `image`.
    ///   - image: A picture for the tile.
    ///   - rating: Shown with a star.
    ///   - query: The text to highlight in `title`.
    ///   - tint: The tile colour and highlight colour. Defaults to a theme colour picked from the title.
    public init(
        title: String,
        subtitle: String? = nil,
        detail: String? = nil,
        badge: String? = nil,
        systemImage: String = "magnifyingglass",
        image: Image? = nil,
        rating: Double? = nil,
        query: String = "",
        style: KitoSearchResultRowStyle = .list,
        highlight: KitoHighlightStyle = .tint,
        tint: Color? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.badge = badge
        self.systemImage = systemImage
        self.image = image
        self.rating = rating
        self.query = query
        self.style = style
        self.highlight = highlight
        self.tint = tint
    }

    public var body: some View {
        Group {
            switch style {
            case .list: listLayout
            case .card: cardLayout
            case .media: mediaLayout
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var tileColor: Color { tint ?? KitoSearchPalette.color(for: title, theme: theme) }

    private var titleText: some View {
        KitoHighlightedText(title, matching: query, style: highlight, font: theme.typography.bodyEmphasized, tint: tint)
            .lineLimit(1)
    }

    @ViewBuilder
    private var subtitleText: some View {
        if let subtitle {
            Text(subtitle)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.onSurface.opacity(0.6))
                .lineLimit(1)
        }
    }

    // MARK: List

    private var listLayout: some View {
        HStack(spacing: theme.spacing.md) {
            KitoResultArtwork(image: image, systemImage: systemImage, color: tileColor, cornerRadius: theme.radii.md)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                titleText
                subtitleText
            }
            Spacer(minLength: theme.spacing.sm)
            VStack(alignment: .trailing, spacing: theme.spacing.xxs) {
                if let detail {
                    Text(detail)
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(theme.colors.onSurface.opacity(0.7))
                }
                if let rating { KitoResultRating(rating: rating) }
            }
            Image(systemName: "chevron.forward")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.colors.onSurface.opacity(0.25))
                .accessibilityHidden(true)
        }
        .padding(.vertical, theme.spacing.xs)
        .contentShape(Rectangle())
    }

    // MARK: Card

    private var cardLayout: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            KitoResultArtwork(image: image, systemImage: systemImage, color: tileColor, cornerRadius: theme.radii.lg)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    titleText
                    Spacer(minLength: theme.spacing.xs)
                    if let badge { KitoResultBadge(text: badge, color: tileColor) }
                }
                subtitleText
                cardFooter
            }
        }
        .padding(theme.spacing.md)
        .background(cardBackground)
    }

    private var cardFooter: some View {
        HStack(spacing: theme.spacing.sm) {
            if let rating { KitoResultRating(rating: rating) }
            if rating != nil, detail != nil {
                Circle().fill(theme.colors.onSurface.opacity(0.25)).frame(width: 3, height: 3)
            }
            if let detail {
                Text(detail)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.onSurface.opacity(0.65))
            }
        }
        .padding(.top, theme.spacing.xxs)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous)
            .fill(theme.colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous)
                    .strokeBorder(theme.colors.border.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: theme.colors.onSurface.opacity(0.07), radius: 12, y: 6)
    }

    // MARK: Media

    private var mediaLayout: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            KitoResultArtwork(image: image, systemImage: systemImage, color: tileColor, cornerRadius: theme.radii.xl, large: true)
                .aspectRatio(16 / 10, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    if let badge {
                        KitoResultBadge(text: badge, color: theme.colors.onPrimary, onColor: true)
                            .padding(theme.spacing.sm)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if let rating {
                        KitoResultRating(rating: rating)
                            .padding(.horizontal, theme.spacing.sm)
                            .padding(.vertical, theme.spacing.xs)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(theme.spacing.sm)
                    }
                }
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                titleText
                subtitleText
                if let detail {
                    Text(detail)
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(tint ?? theme.colors.onSurface.opacity(0.75))
                }
            }
            .padding(.horizontal, theme.spacing.xxs)
        }
    }
}

/// A colour tile with a symbol, or a picture.
struct KitoResultArtwork: View {
    let image: Image?
    let systemImage: String
    let color: Color
    let cornerRadius: CGFloat
    var large = false
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            if let image {
                Color.clear.overlay { image.resizable().scaledToFill() }
            } else {
                shape.fill(KitoSearchPalette.gradient(color))
                Image(systemName: systemImage)
                    .font(large ? theme.typography.displayMedium : theme.typography.titleMedium)
                    .foregroundStyle(theme.colors.onPrimary.opacity(0.92))
                    .shadow(color: theme.colors.onBackground.opacity(0.18), radius: 3, y: 2)
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(theme.colors.onBackground.opacity(0.06), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

struct KitoResultRating: View {
    let rating: Double
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(theme.colors.warning)
            Text(rating.formatted(.number.precision(.fractionLength(1))))
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.onSurface)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rated \(rating.formatted(.number.precision(.fractionLength(1)))) out of 5")
    }
}

struct KitoResultBadge: View {
    let text: String
    let color: Color
    var onColor = false
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        Text(text)
            .font(theme.typography.caption.weight(.bold))
            .foregroundStyle(onColor ? theme.colors.onSurface : color)
            .padding(.horizontal, theme.spacing.sm)
            .padding(.vertical, 3)
            .background(Capsule().fill(onColor ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(color.opacity(0.14))))
            .fixedSize()
    }
}

/// A placeholder shaped like a result, with a shimmer, shown while the first page loads.
public struct KitoSearchSkeletonRow: View {
    private let style: KitoSearchResultRowStyle
    @Environment(\.kitoTheme) private var theme

    public init(style: KitoSearchResultRowStyle = .list) {
        self.style = style
    }

    public var body: some View {
        Group {
            switch style {
            case .list: row(tile: 44, radius: theme.radii.md)
            case .card: row(tile: 64, radius: theme.radii.lg)
                    .padding(theme.spacing.md)
                    .background(RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous).fill(theme.colors.surface))
            case .media: media
            }
        }
        .kitoSearchShimmer()
        .accessibilityHidden(true)
    }

    private var fill: Color { theme.colors.surfaceMuted }

    private func row(tile: CGFloat, radius: CGFloat) -> some View {
        HStack(spacing: theme.spacing.md) {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill).frame(width: tile, height: tile)
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                Capsule().fill(fill).frame(width: 150, height: 11)
                Capsule().fill(fill).frame(width: 96, height: 9)
            }
            Spacer()
            Capsule().fill(fill).frame(width: 34, height: 9)
        }
        .padding(.vertical, theme.spacing.xs)
    }

    private var media: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            RoundedRectangle(cornerRadius: theme.radii.xl, style: .continuous).fill(fill).aspectRatio(16 / 10, contentMode: .fit)
            Capsule().fill(fill).frame(width: 140, height: 11)
            Capsule().fill(fill).frame(width: 90, height: 9)
        }
    }
}
