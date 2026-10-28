import SwiftUI

struct ContentView: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor
    @Environment(SettingsStore.self) private var settings
    @Environment(VisibilityMonitor.self) private var visibilityMonitor

    @State private var selectedFilter: AppFilter = .all
    @State private var searchText = ""
    @State private var selectedItemID: String?
    @State private var windowTab: WindowTab = .apps

    enum WindowTab: Hashable {
        case apps, settings
    }

    enum AppFilter: String, CaseIterable {
        case all, statusbar, dock
    }

    private var l10n: L10nTable { settings.l10n }

    /// Type filter first, then the shared search over name and bundle ID
    /// (same matcher as the popover, so both surfaces find the same apps).
    private var filteredItems: [MenuBarMonitor.MenuBarItem] {
        let scoped: [MenuBarMonitor.MenuBarItem]
        switch selectedFilter {
        case .all:
            scoped = menuBarMonitor.menuBarItems
        case .statusbar:
            scoped = menuBarMonitor.menuBarItems.statusbarOnly
        case .dock:
            scoped = menuBarMonitor.menuBarItems.dockOnly
        }

        return MenuBarMonitor.matching(scoped, query: searchText)
    }

    /// Status Bar apps lead: they are the reason this app exists.
    private var statusbarItems: [MenuBarMonitor.MenuBarItem] {
        filteredItems.statusbarOnly
    }

    private var dockItems: [MenuBarMonitor.MenuBarItem] {
        filteredItems.dockOnly
    }

    /// Resolved from the full item list, so a selection survives filtering:
    /// clearing a search never blanks the detail pane.
    private var selectedItem: MenuBarMonitor.MenuBarItem? {
        guard let selectedItemID else { return nil }
        return menuBarMonitor.menuBarItems.first { $0.id == selectedItemID }
    }

    var body: some View {
        Group {
            switch windowTab {
            case .apps:
                appsView
            case .settings:
                SettingsView()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // The window title already carries the brand name on the left;
                // the toolbar only adds the icon and the tab switcher.
                HStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 17, height: 17)
                    Picker("", selection: $windowTab) {
                        Text(l10n.windowTabApps).tag(WindowTab.apps)
                        Text(l10n.windowTabSettings).tag(WindowTab.settings)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 200)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectSettingsTab)) { _ in
            windowTab = .settings
        }
        .onAppear {
            // The Dock icon reappears with the main window.
            NotificationCenter.default.post(name: .mainWindowVisibilityChanged, object: nil)
        }
    }

    private var appsView: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)

            detailView
                .frame(minWidth: 400, idealWidth: 500)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider()
            sidebarList
        }
    }

    private var sidebarHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
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
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: Theme.Radius.control))

            Picker(l10n.all, selection: $selectedFilter) {
                Text(l10n.all).tag(AppFilter.all)
                Text(l10n.statusBar).tag(AppFilter.statusbar)
                Text(l10n.dock).tag(AppFilter.dock)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Section headers carry the per-type counts; only a live search
            // needs the extra "N apps" result line.
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(String(format: l10n.appsCount, filteredItems.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var sidebarList: some View {
        List(selection: $selectedItemID) {
            if filteredItems.isEmpty {
                ContentUnavailableView(
                    l10n.noApps,
                    systemImage: "app.badge",
                    description: Text(searchText.isEmpty ? (selectedFilter == .all ? l10n.noAppsFound : l10n.noAppsInCategory) : l10n.noAppsFound)
                )
            } else {
                if !statusbarItems.isEmpty {
                    Section {
                        ForEach(statusbarItems) { row(item: $0) }
                    } header: {
                        sectionHeader(l10n.statusBar, systemImage: "menubar.rectangle", count: statusbarItems.count)
                    }
                }

                if !dockItems.isEmpty {
                    Section {
                        ForEach(dockItems) { row(item: $0) }
                    } header: {
                        sectionHeader(l10n.dock, systemImage: "dock.rectangle", count: dockItems.count)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func row(item: MenuBarMonitor.MenuBarItem) -> some View {
        SidebarRow(item: item, onSelect: { selectedItemID = item.id })
            .tag(item.id)
    }

    private func sectionHeader(_ title: String, systemImage: String, count: Int) -> some View {
        Label("\(title) · \(count)", systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        if let selectedItem {
            AppDetailView(item: selectedItem, l10n: l10n)
        } else {
            // One traversal feeds both type counts (was three `.filter` passes).
            let counts = menuBarMonitor.menuBarItems.countsByType
            OverviewView(
                l10n: l10n,
                total: menuBarMonitor.menuBarItems.count,
                statusbarCount: counts.statusbarOnly,
                dockCount: counts.dockOnly
            )
        }
    }
}

// MARK: - Sidebar row

private struct SidebarRow: View {
    @Environment(SettingsStore.self) private var settings

    let item: MenuBarMonitor.MenuBarItem
    let onSelect: () -> Void

    var body: some View {
        // Shared data-only row (icon + name + memory) wrapped in the
        // sidebar's selection behavior; the pin badge rides in as a name
        // accessory so the popover row and this one stay visually identical.
        AppRowContent(item: item, iconSize: 28) {
            // Pinned apps carry their own resident status item in the menu
            // bar — mark it right in the list.
            if settings.isPinned(item.id) {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.Color.warning)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}

// MARK: - Overview (no selection)

/// Landing state shown while no app is selected: brand, a one-glance summary
/// and direct controls for the resident (pinned) apps — their own menu bar
/// icons may be occluded, so quitting them must not depend on those icons.
private struct OverviewView: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor
    @Environment(SettingsStore.self) private var settings
    let l10n: L10nTable
    let total: Int
    let statusbarCount: Int
    let dockCount: Int

    @Environment(VisibilityMonitor.self) private var visibilityMonitor

    /// Pinned apps in pin order, resolved against the live app list.
    private var pinnedItems: [MenuBarMonitor.MenuBarItem] {
        // `uniquingKeysWith` mirrors ResidentBarManager: the inventory should
        // hold one item per bundle ID, but a crash must not depend on that
        // invariant holding.
        let byID = Dictionary(
            menuBarMonitor.menuBarItems.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return settings.pinnedAppIDs.compactMap { byID[$0] }
    }

    /// Main icon occluded and pinned icons occluded read differently; the
    /// pinned variant carries the count.
    private var occlusionBody: String {
        if visibilityMonitor.isMainItemHidden {
            return l10n.notchWarningMainBody
        }
        return String(format: l10n.notchWarningPinnedBody, visibilityMonitor.hiddenPinnedIDs.count)
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Small brand mark anchors the top of the overview without
            // consuming too much space. The detail pane is the protagonist.
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Brand.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(l10n.menuBarManager)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // macOS-native stat cards: vertical stack of label + number,
            // rectangular background instead of iOS-style capsule. The
            // selection prompt rides below as their subtitle, anchored to
            // the stat block instead of floating under the resident list.
            VStack(spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.md) {
                    StatChip(systemImage: "list.bullet", title: l10n.total, value: total)
                    StatChip(systemImage: "menubar.rectangle", title: l10n.statusBar, value: statusbarCount)
                    StatChip(systemImage: "dock.rectangle", title: l10n.dock, value: dockCount)
                }

                Text(l10n.selectAppPrompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if visibilityMonitor.hasOcclusion {
                VStack(alignment: .leading, spacing: 6) {
                    Label(l10n.notchWarningTitle, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Color.warning)
                    Text(occlusionBody)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(Theme.Spacing.md)
                .frame(maxWidth: 420, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(Theme.Color.warning.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .stroke(Theme.Color.warning.opacity(0.35), lineWidth: 1)
                        )
                )
            }

            if !pinnedItems.isEmpty {
                residentSection
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xl)
    }

    // Quit confirmation state for resident-section rows (keyed by bundle ID).
    @State private var residentQuitTarget: MenuBarMonitor.MenuBarItem? = nil

    /// Direct controls for resident apps: their own menu bar icons may be
    /// occluded (notch, crowding, a hider utility), so the main panel must be
    /// able to quit or unpin them without depending on those icons.
    private var residentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l10n.residentAppsTitle)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xs)

            ForEach(pinnedItems) { item in
                HStack(spacing: 8) {
                    AppIconView(icon: item.icon, size: 20)

                    Text(item.processName)
                        .font(.callout)
                        .lineLimit(1)

                    Spacer()

#if !MAC_APP_STORE
                    if menuBarMonitor.canQuit(item) {
                        Button(l10n.quit) {
                            residentQuitTarget = item
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .foregroundStyle(Theme.Color.warning)
                        .confirmationDialog(
                            String(format: l10n.quitConfirmTitle, item.processName),
                            isPresented: Binding(
                                get: { residentQuitTarget?.id == item.id },
                                set: { if !$0 { residentQuitTarget = nil } }
                            ),
                            titleVisibility: .visible
                        ) {
                            Button(l10n.quit, role: .destructive) {
                                menuBarMonitor.quitApp(item)
                                residentQuitTarget = nil
                            }
                            Button(l10n.cancel, role: .cancel) { residentQuitTarget = nil }
                        } message: {
                            Text(l10n.quitConfirmMessage)
                        }
                    }
#endif

                    Button {
                        settings.togglePin(item.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(l10n.removeFromPanel)
                    .accessibilityLabel(l10n.removeFromPanel)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)

                if item.id != pinnedItems.last?.id {
                    Divider()
                }
            }
        }
        .frame(maxWidth: 360)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: Theme.Radius.control))
    }
}

// MARK: - App detail (selection)

/// Left-aligned definition-list layout — identity header, an info card
/// (type / memory / PID), then actions — instead of everything floating
/// centered with no hierarchy.
private struct AppDetailView: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor
    @Environment(SettingsStore.self) private var settings

    let item: MenuBarMonitor.MenuBarItem
    let l10n: L10nTable

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    AppIconView(icon: item.icon, size: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.processName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text(item.bundleIdentifier)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 0) {
                    infoRow(l10n.infoType) {
                        AppTypeBadge(type: item.appType, l10n: l10n)
                    }
                    Divider()
                    infoRow(l10n.memoryUsage) {
                        Text(item.memoryFootprint.map { Format.memory($0) } ?? "—")
                            .font(.callout.monospacedDigit())
                    }
                    Divider()
                    infoRow(l10n.infoPID) {
                        Text("\(item.pid)")
                            .font(.callout.monospacedDigit())
                    }
                }
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: Theme.Radius.control))

                actions

                if item.appType == .statusbarOnly {
                    Text(l10n.statusbarActivateHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: 400)
            .padding(24)
        }
    }

    private func infoRow<Content: View>(_ label: String, @ViewBuilder value: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            value()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    @State private var showQuitConfirm = false

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 10) {
            if menuBarMonitor.canOpen(item) {
                Button {
                    menuBarMonitor.activateApp(item)
                } label: {
                    Label(l10n.open, systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.borderedProminent)
            }

            // Residency only makes sense for menu-bar (accessory) apps: Dock
            // apps are already permanently visible in the Dock.
            if item.appType == .statusbarOnly {
                Button {
                    settings.togglePin(item.id)
                } label: {
                    Label(
                        settings.isPinned(item.id) ? l10n.unpinFromMenuBar : l10n.pinToMenuBar,
                        systemImage: settings.isPinned(item.id) ? "pin.slash.fill" : "pin.fill"
                    )
                }
                .buttonStyle(.bordered)
            }

#if !MAC_APP_STORE
            if menuBarMonitor.canQuit(item) {
                Button {
                    showQuitConfirm = true
                } label: {
                    Label(l10n.quit, systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
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
        .padding(.top, Theme.Spacing.xs)
    }
}
