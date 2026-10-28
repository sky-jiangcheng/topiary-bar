import AppKit
import SwiftUI

struct PopoverView: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor
    @Environment(SettingsStore.self) private var settings
    @Environment(\.openWindow) private var openWindow
    @Environment(VisibilityMonitor.self) private var visibilityMonitor
    @Environment(SystemMemoryMonitor.self) private var systemMemory

    @State private var searchText = ""
    @State private var occlusionDismissed = false
    @State private var showQuitTopiaryConfirm = false

    let onDismiss: () -> Void

    private var l10n: L10nTable { settings.l10n }

    private var filteredItems: [MenuBarMonitor.MenuBarItem] {
        MenuBarMonitor.matching(menuBarMonitor.menuBarItems, query: searchText)
    }

    /// Status Bar apps lead; within each section the heaviest memory users
    /// surface first, so the hog is always the top row.
    private var statusbarItems: [MenuBarMonitor.MenuBarItem] {
        filteredItems.statusbarOnly.sortedByMemoryDesc
    }

    private var dockItems: [MenuBarMonitor.MenuBarItem] {
        filteredItems.dockOnly.sortedByMemoryDesc
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            memorySection

            if visibilityMonitor.hasOcclusion && !occlusionDismissed {
                occlusionBanner
                Divider()
            } else {
                Divider()
            }

            searchSection

            Divider()

            iconListSection

            Divider()

            footerSection
        }
        .frame(minWidth: 360, idealWidth: 360, minHeight: 420, idealHeight: 520)
        .onChange(of: visibilityMonitor.hasOcclusion) { _, stillOccluded in
            // Re-arm the manual dismissal once the occlusion clears, so a new
            // occurrence warns again instead of staying silenced forever.
            if !stillOccluded { occlusionDismissed = false }
        }
    }

    private var headerSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    Text(Brand.name)
                        .font(.headline)
                }
                Text(String(format: l10n.appsCount, menuBarMonitor.menuBarItems.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Explicit close affordance — outside clicks already dismiss the
            // transient popover, but a visible × makes the way out obvious.
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(l10n.popoverClose)
            .accessibilityLabel(l10n.popoverClose)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }

    /// Compact Lemon-style overview: one label/value line over a slightly
    /// thicker bar for better readability at a glance.
    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(l10n.memoryUsage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Format.memory(systemMemory.usedBytes)) / \(Format.memory(systemMemory.totalBytes))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(percentText)
                    .font(.callout.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(systemMemory.usedFraction > 0.85 ? Theme.Color.warning : Color.primary)
            }
            // Slightly taller bar (4 pt) for better visual weight.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.quaternary)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(systemMemory.usedFraction > 0.85
                              ? Theme.Color.warning : Theme.Color.brand)
                        .frame(width: geo.size.width * systemMemory.usedFraction, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: Theme.Radius.control))
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var percentText: String {
        "\(Int((systemMemory.usedFraction * 100).rounded()))%"
    }

    private var searchSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(l10n.searchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: Theme.Radius.control))
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var iconListSection: some View {
        VStack(spacing: 0) {
            if filteredItems.isEmpty {
                ContentUnavailableView(
                    l10n.noApps,
                    systemImage: "app.badge",
                    description: Text(l10n.noAppsFound)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        if !statusbarItems.isEmpty {
                            Section {
                                ForEach(statusbarItems) { IconRow(item: $0, l10n: l10n) }
                            } header: {
                                sectionHeader(l10n.statusBar, count: statusbarItems.count)
                            }
                        }

                        if !dockItems.isEmpty {
                            Section {
                                ForEach(dockItems) { IconRow(item: $0, l10n: l10n) }
                            } header: {
                                sectionHeader(l10n.dock, count: dockItems.count)
                            }
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        Text("\(title) · \(count)")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, 5)
            .background(.quaternary.opacity(0.25))
    }

    /// Redesigned footer: primary action ("Open Main Window") stands alone on
    /// its row; secondary actions (Settings gear, Quit) are smaller and grouped
    /// below it so the visual hierarchy matches the action priority.
    private var footerSection: some View {
        VStack(spacing: 0) {
            // Primary action row — centered, full-width feel
            Button {
                openWindow(id: "main")
            } label: {
                Label(l10n.openMainWindow, systemImage: "macwindow")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xs)

            // Secondary action row — gear left, quit right
            HStack {
                Button {
                    NotificationCenter.default.post(name: .openSettingsTab, object: nil)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(l10n.settingsDots)
                .accessibilityLabel(l10n.settingsDots)

                Spacer()

                Button {
                    showQuitTopiaryConfirm = true
                } label: {
                    // Danger-tinted so the destructive action never reads as
                    // a neutral footer link.
                    Text(l10n.quit)
                        .font(.callout)
                        .foregroundStyle(Theme.Color.warning)
                }
                .buttonStyle(.plain)
                .help(l10n.quitAppTitle)
                .confirmationDialog(
                    l10n.quitTopiaryConfirmTitle,
                    isPresented: $showQuitTopiaryConfirm,
                    titleVisibility: .visible
                ) {
                    Button(l10n.quit, role: .destructive) {
                        NSApp.terminate(nil)
                    }
                    Button(l10n.cancel, role: .cancel) {}
                } message: {
                    Text(l10n.quitTopiaryConfirmMessage)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.sm)
        }
    }

    private var occlusionBanner: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(Theme.Color.warning)
            Text(occlusionBody)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Button {
                occlusionDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(Theme.Spacing.xs)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(l10n.popoverClose)
            .accessibilityLabel(l10n.popoverClose)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        // Stronger contrast: 0.15 opacity + 1 pt stroke for visible warning
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Theme.Color.warning.opacity(0.15))
                .overlay(
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Theme.Color.warning.opacity(0.4))
                            .frame(height: 1)
                    }
                )
        )
    }

    private var occlusionBody: String {
        if visibilityMonitor.isMainItemHidden {
            return l10n.notchWarningMainBody
        }
        return String(format: l10n.notchWarningPinnedBody, visibilityMonitor.hiddenPinnedIDs.count)
    }
}

private struct IconRow: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor

    let item: MenuBarMonitor.MenuBarItem
    let l10n: L10nTable

    /// Hover state gates the action buttons: at rest only name + memory are
    /// shown, keeping the row clean and reducing accidental Quit taps.
    @State private var isHovered = false
    /// Pending quit confirmation (popover style).
    @State private var showQuitConfirm = false

    var body: some View {
        HStack(spacing: 10) {
            // Shared data-only row; hover-gated actions ride behind it so
            // the sidebar and the popover render identical row anatomy.
            AppRowContent(item: item, iconSize: 26, nameFont: .system(.body, weight: .medium))

            // Action buttons appear only on hover to keep the list uncluttered.
            // The Quit button is guarded by a confirmationDialog so a mis-hover
            // tap never terminates an app silently.
            if isHovered {
                if menuBarMonitor.canOpen(item) {
                    Button(l10n.open) {
                        menuBarMonitor.activateApp(item)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

#if !MAC_APP_STORE
                if menuBarMonitor.canQuit(item) {
                    Button(l10n.quit) {
                        showQuitConfirm = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .foregroundStyle(Theme.Color.warning)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .confirmationDialog(
                        String(format: l10n.quitConfirmTitle, item.processName),
                        isPresented: $showQuitConfirm,
                        titleVisibility: .visible
                    ) {
                        Button(l10n.quit, role: .destructive) {
                            menuBarMonitor.quitApp(item)
                        }
                        Button(l10n.cancel, role: .cancel) {}
                    } message: {
                        Text(l10n.quitConfirmMessage)
                    }
                }
#endif
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
