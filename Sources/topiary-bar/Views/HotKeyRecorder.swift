import AppKit
import Carbon.HIToolbox
import SwiftUI

/// macOS-style hotkey recorder backed by a custom NSView: click to arm,
/// press a combo, click elsewhere or hit Escape to cancel. First-responder
/// based, so `keyDown` delivers real virtual key codes for any key
/// (letters, digits, punctuation, F-keys). A trailing clear button disables
/// the shortcut entirely (binding becomes nil).
struct HotKeyRecorder: NSViewRepresentable {
    @Binding var hotKey: HotKeyValue?
    let l10n: L10nTable

    func makeNSView(context: Context) -> HotKeyRecorderView {
        let view = HotKeyRecorderView()
        view.onChange = { newValue in
            hotKey = newValue
        }
        return view
    }

    func updateNSView(_ nsView: HotKeyRecorderView, context: Context) {
        nsView.currentDisplay = hotKey?.display ?? l10n.hotKeyNone
        nsView.recordingText = l10n.hotKeyRecording
    }
}

/// The recorder plus its clear affordance, laid out as one control.
struct HotKeyRecorderField: View {
    @Binding var hotKey: HotKeyValue?
    let l10n: L10nTable

    var body: some View {
        HStack(spacing: 8) {
            HotKeyRecorder(hotKey: $hotKey, l10n: l10n)
                .frame(minWidth: 130, minHeight: 28)

            if hotKey != nil {
                Button {
                    hotKey = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(HoverIconButtonStyle(size: 22, isDestructive: true))
                .help(l10n.hotKeyClear)
                .accessibilityLabel(l10n.hotKeyClear)
            }
        }
    }
}

final class HotKeyRecorderView: NSView {
    /// Called with the newly recorded combination.
    var onChange: ((HotKeyValue) -> Void)?
    var currentDisplay = ""
    var recordingText = ""

    private var isRecording = false {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    /// Losing focus (click elsewhere) cancels recording.
    override func resignFirstResponder() -> Bool {
        isRecording = false
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        // Escape cancels without changing the binding.
        if event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            needsDisplay = true
            return
        }

        let carbon = HotKeyValue.carbonModifiers(from: event.modifierFlags)
        // Require at least one of ⌘/⌃/⌥ so plain keys stay usable in forms.
        guard carbon & UInt32(cmdKey | controlKey | optionKey) != 0 else { return }

        let key = event.charactersIgnoringModifiers ?? ""
        guard !key.isEmpty else { return }

        isRecording = false
        needsDisplay = true
        onChange?(HotKeyValue(
            keyCode: UInt32(event.keyCode),
            modifiers: carbon,
            display: HotKeyValue.displayGlyphs(carbon) + key.uppercased()
        ))
    }

    override func draw(_ dirtyRect: NSRect) {
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let background = isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.18)
            : (isDark ? NSColor.white.withAlphaComponent(0.06) : NSColor.black.withAlphaComponent(0.04))

        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        background.setFill()
        path.fill()

        let strokeColor = isRecording
            ? NSColor.controlAccentColor
            : (isDark ? NSColor.white.withAlphaComponent(0.12) : NSColor.black.withAlphaComponent(0.08))
        strokeColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = isRecording ? recordingText : currentDisplay
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium),
            .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor,
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let size = attributed.size()
        attributed.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2))
    }
}
