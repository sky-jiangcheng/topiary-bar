import AppKit
import Darwin
import Observation

@Observable
@MainActor
final class MenuBarMonitor {
    var menuBarItems: [MenuBarItem] = []
    var isMonitoring = false

    private var timer: Timer?
    private var refreshObserver: Any?
    private var terminateObserver: NSObjectProtocol?
    private var launchObserver: NSObjectProtocol?

    /// Bundle IDs we have asked to quit and not yet seen die. While a bundle
    /// is in this set the corresponding row is suppressed even if the OS
    /// still reports the process as running, and a second Quit click for the
    /// same app is coalesced into the in-flight terminate.
    private var quittingBundleIDs: Set<String> = []

    private let settingsStore: SettingsStore

    enum AppType: String {
        case statusbarOnly = "Status Bar"
        case dockOnly = "Dock"
    }

    struct MenuBarItem: Identifiable, Hashable {
        let id: String
        let bundleIdentifier: String
        let processName: String
        let icon: NSImage?
        let appType: AppType
        /// Process identifier, for memory-footprint lookups.
        var pid: pid_t = -1
        /// Physical memory footprint in bytes (Activity Monitor's "Memory"
        /// column); nil when unavailable, e.g. in the sandboxed MAS build.
        var memoryFootprint: UInt64? = nil

        // Identity deliberately excludes pid/memoryFootprint: live values
        // change every scan and must not re-identify items (SwiftUI list
        // diffs, pin state, detail-pane selection all key off identity).

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(processName)
            hasher.combine(appType)
        }

        static func == (lhs: MenuBarItem, rhs: MenuBarItem) -> Bool {
            lhs.id == rhs.id
                && lhs.bundleIdentifier == rhs.bundleIdentifier
                && lhs.processName == rhs.processName
                && lhs.appType == rhs.appType
                && lhs.icon === rhs.icon
        }

        /// Content equality: `==` is deliberately identity-only (it drives
        /// SwiftUI list diffs, pin state and detail-pane selection), so it
        /// ignores the live pid / memory footprint. Change detection needs the
        /// opposite: the UI *shows* both, so they must count as content.
        func hasSameContent(as other: MenuBarItem) -> Bool {
            self == other
                && pid == other.pid
                && memoryFootprint == other.memoryFootprint
        }
    }

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Initial inventory so the icon list is populated immediately.
        refreshMenuItems()
        startTimer()

        refreshObserver = NotificationCenter.default.addObserver(
            forName: .refreshIntervalChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.restartTimer()
            }
        }

        // Launch / terminate notifications are the exact signal: a quit
        // initiated from inside the app or another quit dialog refreshes the
        // list immediately instead of waiting up to `refreshInterval` seconds
        // for the next timer tick. The timer remains the fallback for
        // activation-policy changes (which don't post a notification).
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            // Extract the Sendable bundle ID here, before crossing into the
            // @MainActor-isolated body — `Notification` is not Sendable and
            // cannot be captured across the isolation boundary.
            let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
                .bundleIdentifier
            // `queue: .main` delivers on the main run loop, so it is safe to
            // bridge straight to the @MainActor-isolated self.
            MainActor.assumeIsolated {
                guard let self else { return }
                if let bundleID {
                    self.quittingBundleIDs.remove(bundleID)
                }
                self.refreshMenuItems()
            }
        }
        launchObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshMenuItems()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        if let observer = refreshObserver {
            NotificationCenter.default.removeObserver(observer)
            refreshObserver = nil
        }
        if let observer = terminateObserver {
            NotificationCenter.default.removeObserver(observer)
            terminateObserver = nil
        }
        if let observer = launchObserver {
            NotificationCenter.default.removeObserver(observer)
            launchObserver = nil
        }
        isMonitoring = false
    }

    private func startTimer() {
        timer?.invalidate()
        let interval = settingsStore.refreshInterval > 0 ? settingsStore.refreshInterval : 2.0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshMenuItems()
            }
        }
    }

    private func restartTimer() {
        guard isMonitoring else { return }
        startTimer()
    }

    /// Rebuilds the item list from the running apps. The aggregation panel is
    /// manual-only (summoned by the user), so a changed list only fans out a
    /// layout-changed notice so a visible panel can re-fit its frame.
    ///
    /// Both scans are sorted by process name, so element-wise `zip` comparison
    /// is aligned; any add/remove shifts the suffix and still reports a change.
    func refreshMenuItems() {
        // Apps we are in the middle of quitting are suppressed here so a
        // mid-flight timer tick cannot resurrect a row the user just dismissed.
        // They will return to the list naturally the next time the user starts
        // the app again.
        let newItems = Self.visibleItems(
            getMenuItemsFromRunningApps(),
            suppressing: quittingBundleIDs
        )
        // Content (memory / pid) is part of what the UI renders, so any content
        // change must be published — the identity-only `==` that drives SwiftUI
        // diffs deliberately ignores those live values.
        let contentChanged = newItems.count != menuBarItems.count
            || zip(newItems, menuBarItems).contains { !$0.hasSameContent(as: $1) }
        guard contentChanged else { return }
        // Only an add / remove / rename reshuffles the menu bar; a memory tick
        // must not wake the resident bar or the occlusion monitor.
        let identityChanged = newItems.count != menuBarItems.count
            || zip(newItems, menuBarItems).contains { $0 != $1 }
        menuBarItems = newItems
        if identityChanged {
            NotificationCenter.default.post(name: .menuBarItemsChanged, object: nil)
        }
    }

    /// Drops items whose bundle ID is in `quittingBundleIDs` — apps the user
    /// asked to quit but that haven't died yet — so the UI doesn't show rows
    /// for processes the user just dismissed. Pure for unit testing.
    static nonisolated func visibleItems(
        _ items: [MenuBarItem],
        suppressing quittingBundleIDs: Set<String>
    ) -> [MenuBarItem] {
        items.filter { !quittingBundleIDs.contains($0.bundleIdentifier) }
    }

    /// System agents that own menu bar / Dock real estate but are not
    /// user-facing apps. The app itself is excluded dynamically via
    /// Bundle.main (the bundle ID differs per distribution channel), so only
    /// system agents are listed here.
    private static let systemAgentBundleIDs: Set<String> = [
        "com.apple.Spotlight",
        "com.apple.WindowManager",
        "com.apple.notificationcenterui",
        "com.apple.controlcenter",
        "com.apple.controlcenter.helper",
        "com.apple.dock",
        "com.apple.dock.helper",
        "com.apple.dock.extra",
        "com.apple.Siri",
        "com.apple.loginwindow",
        "com.apple.CoreLocationAgent",
        "com.apple.coreservices.uiagent",
        "com.apple.backgroundtaskmanagement.agent",
        "com.apple.SoftwareUpdateNotificationManager",
        "com.apple.UserNotificationCenter",
        "com.apple.Security.keychain-circle-Notification",
        "com.apple.accessibility.universalaccessauthwarn",
        "com.apple.LocalAuthentication.UIAgent",
        "com.apple.talagent",
        "com.apple.storeuid",
        "com.apple.TextInputMenuAgent",
        "com.apple.TextInputSwitcher",
        "com.apple.wifi.WiFiAgent",
        "com.apple.AirPlayUIAgent",
        "com.apple.universalcontrol",
        "com.apple.AccessibilityUIServer",
        "com.apple.wallpaper.agent",
        "com.apple.PowerChime",
        "com.apple.WorkflowKit.ShortcutsViewService",
        "com.apple.systemuiserver",
    ]

    /// `NSRunningApplication.icon` hits the disk on every access, and the scan
    /// runs every 1-5 s for the lifetime of the app. Icons are therefore cached
    /// per bundle ID; the map is bounded by the installed app set.
    private var iconCache: [String: NSImage] = [:]

    private func cachedIcon(for app: NSRunningApplication, bundleID: String) -> NSImage? {
        if let cached = iconCache[bundleID] { return cached }
        let icon = app.icon
        iconCache[bundleID] = icon
        return icon
    }

    /// One running process that survived the suppression filters, awaiting the
    /// per-bundle-ID merge. Candidates carry no live data (icon, footprint) so
    /// `assembleItems` stays a pure, unit-testable function.
    struct ProcessCandidate {
        let bundleIdentifier: String
        let processName: String
        let pid: pid_t
        let isRegular: Bool
    }

    /// A process is not an app: several processes share one bundle ID (Docker
    /// Desktop runs com.docker.backend and com.docker.virtualization, both
    /// reporting bundle ID com.docker.docker and the name "Docker"). `id` is
    /// the bundle ID and is a SwiftUI identity key across every surface, so
    /// the inventory must hold at most one item per bundle ID — otherwise
    /// duplicate rows appear and `Dictionary(uniqueKeysWithValues:)` consumers
    /// crash. Where both policies run for one bundle ID, the regular process
    /// wins (the app is Dock-visible; its accessory processes are internal).
    static nonisolated func assembleItems(
        from candidates: [ProcessCandidate],
        icons: [String: NSImage]
    ) -> [MenuBarItem] {
        let regulars = candidates.filter { $0.isRegular }
        let regularBundleIDs = Set(regulars.map { $0.bundleIdentifier })

        var groups: [String: [ProcessCandidate]] = [:]
        for candidate in candidates {
            if !candidate.isRegular {
                // Same bundle ID as a running regular app: an internal
                // process of that app, folded into its single Dock item.
                if regularBundleIDs.contains(candidate.bundleIdentifier) { continue }

                // Heuristic: treat an accessory process as a helper of a
                // regular app when both share the same first two bundle-ID
                // segments (com.docker.* under com.docker). Segment-aligned
                // equality (not prefix matching) prevents false positives such
                // as com.docker absorbing com.dockerized.app.
                let ownBase = Self.baseBundleID(of: candidate.bundleIdentifier)
                let dominatedByParent = ownBase != nil && regulars.contains { regular in
                    Self.baseBundleID(of: regular.bundleIdentifier) == ownBase
                }
                if dominatedByParent { continue }
            }
            groups[candidate.bundleIdentifier, default: []].append(candidate)
        }

        var items: [MenuBarItem] = []
        for (bundleID, group) in groups {
            // Representative process: the first one launched. Memory sums the
            // whole group — the item stands for the app, not one process.
            guard let primary = group.min(by: { $0.pid < $1.pid }) else { continue }
            let footprints = group.compactMap { Self.physFootprint(pid: $0.pid) }
            items.append(MenuBarItem(
                id: bundleID,
                bundleIdentifier: bundleID,
                processName: primary.processName,
                icon: icons[bundleID],
                appType: primary.isRegular ? .dockOnly : .statusbarOnly,
                pid: primary.pid,
                memoryFootprint: footprints.isEmpty ? nil : footprints.reduce(0, +)
            ))
        }

        // Name sort as before; the bundle ID tie-break keeps the element-wise
        // zip comparison in refreshMenuItems aligned when two distinct bundle
        // IDs share a display name.
        return items.sorted {
            let order = $0.processName.localizedCaseInsensitiveCompare($1.processName)
            return order == .orderedAscending
                || (order == .orderedSame && $0.bundleIdentifier < $1.bundleIdentifier)
        }
    }

    private func getMenuItemsFromRunningApps() -> [MenuBarItem] {
        let runningApps = NSWorkspace.shared.runningApplications
        let skipBundleIDs = Self.systemAgentBundleIDs

        var candidates: [ProcessCandidate] = []
        for app in runningApps {
            guard !app.isTerminated,
                  let bundleID = app.bundleIdentifier,
                  let name = app.localizedName,
                  !bundleID.isEmpty,
                  !name.isEmpty else {
                continue
            }

            if bundleID == Bundle.main.bundleIdentifier { continue }
            if skipBundleIDs.contains(bundleID) { continue }

            if app.activationPolicy == .regular {
                candidates.append(ProcessCandidate(
                    bundleIdentifier: bundleID,
                    processName: name,
                    pid: app.processIdentifier,
                    isRegular: true
                ))
                _ = cachedIcon(for: app, bundleID: bundleID)
            } else if app.activationPolicy == .accessory {
                guard !bundleID.hasPrefix("com.apple.WebKit.") else { continue }
                guard !bundleID.hasPrefix("com.apple.") else { continue }

                candidates.append(ProcessCandidate(
                    bundleIdentifier: bundleID,
                    processName: name,
                    pid: app.processIdentifier,
                    isRegular: false
                ))
                _ = cachedIcon(for: app, bundleID: bundleID)
            }
        }

        // Every candidate warmed the cache above, so it holds an icon for each
        // listed bundle ID.
        return Self.assembleItems(from: candidates, icons: iconCache)
    }

    /// First two segments of a bundle identifier ("com.docker" from
    /// "com.docker.helper"); nil when the identifier has fewer than two segments.
    /// `nonisolated` (pure string logic) and internal for unit tests.
    static nonisolated func baseBundleID(of identifier: String) -> String? {
        let parts = identifier.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return nil }
        return parts.prefix(2).joined(separator: ".")
    }

    /// Physical memory footprint of a process in bytes (Activity Monitor's
    /// "Memory" column reads the same `ri_phys_footprint`). nil when the
    /// lookup fails. Compiled out of the sandboxed MAS build: reading other
    /// processes' rusage is outside the App Store sandbox contract.
    /// `nonisolated` (pure syscall, no actor state) so the nonisolated
    /// `assembleItems` can call it.
    static nonisolated func physFootprint(pid: pid_t) -> UInt64? {
#if MAC_APP_STORE
        return nil
#else
        var usage = rusage_info_current()
        let result = withUnsafeMutablePointer(to: &usage) { ptr in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { infoPtr in
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, infoPtr)
            }
        }
        guard result == 0 else { return nil }
        return usage.ri_phys_footprint
#endif
    }

#if !MAC_APP_STORE
    /// Quits the app behind a single button: graceful `terminate()` first,
    /// then automatic escalation to `forceTerminate()` if it is still alive
    /// after a short grace period. Replaces the old quit/force-quit pair,
    /// which read as two identical outcomes to the user.
    ///
    /// One item can stand for several processes (same bundle ID, see
    /// `assembleItems`), so every matching process is terminated; whichever
    /// survive the grace period are force-terminated together.
    ///
    /// Optimisations over the previous version:
    /// 1. The row disappears from the list the moment the button is clicked,
    ///    not at the next timer tick (up to `refreshInterval` away).
    /// 2. Each `terminate()` runs on its own detached Task so a stuck target
    ///    can no longer block the UI thread while waiting on its Apple Event
    ///    reply.
    /// 3. Rapid double-clicks on Quit for the same bundle ID are coalesced
    ///    into the in-flight terminate + escalate cycle.
    /// 4. The grace period shortens from 3 s to 1.5 s: any app that respects
    ///    the Apple Event has quit by then, and the timeout exists only for
    ///    stuck targets.
    /// 5. `didTerminateApplicationNotification` clears the bookkeeping on
    ///    success; the row stays gone without a forced timer reconcile.
    func quitApp(_ item: MenuBarMonitor.MenuBarItem) {
        let bundleID = item.bundleIdentifier
        guard !bundleID.isEmpty else { return }
        // Coalesce re-entry: a second click while the first terminate is
        // still in flight would just queue more Apple Events against a
        // target that already knows it's quitting.
        guard !quittingBundleIDs.contains(bundleID) else { return }

        let matches = NSWorkspace.shared.runningApplications
            .filter { $0.bundleIdentifier == bundleID }
        guard !matches.isEmpty else { return }

        quittingBundleIDs.insert(bundleID)

        // -terminate posts an Apple Event ('quit') to the target and waits
        // synchronously for the reply: a stuck target blocks its caller.
        // Push each call onto its own detached Task so a single misbehaving
        // app can't lock up the batch, and so the UI thread is never the
        // one doing the waiting.
        let pending = matches
        for app in pending {
            let target = app
            Task.detached {
                target.terminate()
            }
        }

        // Immediate visual feedback. The terminate notification handler
        // (and the timer fallback) reconciles with the ground truth once
        // the process actually exits; this just removes the lag between
        // click and row disappearing.
        menuBarItems.removeAll { $0.bundleIdentifier == bundleID }

        // Escalation deadline. The terminate notification clears the
        // `quittingBundleIDs` entry on success, so this Task only wakes up
        // to force-terminate stragglers and tidy the bookkeeping.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard let self else { return }
            for app in pending where !app.isTerminated {
                app.forceTerminate()
            }
            self.quittingBundleIDs.remove(bundleID)
        }
    }
#endif

    /// Whether "Open" can actually bring this app forward. Dock apps respond
    /// to `activate()` unconditionally; accessory apps need a bundle URL for
    /// the `openApplication` re-launch path, otherwise the button would be a
    /// no-op and should not be shown at all.
    func canOpen(_ item: MenuBarMonitor.MenuBarItem) -> Bool {
        guard NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == item.bundleIdentifier }) else {
            return false
        }
        if item.appType == .dockOnly { return true }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleIdentifier) != nil
    }

    /// Whether "Quit" is meaningful. Finder ignores terminate (it relaunches),
    /// so the button would be dead weight there.
    func canQuit(_ item: MenuBarMonitor.MenuBarItem) -> Bool {
        item.bundleIdentifier != "com.apple.Finder"
    }

    func activateApp(_ item: MenuBarItem) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == item.bundleIdentifier }) else { return }
        app.unhide()
        if item.appType == .statusbarOnly {
            // NSRunningApplication.activate() cannot foreground accessory apps
            // (macOS security restriction). Re-opening the bundle activates a
            // running app (or launches it if it quit in the meantime), which
            // replaces the deprecated launchApplication(withBundleIdentifier:).
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            guard let url = app.bundleURL ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleIdentifier) else {
                // Some accessory processes have no bundle URL. `activate()` is
                // best-effort for those, but better than silently doing nothing.
                app.activate()
                return
            }
            Task {
                _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: config)
            }
        } else {
            app.activate()
        }
    }
}

extension Notification.Name {
    static let refreshIntervalChanged = Notification.Name("refreshIntervalChanged")
    static let menuBarItemsChanged = Notification.Name("menuBarItemsChanged")
    /// Summon the main window (AppDelegate handles the actual window work).
    static let openMainWindow = Notification.Name("openMainWindow")
    /// Summon the main window and switch it to the settings tab.
    static let openSettingsTab = Notification.Name("openSettingsTab")
    /// Switch the (already visible) main window to the settings tab.
    static let selectSettingsTab = Notification.Name("selectSettingsTab")
    /// Main-window visibility may have changed — re-evaluate the Dock policy.
    static let mainWindowVisibilityChanged = Notification.Name("mainWindowVisibilityChanged")
}
