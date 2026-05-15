import AppKit

enum InputDeviceKind: String {
    case mouse
    case tablet
    case eraser
    case unknown
}

enum PressureSource: String {
    case hardware
    case simulated
    case none
}

struct CanvasInputSample {
    let location: CGPoint
    let pressure: Float
    let tilt: CGVector
    let buttons: Int
    let timestamp: TimeInterval
    let deviceKind: InputDeviceKind
    let pressureSource: PressureSource
}

final class InputInterpreter {
    private var previousLocation: CGPoint?
    private var previousTimestamp: TimeInterval?

    func reset() {
        previousLocation = nil
        previousTimestamp = nil
    }

    func sample(from event: NSEvent, in view: NSView, isDrawing: Bool) -> CanvasInputSample {
        let location = view.convert(event.locationInWindow, from: nil)
        let hardwarePressure = event.pressure
        let pressureSource: PressureSource
        let pressure: Float

        if hardwarePressure > 0.001 && hardwarePressure < 0.999 {
            pressure = hardwarePressure
            pressureSource = .hardware
        } else if isDrawing {
            pressure = simulatedPressure(location: location, timestamp: event.timestamp)
            pressureSource = .simulated
        } else {
            pressure = 0
            pressureSource = .none
        }

        let sample = CanvasInputSample(
            location: location,
            pressure: max(0, min(1, pressure)),
            tilt: CGVector(dx: Double(event.tilt.x), dy: Double(event.tilt.y)),
            buttons: Int(event.buttonMask.rawValue),
            timestamp: event.timestamp,
            deviceKind: deviceKind(for: event),
            pressureSource: pressureSource
        )

        previousLocation = location
        previousTimestamp = event.timestamp
        return sample
    }

    private func deviceKind(for event: NSEvent) -> InputDeviceKind {
        switch event.subtype {
        case .tabletPoint:
            return .tablet
        case .tabletProximity:
            return event.pointingDeviceType == .eraser ? .eraser : .tablet
        default:
            return .mouse
        }
    }

    private func simulatedPressure(location: CGPoint, timestamp: TimeInterval) -> Float {
        guard let previousLocation, let previousTimestamp else {
            return 0.35
        }

        let dx = location.x - previousLocation.x
        let dy = location.y - previousLocation.y
        let distance = sqrt(dx * dx + dy * dy)
        let dt = max(0.001, timestamp - previousTimestamp)
        let speed = distance / dt

        // A calm default for mouse/trackpad development: faster strokes taper a little,
        // slower strokes become fuller. Real tablet pressure replaces this path.
        let normalizedSpeed = min(1, speed / 1800)
        return Float(0.62 - normalizedSpeed * 0.28)
    }
}
