import CoreGraphics
import Foundation

// Cross-process WindowServer snapshot: real z-order, layers, geometry, alpha.
// Needs no Accessibility (CGWindowList is public). Watches for a target app
// (default substring "Topiary") and dumps a frame whenever its window set
// changes, pairing each frame with a screencapture PNG.

let args = CommandLine.arguments
let matchName = args.count > 1 ? args[1] : "Topiary"
let seconds = args.count > 2 ? (Int(args[2]) ?? 75) : 75
let outDir = args.count > 3 ? args[3] : FileManager.default.currentDirectoryPath

func frameSignature(_ wins: [CGWindow]) -> String {
    wins.map { "\($0.number):\($0.layer):\(Int($0.bounds.origin.x)),\(Int($0.bounds.origin.y)),\(Int($0.bounds.width))x\(Int($0.bounds.height))" }
        .joined(separator: "|")
}

struct CGWindow {
    let number: Int, layer: Int, owner: Int, ownerName: String, name: String, alpha: Double, bounds: CGRect
}

func snapshot() -> [CGWindow] {
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
    var out: [CGWindow] = []
    for info in list {
        let ownerName = (info[kCGWindowOwnerName as String] as? String) ?? ""
        guard ownerName.localizedCaseInsensitiveContains(matchName) else { continue }
        let b = info[kCGWindowBounds as String] as? [String: Any] ?? [:]
        let x = (b["X"] as? CGFloat) ?? 0, y = (b["Y"] as? CGFloat) ?? 0
        let w = (b["Width"] as? CGFloat) ?? 0, h = (b["Height"] as? CGFloat) ?? 0
        out.append(CGWindow(
            number: info[kCGWindowNumber as String] as? Int ?? -1,
            layer: info[kCGWindowLayer as String] as? Int ?? -1,
            owner: info[kCGWindowOwnerPID as String] as? Int ?? -1,
            ownerName: ownerName,
            name: (info[kCGWindowName as String] as? String) ?? "",
            alpha: (info[kCGWindowAlpha as String] as? Double) ?? -1,
            bounds: CGRect(x: x, y: y, width: w, height: h)))
    }
    return out
}

func appWindows() -> [CGWindow] { snapshot() }

print("windowdump: watching owner name containing '\(matchName)' for \(seconds)s, out=\(outDir)")
print("CG coordinates are top-left origin, y down. List order = front to back.")

let start = Date()
var lastSignature = ""
var frame = 0
while Date().timeIntervalSince(start) < Double(seconds) {
    let wins = appWindows()
    let sig = frameSignature(wins)
    if sig != lastSignature && !wins.isEmpty {
        lastSignature = sig
        frame += 1
        let t = String(format: "%6.1f", Date().timeIntervalSince(start))
        print("--- frame \(frame) @\(t)s  windows=\(wins.count) ---")
        for (i, w) in wins.enumerated() {
            print(String(format: "  #%02d number=%d layer=%d alpha=%.2f pid=%d bounds=%.0fx%.0f@(%.0f,%.0f) name='%@'",
                         i, w.number, w.layer, w.alpha, w.owner, w.bounds.width, w.bounds.height, w.bounds.origin.x, w.bounds.origin.y, w.name))
        }
        fflush(stdout)
        let png = "\(outDir)/frame_\(String(format: "%02d", frame)).png"
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-x", "-o", "-t", "png", png]
        try? task.run()
        task.waitUntilExit()
        print("  screenshot -> \(png)")
        fflush(stdout)
    }
    usleep(400_000)
}
print("windowdump: done, \(frame) frames")
