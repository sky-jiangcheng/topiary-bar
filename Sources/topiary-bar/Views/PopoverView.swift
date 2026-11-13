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
    /// The row whose "quit" is waiting for confirmation. One target shared by
    /// the whole list, so at most one row dialog can be up at a time.
    @State private var pendingQuitTarget: MenuBarMonitor.MenuBarItem?

    let onDismiss: () -> Void

    private var l10n: L10nTable { settings.l10n }

    /// Reads the pending target rather than a per-row flag, so the dialog is
    /// not tied to the lifetime of the row that opened it.
    private var quitConfirmPresented: Binding<Bool> {
        Binding(
            get: { pendingQuitTarget != nil },
            set: { if !$0 { pendingQuitTarget = nil } }
        )
    }

    private var quitConfirmTitle: String {
        String(format: l10n.quitConfirmTitle, pendingQuitTarget?.processName ?? "")
    }

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
        // INVARIANT: a presentation modifier must live on a view that is never
        // removed from the hierarchy. This dialog used to ride on the row's
        // hover-gated Quit button, so moving the pointer toward it cleared
        // `isHovered`, dropped that subtree and SwiftUI cancelled the dialog
        // mid-flight (writing isPresented back to false) — the confirmation was
        // literally impossible to click. Keep it attached to the popover root.
        //
        // Gated with its only trigger (the row's Quit button) and with
        // MenuBarMonitor.quitApp, all of which disappear from the MAS channel.
#if !MAC_APP_STORE
        .confirmationDialog(
            quitConfirmTitle,
            isPresented: quitConfirmPresented,
            titleVisibility: .visible
        ) {
            Button(l10n.quit, role: .destructive) {
                if let item = pendingQuitTarget {
                    menuBarMonitor.quitApp(item)
                }
                pendingQuitTarget = nil
            }
            Button(l10n.cancel, role: .cancel) { pendingQuitTarget = nil }
        } message: {
            Text(l10n.quitConfirmMessage)
        }
#endif
    }

    private var headerSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.12), radius: 1.5, x: 0, y: 0.5)

                VStack(alignment: .leading, spacing: 1) {
                    Text(Brand.name)
                        .font(.headline)
                    Text(String(format: l10n.appsCount, menuBarMonitor.menuBarItems.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Explicit close affordance — circular hover button
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(HoverIconButtonStyle(size: 24))
            .help(l10n.popoverClose)
            .accessibilityLabel(l10n.popoverClose)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.xs)
    }

    /// Compact Lemon-style overview: one label/value line over a slightly
    /// thicker bar for better readability at a glance.
    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
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
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 5)
                    Capsule()
                        .fill(systemMemory.usedFraction > 0.85
                              ? Theme.Color.warning : Theme.Color.brand)
                        .frame(width: max(5, geo.size.width * CGFloat(systemMemory.usedFraction)), height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var percentText: String {
        "\(Int((systemMemory.usedFraction * 100).rounded()))%"
    }

    private var searchSection: some View {
        SearchBoxView(text: $searchText, placeholder: l10n.searchPlaceholder)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.xs)
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
                    LazyVStack(spacing: 2, pinnedViews: [.sectionHeaders]) {
                        if !statusbarItems.isEmpty {
                            Section {
                                ForEach(statusbarItems) { IconRow(item: $0, l10n: l10n, onQuit: { pendingQuitTarget = $0 }) }
                            } header: {
                                sectionHeader(l10n.statusBar, systemImage: "menubar.rectangle", count: statusbarItems.count)
                            }
                        }

                        if !dockItems.isEmpty {
                            Section {
                                ForEach(dockItems) { IconRow(item: $0, l10n: l10n, onQuit: { pendingQuitTarget = $0 }) }
                            } header: {
                                sectionHeader(l10n.dock, systemImage: "dock.rectangle", count: dockItems.count)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, systemImage: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.caption2.monospacedDigit())
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                )
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
    }

    /// Redesigned footer: primary action ("Open Main Window") stands alone on
    /// its row; secondary actions (Settings gear, Quit) are smaller and grouped
    /// below it so the visual hierarchy matches the action priority.
    private var footerSection: some View {
        VStack(spacing: 8) {
            // Primary action row — full-width prominent feel
            Button {
                openWindow(id: "main")
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 13, weight: .semibold))
                    Text(l10n.openMainWindow)
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(ModernProminentButtonStyle(fullWidth: true))
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)

            // Secondary action row — gear left, quit right
            HStack {
                Button {
                    NotificationCenter.default.post(name: .openSettingsTab, object: nil)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13))
                        Text(l10n.windowTabSettings)
                            .font(.callout)
                    }
                }
                .buttonStyle(SubtleSecondaryButtonStyle())
                .help(l10n.settingsDots)
                .accessibilityLabel(l10n.settingsDots)

                Spacer()

                Button {
                    showQuitTopiaryConfirm = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "power")
                            .font(.system(size: 11, weight: .semibold))
                        Text(l10n.quit)
                    }
                }
                .buttonStyle(SubtleDestructiveButtonStyle())
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
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(Theme.Color.warning)
            Text(occlusionBody)
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.85))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 4)
            Button {
                occlusionDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(HoverIconButtonStyle(size: 20, isDestructive: true))
            .help(l10n.popoverClose)
            .accessibilityLabel(l10n.popoverClose)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Theme.Color.warning.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(Theme.Color.warning.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.xs)
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
    /// Reports the row the user wants to quit. The confirmation itself belongs
    /// to `PopoverView` — see the INVARIANT note there: a dialog hosted inside
    /// this `if isHovered` branch disappears the moment the pointer leaves the
    /// row, which is exactly on the way to the dialog.
    let onQuit: (MenuBarMonitor.MenuBarItem) -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Shared data-only row; hover-gated actions ride behind it so
            // the sidebar and the popover render identical row anatomy.
            AppRowContent(item: item, iconSize: 26, nameFont: .system(.body, weight: .medium))

            // Action buttons appear only on hover to keep the list uncluttered.
            // Quit still asks first (the dialog lives on the popover root) so a
            // mis-hover tap never terminates an app silently.
            if isHovered {
                HStack(spacing: 6) {
                    if menuBarMonitor.canOpen(item) {
                        Button {
                            menuBarMonitor.activateApp(item)
                        } label: {
                            Label(l10n.open, systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(MicroActionButtonStyle(variant: .accent))
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }

#if !MAC_APP_STORE
                    if menuBarMonitor.canQuit(item) {
                        Button {
                            onQuit(item)
                        } label: {
                            Label(l10n.quit, systemImage: "xmark")
                        }
                        .buttonStyle(MicroActionButtonStyle(variant: .warning))
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
#endif
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .padding(.horizontal, Theme.Spacing.md)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
