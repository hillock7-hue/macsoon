import AppKit
import MetalKit

final class CanvasView: MTKView {
    var onSample: ((CanvasInputSample) -> Void)?

    private let input = InputInterpreter()
    private let brush = BrushSettings()
    private var renderer: CanvasRenderer!
    private var isDrawing = false
    private var previousSample: CanvasInputSample?

    override var acceptsFirstResponder: Bool { true }

    init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("This Mac does not support Metal.")
        }

        super.init(frame: .zero, device: device)
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true
        isPaused = false
        enableSetNeedsDisplay = false
        preferredFramesPerSecond = 120
        renderer = CanvasRenderer(view: self)
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        ))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func clearCanvas() {
        renderer.clear()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        beginStroke(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        continueStroke(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        endStroke(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        beginStroke(with: event)
    }

    override func rightMouseDragged(with event: NSEvent) {
        continueStroke(with: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        endStroke(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        let sample = input.sample(from: event, in: self, isDrawing: false)
        onSample?(sample)
    }

    override func tabletPoint(with event: NSEvent) {
        if event.pressure > 0 {
            if isDrawing {
                continueStroke(with: event)
            } else {
                beginStroke(with: event)
            }
        } else if isDrawing {
            endStroke(with: event)
        } else {
            let sample = input.sample(from: event, in: self, isDrawing: false)
            onSample?(sample)
        }
    }

    override func tabletProximity(with event: NSEvent) {
        let sample = input.sample(from: event, in: self, isDrawing: false)
        onSample?(sample)
    }

    private func beginStroke(with event: NSEvent) {
        input.reset()
        isDrawing = true
        let sample = input.sample(from: event, in: self, isDrawing: true)
        previousSample = sample
        onSample?(sample)
    }

    private func continueStroke(with event: NSEvent) {
        let sample = input.sample(from: event, in: self, isDrawing: true)
        if let previousSample {
            renderer.addSegment(from: previousSample, to: sample, brush: brush)
        }
        self.previousSample = sample
        onSample?(sample)
    }

    private func endStroke(with event: NSEvent) {
        let sample = input.sample(from: event, in: self, isDrawing: false)
        isDrawing = false
        previousSample = nil
        input.reset()
        onSample?(sample)
    }
}
