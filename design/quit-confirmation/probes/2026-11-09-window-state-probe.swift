import AppKit
import SwiftUI
import Combine
import CoreGraphics

// v3 probe for Topiary's popover "Quit" confirmationDialog being visible but
// mouse-dead while the identical dialog works in the main window.
//
// v2 lesson: matching "a window that appeared since baseline" picked the
// NSStatusBarWindow (it has the PR button). v3 locks windows by CLASS NAME and
// proves event routing with AppKit's OWN hitTest (no Accessibility needed).
//
// MODE:
//   transient         baseline = Topiary's real shape (.transient popover)
//   flip              control 1: behavior -> .applicationDefined before present (fix A)
//   closefirst        control 2: close popover, then present (fix C)
//   mainwindow        control 3: same dialog from a titled window, policy .regular
//   titledaccessory   sub-control: titled window but policy stays .accessory
//   sheets            fix candidate: hand-written NSAlert.beginSheetModal(on popover window)

let startTime = Date()

func log(_ s: String) {
    let t = String(format: "%6.2f", Date().timeIntervalSince(startTime))
    FileHandle.standardOutput.write("[\(t)] \(s)\n".data(using: .utf8)!)
}

final class Probe: ObservableObject {
    @Published var showConfirm = false
    var destructiveFired = false
    var cancelFired = false
}

struct ReproView: View {
    @ObservedObject var probe: Probe
    var body: some View {
        VStack(spacing: 12) {
            Text("Topiary (probe)").font(.headline)
            Spacer()
            HStack {
                Button("Settings") { } .buttonStyle(.plain)
                Spacer()
                Button("Quit") { probe.showConfirm = true }
                    .buttonStyle(.plain)
                    .confirmationDialog(
                        "Quit Topiary?", isPresented: $probe.showConfirm, titleVisibility: .visible
                    ) {
                        Button("Quit", role: .destructive) {
                            log(">>> DESTRUCTIVE ACTION FIRED")
                            probe.destructiveFired = true
                        }
                        Button("Cancel", role: .cancel) {
                            log(">>> CANCEL ACTION FIRED")
                            probe.cancelFired = true
                        }
                    } message: {
                        Text("Topiary will stop managing your menu bar apps.")
                    }
            }
        }
        .padding(16)
        .frame(width: 360, height: 300)
    }
}

func clsName(_ o: Any) -> String { String(describing: type(of: o)) }

func collectButtons(_ v: NSView?) -> [NSButton] {
    guard let v else { return [] }
    var out: [NSButton] = []
    if let b = v as? NSButton { out.append(b) }
    for s in v.subviews { out.append(contentsOf: collectButtons(s)) }
    return out
}

func viewTree(_ v: NSView, _ depth: Int, _ limit: Int) -> [String] {
    guard depth <= limit else { return [] }
    var out = ["\(String(repeating: "  ", count: depth))<\(clsName(v))> frame=\(NSStringFromRect(v.frame)) hidden=\(v.isHidden) alpha=\(String(format: "%.2f", v.alphaValue))"]
    for s in v.subviews { out.append(contentsOf: viewTree(s, depth + 1, limit)) }
    return out
}

func screenCenter(of v: NSView) -> NSPoint? {
    guard let w = v.window else { return nil }
    let p = NSPoint(x: v.bounds.midX, y: v.bounds.midY)
    let base = v.convert(p, to: nil)
    return w.convertToScreen(NSRect(origin: base, size: .zero)).origin
}

func describe(_ w: NSWindow) -> String {
    let btns = collectButtons(w.contentView).map { "'\($0.title)'" }
    return "<\(clsName(w))> #\(w.windowNumber) title='\(w.title)' level=\(w.level.rawValue) "
        + "visible=\(w.isVisible) key=\(w.isKeyWindow) canBecomeKey=\(w.canBecomeKey) "
        + "ignoresMouse=\(w.ignoresMouseEvents) parent=\(w.parent.map { "<\(clsName($0))>" } ?? "nil") "
        + "childWindows=\(w.childWindows?.count ?? 0) frame=\(NSStringFromRect(w.frame)) btns=[\(btns.joined(separator: ", "))]"
}

final class ProbeDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let mode = ProcessInfo.processInfo.environment["MODE"] ?? "transient"
    var item: NSStatusItem!
    let pop = NSPopover()
    var host: NSHostingView<ReproView>!
    let probe = Probe()
    var titled: NSWindow?

    var alertWindows: [NSWindow] = []
    var glassWindows: [NSWindow] = []
    var verdictAlertIsTopmost = false
    var verdictHitResolvesToAlert = false
    var verdictPerformClickFired = false
    var hoverPoint: NSPoint?
    var survivedHover = false

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "PR"
        host = NSHostingView(rootView: ReproView(probe: probe))
        let vc = NSViewController(); vc.view = host
        pop.contentSize = NSSize(width: 360, height: 300)
        pop.animates = false
        pop.contentViewController = vc
        pop.delegate = self

        switch mode {
        case "mainwindow": pop.behavior = .transient
        case "titledaccessory": pop.behavior = .transient
        case "flip": pop.behavior = .transient
        default: pop.behavior = .transient
        }

        let titledHost = (mode == "mainwindow" || mode == "titledaccessory")
        if titledHost && mode == "mainwindow" {
            NSApp.setActivationPolicy(.regular)
        }
        log("MODE=\(mode) LSUIElement=\(Bundle.main.object(forInfoDictionaryKey: "LSUIElement") ?? "nil") policy=\(NSApp.activationPolicy().rawValue)")

        after(1.0) {
            if titledHost {
                let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
                                 styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
                w.title = "Topiary probe main window"
                w.contentView = NSHostingView(rootView: ReproView(probe: self.probe))
                w.center()
                w.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                self.titled = w
                log("titled window created: \(describe(w))")
            } else {
                self.pop.show(relativeTo: self.item.button!.bounds, of: self.item.button!, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        after(2.0) { self.snapshot("A: before dialog") }
        after(2.6) {
            switch self.mode {
            case "flip":
                log("--- flip: behavior -> .applicationDefined (fix A) ---")
                self.pop.behavior = .applicationDefined
            case "closefirst":
                log("--- closefirst: closing popover, then presenting (fix C) ---")
                self.pop.performClose(nil)
            case "sheets":
                self.runAppKitSheet()
                return
            default:
                break
            }
            log("--- presenting SwiftUI confirmationDialog ---")
            self.probe.showConfirm = true
        }
        after(3.6) { self.analyze("B: dialog up, pointer NOT yet moved") }
        after(4.4) { self.warpOntoDialogButton("C") }
        after(5.3) { self.snapshot("D: right after hover onto the dialog button") }
        after(5.6) { self.wiggleCursor() }
        after(6.6) { self.snapshot("E: after cursor wiggle over the dialog") }
        after(6.9) { self.proveWiring() }
        after(7.6) {
            let alertAlive = self.alertWindows.contains { $0.isVisible }
            log("VERDICT2 mode=\(self.mode) popoverShownAfterHover=\(self.pop.isShown) dialogAliveAfterHover=\(alertAlive) "
                + "dialogSurvivedHover=\(self.survivedHover) closefirstMode=\(self.mode == "closefirst")")
        }
        after(7.8) {
            log("VERDICT mode=\(self.mode) alertWindows=\(self.alertWindows.count) glassWindows=\(self.glassWindows.count) "
                + "alertIsTopmostAtButton=\(self.verdictAlertIsTopmost) hitTestResolvesToAlert=\(self.verdictHitResolvesToAlert) "
                + "performClickFired=\(self.verdictPerformClickFired) "
                + "destructiveFired=\(self.probe.destructiveFired) popoverShown=\(self.titled != nil ? "n/a" : "\(self.pop.isShown)")")
            NSApp.terminate(nil)
        }
    }

    func popoverDidShow(_ n: Notification) { log("### popoverDidShow behavior=\(self.pop.behavior.rawValue)") }
    func popoverDidClose(_ n: Notification) {
        log("### popoverDidClose reason=\((n.userInfo?[NSPopover.closeReasonUserInfoKey] as? String) ?? "?")")
    }

    func after(_ t: TimeInterval, _ body: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: body)
    }

    /// Exact class-name lock. Also reports everything else that has buttons so
    /// a future rename of the private classes cannot silently fool us again.
    func findDialogWindows() {
        alertWindows = NSApp.windows.filter { clsName($0).contains("Alert") }
        glassWindows = NSApp.windows.filter { clsName($0).contains("Glass") }
        let others = NSApp.windows.filter {
            !clsName($0).contains("Alert") && !clsName($0).contains("Glass")
                && $0.isVisible && !collectButtons($0.contentView).isEmpty
        }
        if alertWindows.isEmpty {
            log("  no window class containing 'Alert'; windows with buttons: "
                + others.map { "<\(clsName($0))> btns=\(collectButtons($0.contentView).map { $0.title })" }.description)
        }
    }

    func snapshot(_ phase: String) {
        log("===== \(phase) =====")
        log("  appActive=\(NSApp.isActive) policy=\(NSApp.activationPolicy().rawValue) "
            + "modalWindow=\(NSApp.modalWindow.map { "<\(clsName($0))>" } ?? "nil") "
            + "keyWindow=\(NSApp.keyWindow.map { "<\(clsName($0))>" } ?? "nil") "
            + "runloopMode=\(RunLoop.current.currentMode?.rawValue ?? "?")")
        if titled == nil { log("  popover.isShown=\(pop.isShown) behavior=\(pop.behavior.rawValue)") }
        findDialogWindows()
        log("  ALERT x\(alertWindows.count): " + alertWindows.map { describe($0) }.joined(separator: "\n    "))
        log("  GLASS x\(glassWindows.count): " + glassWindows.map { describe($0) }.joined(separator: "\n    "))
        logWindowServerOrder()
    }

    func logWindowServerOrder() {
        let mine = Int(ProcessInfo.processInfo.processIdentifier)
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }
        log("  CGWINDOWLIST (front to back, this process):")
        for (i, info) in list.enumerated() {
            guard let owner = info[kCGWindowOwnerPID as String] as? Int, owner == mine else { continue }
            let b = info[kCGWindowBounds as String] as? [String: Any] ?? [:]
            let num = info[kCGWindowNumber as String] as? Int ?? -1
            let w = NSApp.windows.first { $0.windowNumber == num }
            log("    #\(i) number=\(num) layer=\(info[kCGWindowLayer as String] as? Int ?? -1) cls=\(w.map { clsName($0) } ?? "?") bounds=\(b["Width"] ?? "?")x\(b["Height"] ?? "?")@(\(b["X"] ?? "?"),\(b["Y"] ?? "?"))")
        }
    }

    /// WindowServer's own front-to-back answer for a screen point.
    func topmostWindowAtAppKitPoint(_ p: NSPoint) -> NSWindow? {
        let mine = Int(ProcessInfo.processInfo.processIdentifier)
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let cg = CGPoint(x: p.x, y: primaryHeight - p.y)
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for info in list {
            guard let owner = info[kCGWindowOwnerPID as String] as? Int, owner == mine else { continue }
            guard let b = info[kCGWindowBounds as String] as? [String: Any],
                  let x = b["X"] as? CGFloat, let y = b["Y"] as? CGFloat,
                  let w = b["Width"] as? CGFloat, let h = b["Height"] as? CGFloat else { continue }
            if CGRect(x: x, y: y, width: w, height: h).contains(cg) {
                let num = info[kCGWindowNumber as String] as? Int ?? -1
                return NSApp.windows.first { $0.windowNumber == num }
            }
        }
        return nil
    }

    func proveWiring() {
        guard let alert = alertWindows.first(where: { $0.isVisible }) ?? alertWindows.first else {
            log("WIRING: no Alert window to probe (it vanished before we got here)"); return
        }
        guard let quit = collectButtons(alert.contentView).first(where: { $0.title == "Quit" }) else {
            log("WIRING: no Quit button inside Alert"); return
        }
        log("WIRING: performClick on Alert's Quit (bypasses all event routing) -> proves wiring")
        quit.performClick(nil)
        after(0.35) {
            self.verdictPerformClickFired = self.probe.destructiveFired
            log("WIRING: performClick result destructiveFired=\(self.probe.destructiveFired)")
        }
    }

    func analyze(_ phase: String) {
        snapshot(phase)
        guard let alert = alertWindows.first else {
            log("ANALYZE: no Alert-class window exists -> the dialog never got its own window"); return
        }
        for b in collectButtons(alert.contentView) where !b.title.isEmpty {
            guard let p = screenCenter(of: b) else { continue }
            guard let top = topmostWindowAtAppKitPoint(p) else {
                log("  button '\(b.title)' at \(NSStringFromPoint(p)) -> nothing on screen there"); continue
            }
            let local = top.convertPoint(fromScreen: p)
            let hit = top.contentView?.hitTest(local)
            let resolvesToAlert = (hit?.window === alert)
            let isAlert = top.windowNumber == alert.windowNumber
            verdictAlertIsTopmost = verdictAlertIsTopmost || isAlert
            verdictHitResolvesToAlert = verdictHitResolvesToAlert || resolvesToAlert
            log("  button '\(b.title)' appkit=\(NSStringFromPoint(p)) topmostWindow=<\(clsName(top))>#\(top.windowNumber) topmostIsAlert=\(isAlert) "
                + "hitTestInView=\(hit.map { clsName($0) } ?? "nil") hitResolvesToAlert=\(resolvesToAlert)")
            if hit == nil {
                log("    topmost window view tree:\n" + (top.contentView.map { viewTree($0, 1, 3).joined(separator: "\n") } ?? "-"))
            }
        }
    }

    /// Fix candidate: skip SwiftUI entirely and use a hand-written NSAlert as a
    /// window-modal sheet on the popover's own window.
    func runAppKitSheet() {
        guard let parent = pop.contentViewController?.view.window ?? host.window else {
            log("SHEETS: no popover window to attach the sheet to"); return
        }
        log("SHEETS: beginSheetModal(for: <\(clsName(parent))>#\(parent.windowNumber) level=\(parent.level.rawValue))")
        let a = NSAlert()
        a.messageText = "Quit Topiary?"
        a.informativeText = "Topiary will stop managing your menu bar apps."
        a.addButton(withTitle: "Quit")
        a.addButton(withTitle: "Cancel")
        a.beginSheetModal(for: parent) { resp in
            log("SHEETS: completion handler response=\(resp.rawValue)")
            if resp == .alertFirstButtonReturn { self.probe.destructiveFired = true }
        }
    }

    /// Move the hardware cursor onto the dialog's Quit button. This is the one
    /// thing v3 never did, and the observation "hover makes it vanish" says it
    /// is the trigger. CGWarpMouseCursorPosition needs no Accessibility.
    func warpOntoDialogButton(_ tag: String) {
        // Mirror the real app: Topiary activates itself when the icon is clicked,
        // so the pointer has to travel to the dialog while the app is active.
        NSApp.activate(ignoringOtherApps: true)
        guard let alert = alertWindows.first(where: { $0.isVisible }) else {
            log("HOVER: no visible Alert window to hover"); return
        }
        guard let quit = collectButtons(alert.contentView).first(where: { $0.title == "Quit" })
                ?? collectButtons(alert.contentView).first else {
            log("HOVER: no button inside the Alert window"); return
        }
        guard let p = screenCenter(of: quit) else { log("HOVER: cannot compute button centre"); return }
        hoverPoint = p
        let h = NSScreen.screens.first?.frame.height ?? 0
        let cg = CGPoint(x: p.x, y: h - p.y)
        log("HOVER: warping cursor to appkit=\(NSStringFromPoint(p)) cg=(\(cg.x),\(cg.y)) (over '\(quit.title)')")
        CGWarpMouseCursorPosition(cg)
        after(0.25) {
            log("HOVER: NSEvent.mouseLocation=\(NSStringFromPoint(NSEvent.mouseLocation)) "
                + "alert.mouseLocationOutsideOfEventStream=\(NSStringFromPoint(alert.mouseLocationOutsideOfEventStream)) "
                + "alertVisible=\(alert.isVisible) popoverShown=\(self.pop.isShown) "
                + "keyWindow=\(NSApp.keyWindow.map { clsName($0) } ?? "nil")")
            self.survivedHover = alert.isVisible
        }
    }

    /// Small back-and-forth motion so WindowServer emits real mouse-moved events
    /// for the window under the cursor (warp alone may only relocate the cursor).
    func wiggleCursor() {
        guard let p = hoverPoint else { log("WIGGLE: no hover point"); return }
        let h = NSScreen.screens.first?.frame.height ?? 0
        for (i, dx) in [CGFloat(0), 3, -3, 1, -1, 0].enumerated() {
            usleep(UInt32(i * 15_000))
            CGWarpMouseCursorPosition(CGPoint(x: p.x + CGFloat(dx), y: h - p.y))
            CGAssociateMouseAndMouseCursorPosition(1)
        }
        log("WIGGLE: moved cursor +/-3px across the dialog button")
    }

    @objc func click() { if pop.isShown { pop.performClose(nil) } }
}

let app = NSApplication.shared
let probeDelegate = ProbeDelegate()
app.delegate = probeDelegate
app.run()
