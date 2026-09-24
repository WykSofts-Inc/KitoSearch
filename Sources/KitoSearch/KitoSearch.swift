//
//  KitoSearch.swift
//  KitoSearch
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

// Small pieces shared by the views in this package.

enum KitoSearchMotion {
    /// The package's one spring, or none under Reduce Motion.
    static func spring(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(duration: 0.38, bounce: 0.28)
    }

    static func snappy(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : .snappy(duration: 0.3)
    }
}

/// Scales down a little while pressed.
struct KitoSearchPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(pressedScale(configuration.isPressed))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }

    private func pressedScale(_ isPressed: Bool) -> CGFloat {
        isPressed && !reduceMotion ? scale : 1
    }
}

/// Picks a stable theme colour for a piece of text, so tiles and avatars vary without a palette.
enum KitoSearchPalette {
    static func color(for text: String, theme: KitoTheme) -> Color {
        let palette = [theme.colors.primary, theme.colors.success, theme.colors.warning, theme.colors.danger, theme.colors.secondary]
        let hash = text.unicodeScalars.reduce(5_381) { ($0 &* 33 &+ Int($1.value)) & 0xFFFFFF }
        return palette[hash % palette.count]
    }

    static func gradient(_ color: Color) -> LinearGradient {
        LinearGradient(colors: [color.opacity(0.95), color.opacity(0.62)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Lays out children left to right, wrapping onto new lines.
struct KitoFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal: proposal, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(proposal: proposal, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// A soft light sweeping across placeholder shapes. Under Reduce Motion it gently pulses instead.
struct KitoShimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.kitoTheme) private var theme
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay { sweep.mask(content) }
            .onAppear(perform: start)
    }

    private var sweep: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [.clear, theme.colors.surface.opacity(0.75), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: proxy.size.width * 0.6)
            .offset(x: sweepOffset(proxy.size.width))
        }
        .opacity(reduceMotion ? 0 : 1)
        .allowsHitTesting(false)
    }

    private func sweepOffset(_ width: CGFloat) -> CGFloat {
        phase * width * 1.4
    }

    private func start() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) { phase = 1.2 }
    }
}

extension View {
    func kitoSearchShimmer() -> some View {
        modifier(KitoShimmer())
    }

    /// Applies `transform` only when `condition` is true.
    @ViewBuilder
    func kitoSearchIf<Content: View>(_ condition: Bool, _ transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

/// A small uppercase-free section title with an optional trailing button.
struct KitoSearchSectionTitle: View {
    let title: String
    var systemImage: String?
    var actionTitle: String?
    var action: (() -> Void)?
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.colors.onBackground.opacity(0.5))
            }
            Text(title)
                .font(theme.typography.label.weight(.semibold))
                .foregroundStyle(theme.colors.onBackground)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: theme.spacing.sm)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(theme.typography.label)
                    .foregroundStyle(theme.colors.onBackground.opacity(0.6))
                    .buttonStyle(.plain)
            }
        }
        .textCase(nil)
    }
}
