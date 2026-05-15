import AppKit

final class PressureView: NSView {
    private var lastPoint: NSPoint?
    private var eventCount = 0
    private var maxPressure: Float = 0
    private var startTime: TimeInterval?
    private var strokes: [(NSPoint, NSPoint, CGFloat)] = []

    private let status = NSTextField(labelWithString: "等待影拓笔进入窗口")
    private let pressure = NSTextField(labelWithString: "pressure: -")
    private let maxPressureLabel = NSTextField(labelWithString: "max pressure: 0")
    private let location = NSTextField(labelWithString: "location: -")
    private let tilt = NSTextField(labelWithString: "tilt: -")
    private let subtype = NSTextField(labelWithString: "subtype: -")
    private let eventType = NSTextField(labelWithString: "event: -")
    private let count = NSTextField(labelWithString: "events: 0")
    private let rate = NSTextField(labelWithString: "rate: -")
    private let clearButton = NSButton(title: "清空", target: nil, action: nil)

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        setupOverlay()
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupOverlay() {
        let panel = NSStackView()
        panel.orientation = .vertical
        panel.alignment = .leading
        panel.spacing = 6
        panel.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92).cgColor
        panel.layer?.cornerRadius = 8
        panel.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Wacom Native Pressure Test")
        title.font = .boldSystemFont(ofSize: 15)

        for label in [status, pressure, maxPressureLabel, location, tilt, subtype, eventType, count, rate] {
            label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        }

        clearButton.target = self
        clearButton.action = #selector(clearCanvas)

        [title, status, pressure, maxPressureLabel, location, tilt, subtype, eventType, count, rate, clearButton].forEach {
            panel.addArrangedSubview($0)
        }

        addSubview(panel)
        NSLayoutConstraint.activate([
            panel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            panel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            panel.widthAnchor.constraint(equalToConstant: 300)
        ])
    }

    @objc private func clearCanvas() {
        strokes.removeAll()
        eventCount = 0
        maxPressure = 0
        startTime = nil
        lastPoint = nil
        updateLabels(event: nil, pressureValue: 0)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        dirtyRect.fill()

        NSColor.black.setStroke()
        for stroke in strokes {
            let path = NSBezierPath()
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.lineWidth = stroke.2
            path.move(to: stroke.0)
            path.line(to: stroke.1)
            path.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        lastPoint = convert(event.locationInWindow, from: nil)
        handle(event, shouldDraw: true)
    }

    override func mouseDragged(with event: NSEvent) {
        handle(event, shouldDraw: true)
    }

    override func mouseUp(with event: NSEvent) {
        handle(event, shouldDraw: false)
        lastPoint = nil
    }

    override func mouseMoved(with event: NSEvent) {
        handle(event, shouldDraw: false)
    }

    override func tabletPoint(with event: NSEvent) {
        handle(event, shouldDraw: event.pressure > 0)
    }

    override func tabletProximity(with event: NSEvent) {
        handle(event, shouldDraw: false)
    }

    private func handle(_ event: NSEvent, shouldDraw: Bool) {
        let point = convert(event.locationInWindow, from: nil)
        let pressureValue = event.pressure

        if shouldDraw, let last = lastPoint {
            let width = CGFloat(max(0.02, pressureValue)) * 28 + 1
            strokes.append((last, point, width))
            needsDisplay = true
        }

        lastPoint = point
        updateLabels(event: event, pressureValue: pressureValue)
    }

    private func updateLabels(event: NSEvent?, pressureValue: Float) {
        let now = Date.timeIntervalSinceReferenceDate
        if startTime == nil { startTime = now }
        eventCount += event == nil ? 0 : 1
        maxPressure = max(maxPressure, pressureValue)

        if let event {
            let point = convert(event.locationInWindow, from: nil)
            status.stringValue = pressureValue > 0 ? "状态: 接触/按下" : "状态: 悬停或移动"
            pressure.stringValue = String(format: "pressure: %.4f", pressureValue)
            maxPressureLabel.stringValue = String(format: "max pressure: %.4f", maxPressure)
            location.stringValue = String(format: "location: %.1f, %.1f", point.x, point.y)
            tilt.stringValue = String(format: "tilt: %.3f, %.3f", event.tilt.x, event.tilt.y)
            subtype.stringValue = "subtype: \(event.subtype.rawValue)"
            eventType.stringValue = "event: \(event.type.rawValue)"
        } else {
            status.stringValue = "等待影拓笔进入窗口"
            pressure.stringValue = "pressure: -"
            maxPressureLabel.stringValue = "max pressure: 0"
            location.stringValue = "location: -"
            tilt.stringValue = "tilt: -"
            subtype.stringValue = "subtype: -"
            eventType.stringValue = "event: -"
        }

        count.stringValue = "events: \(eventCount)"
        if let startTime {
            let elapsed = max(0.001, now - startTime)
            rate.stringValue = String(format: "rate: %.1f events/s", Double(eventCount) / elapsed)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let view = PressureView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        let window = NSWindow(
            contentRect: view.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Wacom Native Pressure Test"
        window.center()
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
