//
//  KitoSearchField.swift
//  KitoSearch
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// How a `KitoSearchField` is drawn.
public enum KitoSearchFieldStyle: Sendable, CaseIterable {
    /// A filled capsule, like the system search bar.
    case capsule
    /// Frosted material with a light edge, for fields over imagery or colour.
    case glass
    /// Just a line underneath that fills with colour on focus.
    case underlined
    /// A tall, raised hero field for a home or landing screen.
    case prominent

    var height: CGFloat {
        switch self {
        case .capsule, .glass, .underlined: 44
        case .prominent: 58
        }
    }
}

/// A search field with an animated focus state, clear and cancel buttons, tokens inside the field,
/// an optional scope row and a trailing slot for a voice button or anything else.
///
/// ```swift
/// KitoSearchField(text: $query, prompt: "Restaurants, dishes, areas", style: .prominent,
///                 tokens: $tokens, onSubmit: { search($0) }) {
///     KitoVoiceSearchButton(isListening: listening) { toggleDictation() }
/// }
/// ```
///
/// On focus the field lifts and a focus ring grows around it, and Cancel slides in from the edge.
/// Return submits. With a hardware keyboard, Delete in an empty field removes the last token.
public struct KitoSearchField<Accessory: View>: View {
    @Binding private var text: String
    @Binding private var tokens: [KitoSearchToken]
    @Binding private var scope: String?
    private let prompt: String
    private let style: KitoSearchFieldStyle
    private let scopes: [KitoSearchScope]
    private let externalFocus: Binding<Bool>?
    private let showsCancelButton: Bool
    private let tint: Color?
    private let onSubmit: (String) -> Void
    private let onCancel: (() -> Void)?
    private let accessory: Accessory

    @FocusState private var focused: Bool
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - text: The query.
    ///   - prompt: Placeholder text.
    ///   - style: `.capsule`, `.glass`, `.underlined` or `.prominent`.
    ///   - tokens: Chips shown inside the field; each has a remove button.
    ///   - scopes: Segments shown under the field. Empty hides the row.
    ///   - scope: The selected scope id; `nil` selects the first.
    ///   - isFocused: Mirrors (and can set) keyboard focus.
    ///   - showsCancelButton: Whether Cancel slides in while focused.
    ///   - tint: Accent for the focus ring, icons and Cancel. Defaults to the theme's primary.
    ///   - onSubmit: Called with the text when Return is pressed.
    ///   - onCancel: Called after Cancel clears the field and dismisses the keyboard.
    ///   - accessory: A trailing slot, e.g. `KitoVoiceSearchButton`.
    public init(
        text: Binding<String>,
        prompt: String = "Search",
        style: KitoSearchFieldStyle = .capsule,
        tokens: Binding<[KitoSearchToken]> = .constant([]),
        scopes: [KitoSearchScope] = [],
        scope: Binding<String?> = .constant(nil),
        isFocused: Binding<Bool>? = nil,
        showsCancelButton: Bool = true,
        tint: Color? = nil,
        onSubmit: @escaping (String) -> Void = { _ in },
        onCancel: (() -> Void)? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        _text = text
        _tokens = tokens
        _scope = scope
        self.prompt = prompt
        self.style = style
        self.scopes = scopes
        self.externalFocus = isFocused
        self.showsCancelButton = showsCancelButton
        self.tint = tint
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        self.accessory = accessory()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack(spacing: theme.spacing.md) {
                field
                if focused && showsCancelButton {
                    cancelButton
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            if !scopes.isEmpty {
                KitoSearchScopeBar(scopes, selection: $scope, tint: tint)
            }
        }
        .animation(KitoSearchMotion.spring(reduceMotion), value: focused)
        .animation(KitoSearchMotion.spring(reduceMotion), value: text.isEmpty)
        .animation(KitoSearchMotion.spring(reduceMotion), value: tokens)
        .onChange(of: focused) { _, isFocused in
            if let externalFocus, externalFocus.wrappedValue != isFocused { externalFocus.wrappedValue = isFocused }
        }
        .onChange(of: externalFocus?.wrappedValue) { _, wanted in
            if let wanted, wanted != focused { focused = wanted }
        }
    }

    // MARK: Field

    private var accent: Color { tint ?? theme.colors.primary }

    private var cornerRadius: CGFloat {
        style == .prominent ? theme.radii.xl : style.height / 2
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var field: some View {
        HStack(spacing: theme.spacing.sm) {
            leadingIcon
            ForEach(tokens) { token in
                KitoSearchTokenChip(token: token, accent: accent) { remove(token) }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            textField
            if !text.isEmpty {
                clearButton.transition(.scale(scale: 0.4).combined(with: .opacity))
            }
            accessory
        }
        .padding(.horizontal, horizontalPadding)
        .frame(height: style.height)
        .background { background }
        .overlay { border }
        .scaleEffect(fieldScale)
        .contentShape(shape)
        .onTapGesture { focused = true }
    }

    private var horizontalPadding: CGFloat {
        switch style {
        case .underlined: theme.spacing.xxs
        case .prominent: theme.spacing.sm
        case .capsule, .glass: theme.spacing.md
        }
    }

    /// The field grows to full size as it takes focus.
    private var fieldScale: CGFloat {
        focused || reduceMotion ? 1 : 0.985
    }

    private var textField: some View {
        TextField("", text: $text, prompt: placeholder)
            .font(style == .prominent ? theme.typography.bodyEmphasized : theme.typography.body)
            .foregroundStyle(theme.colors.onSurface)
            .tint(accent)
            .focused($focused)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .onSubmit { onSubmit(text) }
            .onKeyPress(.delete) { removeLastTokenIfEmpty() }
            .accessibilityLabel(prompt)
    }

    private var placeholder: Text {
        Text(tokens.isEmpty ? prompt : "")
            .foregroundStyle(theme.colors.onSurface.opacity(0.45))
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if style == .prominent {
            Image(systemName: "magnifyingglass")
                .font(theme.typography.label.weight(.bold))
                .foregroundStyle(theme.colors.onPrimary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(KitoSearchPalette.gradient(accent)))
                .shadow(color: accent.opacity(0.35), radius: 6, y: 3)
                .symbolEffect(.bounce, value: focused)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "magnifyingglass")
                .font(theme.typography.body.weight(.semibold))
                .foregroundStyle(focused ? accent : theme.colors.onSurface.opacity(0.45))
                .symbolEffect(.bounce, value: focused)
                .accessibilityHidden(true)
        }
    }

    private var clearButton: some View {
        Button {
            text = ""
            focused = true
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.onSurface.opacity(0.35))
                .frame(minWidth: 28, minHeight: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(KitoSearchPressStyle(scale: 0.85))
        .accessibilityLabel("Clear text")
    }

    private var cancelButton: some View {
        Button("Cancel") {
            text = ""
            tokens = []
            focused = false
            onCancel?()
        }
        .font(theme.typography.bodyEmphasized)
        .foregroundStyle(accent)
        .buttonStyle(.plain)
        .fixedSize()
    }

    // MARK: Chrome

    @ViewBuilder
    private var background: some View {
        switch style {
        case .capsule:
            shape.fill(focused ? theme.colors.surface : theme.colors.surfaceMuted)
                .shadow(color: accent.opacity(focused ? 0.14 : 0), radius: 10, y: 4)
        case .glass:
            shape.fill(.ultraThinMaterial)
                .shadow(color: theme.colors.onBackground.opacity(0.12), radius: 12, y: 6)
        case .underlined:
            Color.clear
        case .prominent:
            shape.fill(theme.colors.surface)
                .shadow(color: accent.opacity(focused ? 0.28 : 0.14), radius: focused ? 24 : 14, y: focused ? 12 : 6)
        }
    }

    @ViewBuilder
    private var border: some View {
        switch style {
        case .underlined:
            KitoUnderline(isFocused: focused, accent: accent, rest: theme.colors.border)
        case .glass:
            shape.strokeBorder(glassEdge, lineWidth: 1)
                .overlay { focusRing }
        case .capsule, .prominent:
            shape.strokeBorder(focused ? accent : theme.colors.border.opacity(style == .capsule ? 0 : 1), lineWidth: focused ? 1.5 : 1)
                .overlay { focusRing }
        }
    }

    private var glassEdge: LinearGradient {
        let top = focused ? accent : theme.colors.surface.opacity(0.7)
        return LinearGradient(colors: [top, theme.colors.surface.opacity(0.12)], startPoint: .top, endPoint: .bottom)
    }

    /// A soft ring that grows outward on focus.
    private var focusRing: some View {
        shape
            .stroke(accent.opacity(focused ? 0.18 : 0), lineWidth: focused ? 6 : 0)
            .padding(focused ? -3 : 0)
            .allowsHitTesting(false)
    }

    // MARK: Tokens

    private func remove(_ token: KitoSearchToken) {
        tokens.removeAll { $0.id == token.id }
    }

    private func removeLastTokenIfEmpty() -> KeyPress.Result {
        guard text.isEmpty, !tokens.isEmpty else { return .ignored }
        tokens.removeLast()
        return .handled
    }
}

public extension KitoSearchField where Accessory == EmptyView {
    /// A search field without a trailing accessory.
    init(
        text: Binding<String>,
        prompt: String = "Search",
        style: KitoSearchFieldStyle = .capsule,
        tokens: Binding<[KitoSearchToken]> = .constant([]),
        scopes: [KitoSearchScope] = [],
        scope: Binding<String?> = .constant(nil),
        isFocused: Binding<Bool>? = nil,
        showsCancelButton: Bool = true,
        tint: Color? = nil,
        onSubmit: @escaping (String) -> Void = { _ in },
        onCancel: (() -> Void)? = nil
    ) {
        self.init(
            text: text, prompt: prompt, style: style, tokens: tokens, scopes: scopes, scope: scope,
            isFocused: isFocused, showsCancelButton: showsCancelButton, tint: tint,
            onSubmit: onSubmit, onCancel: onCancel
        ) { EmptyView() }
    }
}

/// The underline for `.underlined`: a hairline that fills with colour from the centre on focus.
private struct KitoUnderline: View {
    let isFocused: Bool
    let accent: Color
    let rest: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
            Rectangle().fill(rest).frame(height: 1)
            Capsule()
                .fill(accent)
                .frame(height: 2)
                .scaleEffect(x: isFocused ? 1 : 0.001, anchor: .center)
                .opacity(isFocused ? 1 : 0)
        }
        .allowsHitTesting(false)
    }
}

/// A token chip inside the field.
struct KitoSearchTokenChip: View {
    let token: KitoSearchToken
    let accent: Color
    let onRemove: () -> Void
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.xs) {
            if let systemImage = token.systemImage {
                Image(systemName: systemImage).font(.caption2.weight(.bold))
            }
            if !token.label.isEmpty {
                Text("\(token.label):").opacity(0.7)
            }
            Text(token.value).fontWeight(.semibold)
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.caption2.weight(.heavy))
                    .padding(.leading, theme.spacing.xxs)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
        .font(theme.typography.caption)
        .lineLimit(1)
        .foregroundStyle(accent)
        .padding(.horizontal, theme.spacing.sm)
        .padding(.vertical, theme.spacing.xs + 1)
        .background(Capsule().fill(accent.opacity(0.14)))
        .overlay(Capsule().strokeBorder(accent.opacity(0.25), lineWidth: 1))
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Filter \(token.text)")
        .accessibilityAction(named: "Remove") { onRemove() }
    }
}

/// Segments under a search field ("All", "People", "Places"), with a sliding selection.
public struct KitoSearchScopeBar: View {
    private let scopes: [KitoSearchScope]
    @Binding private var selection: String?
    private let tint: Color?
    @Namespace private var namespace
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - scopes: The segments.
    ///   - selection: The selected id; `nil` selects the first segment.
    public init(_ scopes: [KitoSearchScope], selection: Binding<String?>, tint: Color? = nil) {
        self.scopes = scopes
        _selection = selection
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(scopes) { scope in
                segment(scope)
            }
        }
        .padding(3)
        .background(Capsule().fill(theme.colors.surfaceMuted))
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func isSelected(_ scope: KitoSearchScope) -> Bool {
        selection == scope.id || (selection == nil && scope.id == scopes.first?.id)
    }

    private func segment(_ scope: KitoSearchScope) -> some View {
        let selected = isSelected(scope)
        return Button {
            withAnimation(KitoSearchMotion.snappy(reduceMotion)) { selection = scope.id }
        } label: {
            HStack(spacing: theme.spacing.xs) {
                if let systemImage = scope.systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selected ? (tint ?? theme.colors.primary) : theme.colors.onSurface.opacity(0.5))
                }
                Text(scope.title)
                    .font(theme.typography.label)
                    .foregroundStyle(selected ? theme.colors.onSurface : theme.colors.onSurface.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 32)
            .background { selectionPill(selected) }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func selectionPill(_ selected: Bool) -> some View {
        if selected {
            Capsule()
                .fill(theme.colors.surface)
                .shadow(color: theme.colors.onSurface.opacity(0.12), radius: 4, y: 2)
                .matchedGeometryEffect(id: "scope", in: namespace)
        }
    }
}

/// A microphone button for the search field's accessory slot. While listening it turns into a
/// live waveform with a soft pulse.
///
/// The button only reports taps; starting and stopping dictation is up to your app (for example
/// with the Speech framework, which needs `NSSpeechRecognitionUsageDescription` and
/// `NSMicrophoneUsageDescription` in your Info.plist).
public struct KitoVoiceSearchButton: View {
    private let isListening: Bool
    private let tint: Color?
    private let action: () -> Void
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isListening: Bool = false, tint: Color? = nil, action: @escaping () -> Void) {
        self.isListening = isListening
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                if isListening {
                    KitoVoicePulse(color: accent, animated: !reduceMotion)
                }
                Image(systemName: isListening ? "waveform" : "mic.fill")
                    .font(theme.typography.body.weight(.semibold))
                    .foregroundStyle(isListening ? accent : theme.colors.onSurface.opacity(0.55))
                    .symbolEffect(.variableColor.iterative, isActive: isListening && !reduceMotion)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 32, height: 32)
            .contentShape(Circle())
        }
        .buttonStyle(KitoSearchPressStyle(scale: 0.85))
        .sensoryFeedback(.impact(weight: .light), trigger: isListening)
        .accessibilityLabel(isListening ? "Stop voice search" : "Voice search")
    }

    private var accent: Color { tint ?? theme.colors.primary }
}

private struct KitoVoicePulse: View {
    let color: Color
    let animated: Bool
    @State private var expanded = false

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.16))
            Circle()
                .stroke(color.opacity(0.35), lineWidth: 2)
                .scaleEffect(expanded ? 1.5 : 1)
                .opacity(expanded ? 0 : 1)
        }
        .onAppear {
            guard animated else { return }
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) { expanded = true }
        }
    }
}
