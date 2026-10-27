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

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                iconView
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.accentColor, lineWidth: 2)
                        }
                    }

                Text(title)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var iconView: some View {
        switch iconType {
        case .dots:
            HStack(spacing: 4) {
                Circle().fill(Color.primary).frame(width: 6, height: 6)
                Circle().fill(Color.primary).frame(width: 6, height: 6)
                Circle().fill(Color.primary).frame(width: 6, height: 6)
            }
        case .grid:
            Image(systemName: "square.grid.2x2")
                .font(.title2)
        case .chevron:
            Image(systemName: "chevron.down")
                .font(.title2)
        case .square:
            Image(systemName: "square.fill")
                .font(.title2)
        case .circle:
            Image(systemName: "circle.fill")
                .font(.title2)
        case .transparent:
            Image(systemName: "circle.dotted")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}
