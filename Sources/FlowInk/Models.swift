import AppKit

final class BrushSettings {
    var minimumSize: CGFloat = 2
    var maximumSize: CGFloat = 24
    var minimumOpacity: CGFloat = 0.35
    var maximumOpacity: CGFloat = 0.95
    var stabilization: CGFloat = 0.42
    var naturalCorrection: NaturalCorrection = .light
    var color: NSColor = .black
}

enum NaturalCorrection: String {
    case off
    case light
    case standard
}
