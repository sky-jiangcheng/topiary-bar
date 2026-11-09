import AppKit
import SwiftUI
import Combine
import CoreGraphics

// v6 probe: does a confirmationDialog die when its HOSTING VIEW leaves the
// view tree? PopoverView.IconRow gates the Quit button (and therefore the
// .confirmationDialog riding on it) behind `if isHovered`, so moving the
// pointer toward the dialog clears the hover state and removes that subtree.
//
// STYLE=gated    mirrors IconRow exactly (dialog attached inside `if hovered`)
// STYLE=hoisted  the fix candidate (buttons stay in the tree, hover only gates
//                visibility; the dialog rides on a stable ancestor)

let startTime = Date()
let style = ProcessInfo.processInfo.environment["STYLE"] ?? "gated"

func log(_ s: String) {
    let t = String(format: "%6.2f", Date().timeIntervalSince(startTime))
    FileHandle.standardOutput.write("[\(t)] \(s)\n".data(using: .utf8)!)
}

final class RowState: ObservableObject {
    @Published var hovered = false
    @Published var showConfirm = false
}

let rowState = RowState()

struct GatedRow: View {
    @ObservedObject var st: RowState
    var body: some View {
        HStack(spacing: 10) {
            Text("SomeMenuBarApp").frame(maxWidth: .infinity, alignment: .leading)
            if st.hovered {
                Button("Open") { } .buttonStyle(.bordered).controlSize(.mini)
                Button("Quit") {
                    log("QUIT ACTION RAN -> showConfirm = true")
                    st.showConfirm = true
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .confirmationDialog("Quit “SomeMenuBarApp”?", isPresented: $st.showConfirm, titleVisibility: .visible) {
                    Button("Quit", role: .destructive) { log(">>> DESTRUCTIVE FIRED") }
                    Button("Cancel", role: .cancel) { log(">>> CANCEL FIRED") }
                } message: {
                    Text("This will terminate the app immediately.")
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { inside in log("onHover -> \(inside)"); st.hovered = inside }
    }
}

struct HoistedRow: View {
    @ObservedObject var st: RowState
    var body: some View {
        HStack(spacing: 10) {
            Text("SomeMenuBarApp").frame(maxWidth: .infinity, alignment: .leading)
            Button("Open") { } .buttonStyle(.bordered).controlSize(.mini)
            Button("Quit") {
                log("QUIT ACTION RAN -> showConfirm = true")
                st.showConfirm = true
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(.horizontal, 16).padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        // hover only paints; the buttons never leave the tree
        .opacity(st.hovered ? 1 : 1)
        .overlay(alignment: .trailing) {
            HStack(spacing: 10) {
                Button("Open") { } .buttonStyle(.bordered).controlSize(.mini)
                Button("Quit") {
                    log("QUIT ACTION RAN (overlay) -> showConfirm = true")
                    st.showConfirm = true
                }
                .buttonStyle(.bordered).controlSize(.mini)
            }
            .padding(.trailing, 16)
            .opacity(st.hovered ? 1 : 0)
            .allowsHitTesting(st.hovered)
        }
        // the presentation rides on a STABLE ancestor instead
        .confirmationDialog("Quit “SomeMenuBarApp”?", isPresented: $st.showConfirm, titleVisibility: .visible) {
            Button("Quit", role: .destructive) { log(">>> DESTRUCTIVE FIRED") }
            Button("Cancel", role: .cancel) { log(">>> CANCEL FIRED") }
        } message: {
            Text("This will terminate the app immediately.")
        }
        .onHover { inside in log("onHover -> \(inside)"); st.hovered = inside }
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

func findAppButtons() -> [String] {
    NSApp.windows.filter { $0.isVisible }.flatMap { w in
        collectButtons(w.contentView).filter { !$0.title.isEmpty }.map { "<\(clsName(w))> '\($0.title)'" }
    }
}

func alertState() -> (count: Int, visible: Int, key: Bool) {
    let alerts = NSApp.windows.filter { clsName($0).contains("Alert") }
    return (alerts.count, alerts.filter { $0.isVisible }.count, alerts.contains { $0.isKeyWindow })
}

func phase(_ name: String) {
    let a = alertState()
    log("\(name): hovered=\(rowState.hovered) showConfirm=\(rowState.showConfirm) "
        + "alertWindows=\(a.count) alertVisible=\(a.visible) alertIsKey=\(a.key)")
    log("   buttons on screen: \(findAppButtons().description)")
}

final class HDel: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var item: NSStatusItem!
    let pop = NSPopover()

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "HG"

        pop.contentSize = NSSize(width: 360, height: 90)
        pop.behavior = .transient
        pop.animates = false
        let root: AnyView = style == "hoisted"
            ? AnyView(HoistedRow(st: rowState).frame(width: 360, height: 90))
            : AnyView(GatedRow(st: rowState).frame(width: 360, height: 90))
        let vc = NSViewController()
        vc.view = NSHostingView(rootView: root)
        pop.contentViewController = vc
        pop.delegate = self

        log("STYLE=\(style)")
        after(1.0) {
            self.pop.show(relativeTo: self.item.button!.bounds, of: self.item.button!, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
        after(2.0) { phase("1 popover open, not hovered") }
        after(2.4) { log("SET hovered = true (pointer over the row)"); rowState.hovered = true }
        after(2.9) { phase("2 hovered, Quit button materialised") }
        after(3.2) { log("PRESENT dialog while hovered"); rowState.showConfirm = true }
        after(4.0) { phase("3 dialog up, still hovered") }
        after(4.4) {
            log("SET hovered = false (pointer leaves the row on its way to the dialog)")
            rowState.hovered = false
            CGWarpMouseCursorPosition(CGPoint(x: 40, y: 700))
        }
        after(5.2) { phase("4 AFTER hover cleared") }
        after(6.0) {
            let a = alertState()
            log("VERDICT style=\(style) dialogSurvivedUnhover=\(a.visible > 0) showConfirmStillTrue=\(rowState.showConfirm)")
            NSApp.terminate(nil)
        }
    }

    func after(_ t: TimeInterval, _ body: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: body)
    }
}

let app = NSApplication.shared
let probeDelegate = HDel()
app.delegate = probeDelegate
app.run()
