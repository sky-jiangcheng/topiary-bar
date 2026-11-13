import AppKit
import SwiftUI

// MARK: - Brand

/// The product brand, single source of truth for every surface.
enum Brand {
    static let name = "Topiary"
}

// MARK: - Design tokens

/// Shared design tokens. The pre-redesign UI hardcoded radii, opacities and
/// per-type hues in every view, and the copies drifted apart over time; the
/// shared components below read from here so all five surfaces (main window,
/// popover, aggregation panel, settings, order) stay consistent.
enum Theme {
    /// Corner radii for containers. App icons carry their own squircle
    /// artwork (macOS 11+), so radii never clip icons.
    enum Radius {
        static let control: CGFloat = 8
        static let tile: CGFloat = 10
        static let card: CGFloat = 12
    }

    /// Canonical spacing scale. Use these instead of inline literals so all
    /// surfaces share the same rhythm.
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    /// Semantic color aliases. Views reference these names so intent is clear
    /// and a future palette swap only touches this file.
    ///
    /// Colour budget, in one place: system blue is reserved for controls
    /// (selection, prominent buttons), orange for warning and destructive
    /// affordances, and the brand green below for the product talking about
    /// itself and for the memory readout. Green is deliberately never a
    /// control colour — a tinted button would compete with the user's own
    /// accent choice and quietly turn a brand colour into a status colour.
    enum Color {
        /// Warning / destructive accent (occlusion banners, Quit affordances).
        static let warning = SwiftUI.Color.orange
        /// Subtle fill for secondary containers (search fields, section headers).
        static let secondaryFill = SwiftUI.Color.secondary.opacity(0.1)
        /// Slightly stronger fill for cards and memory bars.
        static let tertiaryFill = SwiftUI.Color.secondary.opacity(0.08)

        /// The brand hue — the icon's own green, lifted to a mid tone.
        ///
        /// `#2E7D52` on light (5.03:1 on white) and `#7CBE96` on dark
        /// (7.83:1 on the dark canvas); the pair is the contract shared with
        /// `tools/generate_app_icon.py` (BRAND_GREEN) and the website
        /// (`--brand`), and `--check-brand` fails the build if any of the
        /// three drifts apart. Do not use one on the other mode's ground:
        /// #2E7D52 only reaches 3.38:1 on dark, #7CBE96 only 2.17:1 on light.
        static let brand = SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return isDark
                ? NSColor(srgbRed: 124 / 255, green: 190 / 255, blue: 150 / 255, alpha: 1)
                : NSColor(srgbRed: 46 / 255, green: 125 / 255, blue: 82 / 255, alpha: 1)
        })
    }
}

// MARK: - App icon

/// Renders an app icon at a fixed size with identical treatment on every
/// surface. macOS icons ship pre-rounded, so no extra clipping; the
/// placeholder covers apps whose icon is not (yet) available.
struct AppIconView: View {
    let icon: NSImage?
    let size: CGFloat

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.7))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 0.5)
    }
}

// MARK: - App row (shared)

/// Data-only row content shared by the popover list and the main-window
/// sidebar: icon, name (+ optional trailing accessory) and memory footprint.
/// Each surface wraps it with its own paddings and hover actions so the brand
/// reads identically everywhere while behavior stays surface-specific.
struct AppRowContent<Accessory: View>: View {
    let item: MenuBarMonitor.MenuBarItem
    var iconSize: CGFloat
    var nameFont: Font
    var nameAccessory: Accessory

    init(
        item: MenuBarMonitor.MenuBarItem,
        iconSize: CGFloat = 28,
        nameFont: Font = .body,
        @ViewBuilder nameAccessory: () -> Accessory = { EmptyView() }
    ) {
        self.item = item
        self.iconSize = iconSize
        self.nameFont = nameFont
        self.nameAccessory = nameAccessory()
    }

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(icon: item.icon, size: iconSize)

            Text(item.processName)
                .font(nameFont)
                .lineLimit(1)
                .foregroundStyle(.primary)

            nameAccessory

            Spacer()

            if let footprint = item.memoryFootprint {
                Text(Format.memory(footprint))
                    .font(.caption.monospacedDigit())
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
            }
        }
    }
}

// MARK: - App type badge

/// Neutral type badge: the glyph carries the Status Bar / Dock distinction
/// and the color budget stays reserved for actions (blue = open, red = quit,
/// orange = force quit). Replaces the old purple/green per-type tinting.
struct AppTypeBadge: View {
    let type: MenuBarMonitor.AppType
    let l10n: L10nTable

    var body: some View {
        Label(
            type == .statusbarOnly ? l10n.statusBar : l10n.dock,
            systemImage: type == .statusbarOnly ? "menubar.rectangle" : "dock.rectangle"
        )
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Formatting

enum Format {
    /// Human-readable memory footprint, Lemon-style: "3.25 GB", "257 MB",
    /// "48.2 MB". GB keeps two decimals; MB keeps one below 100 for the
    /// small-app tail, none above.
    static func memory(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 100 { return String(format: "%.0f MB", mb) }
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Stat chip

/// Compact read-only summary chip for the overview state. Uses a macOS-native
/// rectangular card instead of an iOS-style capsule. Filtering is owned by the
/// sidebar's segmented picker, so chips are deliberately not buttons.
struct StatChip: View {
    let systemImage: String
    let title: String
    let value: Int
    var tintColor: Color = .secondary

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(tintColor)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(value)")
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .frame(minWidth: 84)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(isHovered ? Color.primary.opacity(0.18) : Color.primary.opacity(0.06), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Cursor & Interactive Modifiers

struct PointingHandModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if hovering != isHovering {
                    isHovering = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .onDisappear {
                if isHovering {
                    isHovering = false
                    NSCursor.pop()
                }
            }
    }
}

extension View {
    func pointingHandCursor() -> some View {
        modifier(PointingHandModifier())
    }
}

// MARK: - Button Styles

/// Dedicated micro action button style for row actions (Open, Quit) in lists.
struct MicroActionButtonStyle: ButtonStyle {
    enum Variant {
        case standard
        case accent
        case warning
    }

    var variant: Variant = .standard

    func makeBody(configuration: Configuration) -> some View {
        MicroActionButtonBody(configuration: configuration, variant: variant)
    }

    private struct MicroActionButtonBody: View {
        let configuration: Configuration
        let variant: Variant
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 0.8)
                )
                .scaleEffect(configuration.isPressed ? 0.94 : (isHovered ? 1.02 : 1.0))
                .animation(.easeInOut(duration: 0.12), value: isHovered)
                .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
                .onHover { isHovered = $0 }
                .pointingHandCursor()
        }

        private var foregroundColor: Color {
            switch variant {
            case .standard:
                return isHovered ? .primary : .secondary
            case .accent:
                return isHovered ? Color.accentColor : Color.accentColor.opacity(0.9)
            case .warning:
                return isHovered ? Theme.Color.warning : Theme.Color.warning.opacity(0.9)
            }
        }

        private var backgroundColor: Color {
            switch variant {
            case .standard:
                return isHovered ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06)
            case .accent:
                return isHovered ? Color.accentColor.opacity(0.22) : Color.accentColor.opacity(0.12)
            case .warning:
                return isHovered ? Theme.Color.warning.opacity(0.22) : Theme.Color.warning.opacity(0.12)
            }
        }

        private var borderColor: Color {
            switch variant {
            case .standard:
                return isHovered ? Color.primary.opacity(0.18) : Color.primary.opacity(0.08)
            case .accent:
                return isHovered ? Color.accentColor.opacity(0.35) : Color.accentColor.opacity(0.2)
            case .warning:
                return isHovered ? Theme.Color.warning.opacity(0.35) : Theme.Color.warning.opacity(0.2)
            }
        }
    }
}

/// Circular or rounded icon button style with soft translucent hover background.
struct HoverIconButtonStyle: ButtonStyle {
    var size: CGFloat = 26
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        HoverIconButtonBody(configuration: configuration, size: size, isDestructive: isDestructive)
    }

    private struct HoverIconButtonBody: View {
        let configuration: Configuration
        let size: CGFloat
        let isDestructive: Bool
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(foregroundColor)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(backgroundColor)
                )
                .scaleEffect(configuration.isPressed ? 0.9 : (isHovered ? 1.06 : 1.0))
                .animation(.easeInOut(duration: 0.12), value: isHovered)
                .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
                .onHover { isHovered = $0 }
                .pointingHandCursor()
        }

        private var foregroundColor: Color {
            if isDestructive {
                return isHovered ? Theme.Color.warning : Theme.Color.warning.opacity(0.8)
            }
            return isHovered ? .primary : .secondary
        }

        private var backgroundColor: Color {
            if isDestructive {
                return isHovered ? Theme.Color.warning.opacity(0.16) : Color.clear
            }
            return isHovered ? Color.primary.opacity(0.08) : Color.clear
        }
    }
}

/// Prominent primary action button with smooth hover illumination and drop shadow.
struct ModernProminentButtonStyle: ButtonStyle {
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        ModernProminentButtonBody(configuration: configuration, fullWidth: fullWidth)
    }

    private struct ModernProminentButtonBody: View {
        let configuration: Configuration
        let fullWidth: Bool
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .padding(.horizontal, fullWidth ? 16 : 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .fill(Color.accentColor.opacity(isHovered ? 0.92 : 1.0))
                        .shadow(color: Color.accentColor.opacity(isHovered ? 0.35 : 0.15), radius: isHovered ? 4 : 2, x: 0, y: 1.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                )
                .scaleEffect(configuration.isPressed ? 0.97 : (isHovered ? 1.01 : 1.0))
                .animation(.easeInOut(duration: 0.12), value: isHovered)
                .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
                .onHover { isHovered = $0 }
                .pointingHandCursor()
        }
    }
}

/// Bordered secondary button with hover highlight and active bounce.
struct ModernSecondaryButtonStyle: ButtonStyle {
    var isHighlighted: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        ModernSecondaryButtonBody(configuration: configuration, isHighlighted: isHighlighted)
    }

    private struct ModernSecondaryButtonBody: View {
        let configuration: Configuration
        let isHighlighted: Bool
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isHighlighted ? Theme.Color.warning : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 0.8)
                )
                .scaleEffect(configuration.isPressed ? 0.97 : (isHovered ? 1.01 : 1.0))
                .animation(.easeInOut(duration: 0.12), value: isHovered)
                .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
                .onHover { isHovered = $0 }
                .pointingHandCursor()
        }

        private var backgroundColor: Color {
            if isHighlighted {
                return isHovered ? Theme.Color.warning.opacity(0.16) : Theme.Color.warning.opacity(0.08)
            }
            return isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04)
        }

        private var borderColor: Color {
            if isHighlighted {
                return isHovered ? Theme.Color.warning.opacity(0.35) : Theme.Color.warning.opacity(0.2)
            }
            return isHovered ? Color.primary.opacity(0.18) : Color.primary.opacity(0.1)
        }
    }
}

/// Bordered destructive button with warning styling.
struct ModernWarningButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ModernWarningButtonBody(configuration: configuration)
    }

    private struct ModernWarningButtonBody: View {
        let configuration: Configuration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.Color.warning)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .fill(isHovered ? Theme.Color.warning.opacity(0.16) : Theme.Color.warning.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(isHovered ? Theme.Color.warning.opacity(0.35) : Theme.Color.warning.opacity(0.2), lineWidth: 0.8)
                )
                .scaleEffect(configuration.isPressed ? 0.97 : (isHovered ? 1.01 : 1.0))
                .animation(.easeInOut(duration: 0.12), value: isHovered)
                .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
                .onHover { isHovered = $0 }
                .pointingHandCursor()
        }
    }
}

/// Subtle secondary action button with hover pill background (for footer settings).
struct SubtleSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SubtleSecondaryButtonBody(configuration: configuration)
    }

    private struct SubtleSecondaryButtonBody: View {
        let configuration: Configuration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(isHovered ? Color.primary : Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                )
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: isHovered)
                .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
                .onHover { isHovered = $0 }
                .pointingHandCursor()
        }
    }
}

/// Subtle destructive action button with warning hover pill (for footer quit).
struct SubtleDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SubtleDestructiveButtonBody(configuration: configuration)
    }

    private struct SubtleDestructiveButtonBody: View {
        let configuration: Configuration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.callout.weight(.medium))
                .foregroundStyle(Theme.Color.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovered ? Theme.Color.warning.opacity(0.12) : Color.clear)
                )
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: isHovered)
                .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
                .onHover { isHovered = $0 }
                .pointingHandCursor()
        }
    }
}

// MARK: - Search Box

/// Unified macOS-style search box with reactive focus and clear button.
struct SearchBoxView: View {
    @Binding var text: String
    let placeholder: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isFocused ? Color.accentColor : Color.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(HoverIconButtonStyle(size: 18))
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(isFocused ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
    }
}
