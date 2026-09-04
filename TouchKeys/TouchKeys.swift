// TouchKeys — auto-showing onscreen touch keyboard for macOS
// Shows a non-activating keyboard panel whenever a text input has focus,
// hides it when focus moves elsewhere. Types by posting CGEvents.

import AppKit
import ApplicationServices

// MARK: - Key model

struct Key {
    let label: String          // label on the letters layer
    let shifted: String?       // label when shift is active (nil = uppercase of label)
    let keyCode: CGKeyCode
    let width: CGFloat         // relative width, 1.0 = standard key
    let isModifier: Bool
    let usesShiftFlag: Bool    // post with shift flag when shift active

    init(_ label: String, _ keyCode: CGKeyCode, width: CGFloat = 1.0,
         shifted: String? = nil, isModifier: Bool = false, usesShiftFlag: Bool = true) {
        self.label = label; self.keyCode = keyCode; self.width = width
        self.shifted = shifted; self.isModifier = isModifier; self.usesShiftFlag = usesShiftFlag
    }
}

// special sentinel key codes for internal actions
let kShiftKey: CGKeyCode = 0xFFF0
let kLayerKey: CGKeyCode = 0xFFF1
let kHideKey:  CGKeyCode = 0xFFF2

let lettersLayer: [[Key]] = [
    [Key("1",18,shifted:"!"),Key("2",19,shifted:"@"),Key("3",20,shifted:"#"),Key("4",21,shifted:"$"),Key("5",23,shifted:"%"),Key("6",22,shifted:"^"),Key("7",26,shifted:"&"),Key("8",28,shifted:"*"),Key("9",25,shifted:"("),Key("0",29,shifted:")"),Key("⌫",51,width:1.5,usesShiftFlag:false)],
    [Key("q",12),Key("w",13),Key("e",14),Key("r",15),Key("t",17),Key("y",16),Key("u",32),Key("i",34),Key("o",31),Key("p",35)],
    [Key("a",0),Key("s",1),Key("d",2),Key("f",3),Key("g",5),Key("h",4),Key("j",38),Key("k",40),Key("l",37),Key("↵",36,width:1.5,usesShiftFlag:false)],
    [Key("⇧",kShiftKey,width:1.5,isModifier:true),Key("z",6),Key("x",7),Key("c",8),Key("v",9),Key("b",11),Key("n",45),Key("m",46),Key(",",43,shifted:"<"),Key(".",47,shifted:">"),Key("?",44,shifted:"?")],
    [Key("#+=",kLayerKey,width:1.5,isModifier:true),Key("space",49,width:6.0,usesShiftFlag:false),Key("←",123,usesShiftFlag:false),Key("→",124,usesShiftFlag:false),Key("▼",kHideKey,width:1.5,isModifier:true)]
]

let symbolsLayer: [[Key]] = [
    [Key("1",18),Key("2",19),Key("3",20),Key("4",21),Key("5",23),Key("6",22),Key("7",26),Key("8",28),Key("9",25),Key("0",29),Key("⌫",51,width:1.5,usesShiftFlag:false)],
    [Key("!",18,shifted:"!"),Key("@",19,shifted:"@"),Key("#",20,shifted:"#"),Key("$",21,shifted:"$"),Key("%",23,shifted:"%"),Key("^",22,shifted:"^"),Key("&",26,shifted:"&"),Key("*",28,shifted:"*"),Key("(",25,shifted:"("),Key(")",29,shifted:")")],
    [Key("-",27),Key("=",24),Key("[",33),Key("]",30),Key("\\",42),Key(";",41),Key("'",39),Key("`",50),Key("/",44),Key("↵",36,width:1.5,usesShiftFlag:false)],
    [Key("⇧",kShiftKey,width:1.5,isModifier:true),Key("_",27,shifted:"_"),Key("+",24,shifted:"+"),Key("{",33,shifted:"{"),Key("}",30,shifted:"}"),Key("|",42,shifted:"|"),Key(":",41,shifted:":"),Key("\"",39,shifted:"\""),Key("~",50,shifted:"~"),Key("?",44,shifted:"?")],
    [Key("abc",kLayerKey,width:1.5,isModifier:true),Key("space",49,width:6.0,usesShiftFlag:false),Key("esc",53,usesShiftFlag:false),Key("tab",48,usesShiftFlag:false),Key("▼",kHideKey,width:1.5,isModifier:true)]
]

// rows on the symbols layer whose labels are inherently shifted characters
let symbolsShiftedRows: Set<Int> = [1, 3]

// MARK: - Event posting

let keyEventSource = CGEventSource(stateID: .combinedSessionState)

func postKey(_ keyCode: CGKeyCode, shift: Bool) {
    var flags: CGEventFlags = shift ? .maskShift : []
    if keyCode >= 123 && keyCode <= 126 {
        flags.insert(.maskSecondaryFn); flags.insert(.maskNumericPad)
    }
    for down in [true, false] {
        guard let e = CGEvent(keyboardEventSource: keyEventSource, virtualKey: keyCode, keyDown: down) else {
            continue
        }
        e.flags = flags
        e.post(tap: .cgSessionEventTap)
    }
}

// MARK: - Key view

final class KeyView: NSView {
    let key: Key
    let display: String
    let onPress: (Key) -> Void
    private let label = NSTextField(labelWithString: "")
    var highlighted = false { didSet { needsDisplay = true } }
    var latched = false { didSet { needsDisplay = true } }

    init(key: Key, display: String, onPress: @escaping (Key) -> Void) {
        self.key = key; self.display = display; self.onPress = onPress
        super.init(frame: .zero)
        wantsLayer = true
        label.stringValue = display
        label.alignment = .center
        label.font = .systemFont(ofSize: 22, weight: .medium)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let r = NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), xRadius: 8, yRadius: 8)
        if highlighted { NSColor.controlAccentColor.setFill() }
        else if latched { NSColor.controlAccentColor.withAlphaComponent(0.45).setFill() }
        else { NSColor.controlColor.withAlphaComponent(0.92).setFill() }
        r.fill()
    }

    override func mouseDown(with event: NSEvent) { highlighted = true }
    override func mouseUp(with event: NSEvent) {
        highlighted = false
        onPress(key)
    }
    override func rightMouseDown(with event: NSEvent) { highlighted = true }
    override func rightMouseUp(with event: NSEvent) {
        highlighted = false
        onPress(key)
    }
    override func mouseExited(with event: NSEvent) { highlighted = false }
}

// MARK: - Keyboard panel

final class KeyboardController {
    let panel: NSPanel
    private var shiftActive = false
    private var symbolsActive = false
    private var keyViews: [KeyView] = []
    var manuallyHidden = false   // user tapped ▼: stay hidden until focus leaves & returns
    var pinned = false           // shown via menu: ignore auto-hide until menu Hide
    var lastKeyPress = Date.distantPast

    static let keyHeight: CGFloat = 58
    static let unit: CGFloat = 66

    init() {
        panel = NSPanel(contentRect: .zero,
                        styleMask: [.nonactivatingPanel, .borderless, .utilityWindow],
                        backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        rebuild()
    }

    private func rebuild() {
        let layer = symbolsActive ? symbolsLayer : lettersLayer
        let rows = layer.count
        let maxUnits = layer.map { $0.reduce(0) { $0 + $1.width } }.max() ?? 10
        let w = maxUnits * Self.unit + 16
        let h = CGFloat(rows) * Self.keyHeight + 16

        let root = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        root.material = .hudWindow
        root.state = .active
        root.wantsLayer = true
        root.layer?.cornerRadius = 12

        keyViews = []
        for (r, row) in layer.enumerated() {
            let rowUnits = row.reduce(0) { $0 + $1.width }
            var x = (w - rowUnits * Self.unit) / 2
            let y = h - 8 - CGFloat(r + 1) * Self.keyHeight
            for key in row {
                let disp = displayLabel(for: key, row: r)
                let kv = KeyView(key: key, display: disp) { [weak self] k in self?.pressed(k, row: r) }
                kv.frame = NSRect(x: x, y: y, width: key.width * Self.unit, height: Self.keyHeight)
                if key.keyCode == kShiftKey { kv.latched = shiftActive }
                root.addSubview(kv)
                keyViews.append(kv)
                x += key.width * Self.unit
            }
        }

        let origin = panel.frame.origin
        panel.setContentSize(NSSize(width: w, height: h))
        panel.contentView = root
        if origin != .zero { panel.setFrameOrigin(origin) }
    }

    private func displayLabel(for key: Key, row: Int) -> String {
        if key.isModifier || !key.usesShiftFlag { return key.label }
        if shiftActive {
            if let s = key.shifted { return s }
            return key.label.uppercased()
        }
        return key.label
    }

    private var lastKeyCode: CGKeyCode = 0
    private var lastKeyTime = Date.distantPast

    private func pressed(_ key: Key, row: Int) {
        // Debounce: a single tap can arrive as more than one mouseUp; ignore an
        // identical key repeated within 150 ms (faster than any real double-letter tap).
        let now = Date()
        if key.keyCode == lastKeyCode && now.timeIntervalSince(lastKeyTime) < 0.15 {
            lastKeyTime = now
            return
        }
        lastKeyCode = key.keyCode
        lastKeyTime = now

        lastKeyPress = now
        switch key.keyCode {
        case kShiftKey:
            shiftActive.toggle(); rebuild()
        case kLayerKey:
            symbolsActive.toggle(); shiftActive = false; rebuild()
        case kHideKey:
            manuallyHidden = true
            pinned = false
            hide()
        default:
            var shift = shiftActive && key.usesShiftFlag
            if symbolsActive && symbolsShiftedRows.contains(row) && key.usesShiftFlag { shift = true }
            postKey(key.keyCode, shift: shift)
            if shiftActive { shiftActive = false; rebuild() } // one-shot shift
        }
    }

    func show(on screen: NSScreen) {
        if panel.isVisible { return }
        if panel.frame.origin == .zero || !screen.visibleFrame.intersects(panel.frame) {
            let f = screen.visibleFrame
            let x = f.midX - panel.frame.width / 2
            let y = f.minY + 12
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { self.panel.orderOut(nil) })
    }
}

// MARK: - Focus watcher

final class FocusWatcher {
    private let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXSearchField", "AXComboBox"]
    private var missCount = 0
    let keyboard: KeyboardController
    private var ownPID = ProcessInfo.processInfo.processIdentifier
    private var lastFrontPID: pid_t = -1

    init(keyboard: KeyboardController) { self.keyboard = keyboard }

    func start() {
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.poll() }
    }

    private func poll() {
        // Chromium/Electron apps build their accessibility tree only after an assistive
        // client announces itself — without this, their text fields are invisible to us.
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != lastFrontPID {
            lastFrontPID = front.processIdentifier
            let appEl = AXUIElementCreateApplication(front.processIdentifier)
            AXUIElementSetAttributeValue(appEl, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        }
        if keyboard.pinned {
            keyboard.show(on: NSScreen.main ?? NSScreen.screens[0])
            return
        }
        let (isText, frame) = focusedTextElement()
        if isText {
            missCount = 0
            if !keyboard.manuallyHidden {
                keyboard.show(on: screenFor(frame: frame))
            }
        } else {
            // never hide mid-typing: some apps report focus erratically between keystrokes
            if Date().timeIntervalSince(keyboard.lastKeyPress) < 1.0 { return }
            missCount += 1
            if missCount >= 2 {           // ~0.5 s debounce
                keyboard.manuallyHidden = false
                keyboard.hide()
            }
        }
    }

    private func focusedTextElement() -> (Bool, CGRect?) {
        let sys = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(sys, kAXFocusedUIElementAttribute as CFString, &focusedRef)
        if result != .success, lastFrontPID > 0 {
            let appEl = AXUIElementCreateApplication(lastFrontPID)
            result = AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &focusedRef)
        }
        guard result == .success,
              let f = focusedRef, CFGetTypeID(f) == AXUIElementGetTypeID() else { return (false, nil) }
        let el = f as! AXUIElement

        var pid: pid_t = 0
        AXUIElementGetPid(el, &pid)
        if pid == ownPID { return (true, nil) }  // taps on our own panel: keep showing

        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &roleRef) == .success,
              let role = roleRef as? String else { return (false, nil) }
        var isText = textRoles.contains(role)
        if !isText && role != "AXStaticText" && role != "AXWindow" && role != "AXApplication" && role != "AXWebArea" {
            // editable text in web views / custom editors exposes a selected-text range
            var names: CFArray?
            if AXUIElementCopyAttributeNames(el, &names) == .success,
               let attrs = names as? [String], attrs.contains("AXSelectedTextRange") {
                isText = true
            }
        }
        guard isText else { return (false, nil) }

        var frame: CGRect? = nil
        var posRef: CFTypeRef?; var sizeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posRef) == .success,
           AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeRef) == .success {
            var p = CGPoint.zero; var s = CGSize.zero
            AXValueGetValue(posRef as! AXValue, .cgPoint, &p)
            AXValueGetValue(sizeRef as! AXValue, .cgSize, &s)
            frame = CGRect(origin: p, size: s)
        }
        return (true, frame)
    }

    private func screenFor(frame: CGRect?) -> NSScreen {
        guard let f = frame, let main = NSScreen.main else { return NSScreen.main ?? NSScreen.screens[0] }
        // AX coordinates are top-left origin; convert y to AppKit's bottom-left
        let totalH = NSScreen.screens.map { $0.frame.maxY }.max() ?? main.frame.maxY
        let mid = CGPoint(x: f.midX, y: totalH - f.midY)
        for s in NSScreen.screens where s.frame.contains(mid) { return s }
        return main
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    var keyboard: KeyboardController!
    var watcher: FocusWatcher!
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)

        // posting keyboard events is gated separately from Accessibility
        if !CGPreflightPostEventAccess() {
            _ = CGRequestPostEventAccess()
        }

        keyboard = KeyboardController()
        watcher = FocusWatcher(keyboard: keyboard)
        watcher.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "⌨"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Keep Keyboard Shown", action: #selector(showKb), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Hide Keyboard (auto mode)", action: #selector(hideKb), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit TouchKeys", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc func showKb() {
        keyboard.manuallyHidden = false
        keyboard.pinned = true
        keyboard.show(on: NSScreen.main ?? NSScreen.screens[0])
    }
    @objc func hideKb() {
        keyboard.manuallyHidden = true
        keyboard.pinned = false
        keyboard.hide()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
