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
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
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

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(value)")
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .frame(minWidth: 80)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.Radius.control))
    }
}
