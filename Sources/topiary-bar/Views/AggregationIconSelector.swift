import SwiftUI

/// Icon-style picker for the menu bar aggregation icon. Intentionally exposes
/// only the grid of option buttons — the section title and description caption
/// are owned by SettingsView's Section header so they render exactly once.
struct AggregationIconSelector: View {
    @Binding var selectedIcon: SettingsStore.AggregationIconType
    let l10n: L10nTable

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 100), spacing: 10)],
            spacing: 10
        ) {
            ForEach(SettingsStore.AggregationIconType.allCases) { iconType in
                IconOptionButton(
                    iconType: iconType,
                    title: title(for: iconType),
                    isSelected: selectedIcon == iconType,
                    action: { selectedIcon = iconType }
                )
            }
        }
    }

    private func title(for iconType: SettingsStore.AggregationIconType) -> String {
        switch iconType {
        case .dots: return l10n.iconTypeDots
        case .grid: return l10n.iconTypeGrid
        case .chevron: return l10n.iconTypeChevron
        case .square: return l10n.iconTypeSquare
        case .circle: return l10n.iconTypeCircle
        case .transparent: return l10n.iconTypeTransparent
        }
    }
}

private struct IconOptionButton: View {
    let iconType: SettingsStore.AggregationIconType
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                iconView
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04)))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.18) : Color.primary.opacity(0.08)), lineWidth: isSelected ? 2 : 1)
                    }
                    .shadow(color: isSelected ? Color.accentColor.opacity(0.2) : .clear, radius: 4, x: 0, y: 2)

                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : (isHovered ? .primary : .secondary))
            }
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var iconView: some View {
        switch iconType {
        case .dots:
            HStack(spacing: 4) {
                Circle().fill(isSelected ? Color.accentColor : Color.primary).frame(width: 6, height: 6)
                Circle().fill(isSelected ? Color.accentColor : Color.primary).frame(width: 6, height: 6)
                Circle().fill(isSelected ? Color.accentColor : Color.primary).frame(width: 6, height: 6)
            }
        case .grid:
            Image(systemName: "square.grid.2x2")
                .font(.title2)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
        case .chevron:
            Image(systemName: "chevron.down")
                .font(.title2)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
        case .square:
            Image(systemName: "square.fill")
                .font(.title2)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
        case .circle:
            Image(systemName: "circle.fill")
                .font(.title2)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
        case .transparent:
            Image(systemName: "circle.dotted")
                .font(.title2)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
    }
}
