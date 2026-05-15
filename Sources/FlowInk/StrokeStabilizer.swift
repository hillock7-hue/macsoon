import CoreGraphics

final class StrokeStabilizer {
    private var previousOutput: CanvasInputSample?
    private var previousRaw: CanvasInputSample?

    func reset() {
        previousOutput = nil
        previousRaw = nil
    }

    func begin(with sample: CanvasInputSample) -> CanvasInputSample {
        previousOutput = sample
        previousRaw = sample
        return sample
    }

    func smooth(_ raw: CanvasInputSample, settings: BrushSettings) -> CanvasInputSample {
        guard let previousOutput, let previousRaw else {
            return begin(with: raw)
        }

        let speed = raw.location.distance(to: previousRaw.location) / CGFloat(max(0.001, raw.timestamp - previousRaw.timestamp))
        let speedFactor = min(1, speed / 2200)
        let baseStabilization = min(0.92, max(0, settings.stabilization))

        // Faster strokes get more path cleanup; slower detail work keeps more of the hand.
        let adaptiveStabilization = min(0.94, baseStabilization * (0.55 + speedFactor * 0.75))
        let response = 1 - adaptiveStabilization
        let alpha = min(0.82, max(0.16, response + (1 - speedFactor) * 0.22))

        let smoothedLocation = previousOutput.location.lerp(to: raw.location, alpha: alpha)
        let pressureAlpha = settings.naturalCorrection == .off ? 1 : CGFloat(0.42 + (1 - speedFactor) * 0.24)
        let smoothedPressure = CGFloat(previousOutput.pressure).lerp(to: CGFloat(raw.pressure), alpha: pressureAlpha)

        let corrected = raw.replacing(
            location: smoothedLocation,
            pressure: Float(min(1, max(0, smoothedPressure)))
        )
        self.previousOutput = corrected
        self.previousRaw = raw
        return corrected
    }
}

private extension CanvasInputSample {
    func replacing(location: CGPoint, pressure: Float) -> CanvasInputSample {
        CanvasInputSample(
            location: location,
            pressure: pressure,
            tilt: tilt,
            buttons: buttons,
            timestamp: timestamp,
            deviceKind: deviceKind,
            pressureSource: pressureSource
        )
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }

    func lerp(to other: CGPoint, alpha: CGFloat) -> CGPoint {
        CGPoint(
            x: x + (other.x - x) * alpha,
            y: y + (other.y - y) * alpha
        )
    }
}

private extension CGFloat {
    func lerp(to other: CGFloat, alpha: CGFloat) -> CGFloat {
        self + (other - self) * alpha
    }
}
