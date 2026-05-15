import AppKit

final class MainWorkspaceView: NSView {
    private let canvasView = CanvasView()
    private let pressureLabel = NSTextField(labelWithString: "pressure: -")
    private let sourceLabel = NSTextField(labelWithString: "source: -")
    private let deviceLabel = NSTextField(labelWithString: "device: -")
    private let positionLabel = NSTextField(labelWithString: "position: -")
    private let tiltLabel = NSTextField(labelWithString: "tilt: -")
    private let stabilizerLabel = NSTextField(labelWithString: "stabilizer: light")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        canvasView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(canvasView)

        let panel = NSStackView()
        panel.orientation = .vertical
        panel.alignment = .leading
        panel.spacing = 6
        panel.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92).cgColor
        panel.layer?.cornerRadius = 8

        let title = NSTextField(labelWithString: "FlowInk 1.0 Prototype")
        title.font = .boldSystemFont(ofSize: 14)

        for label in [pressureLabel, sourceLabel, deviceLabel, positionLabel, tiltLabel, stabilizerLabel] {
            label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        }

        let clearButton = NSButton(title: "清空画布", target: self, action: #selector(clearCanvas))
        let undoButton = NSButton(title: "撤销上一笔", target: self, action: #selector(undoLastStroke))

        let note = NSTextField(wrappingLabelWithString: "当前版本使用 Metal 渲染基础笔刷；没有真实压感时会启用模拟压感，等 PTH-660 接入后切换为硬件压感。")
        note.font = .systemFont(ofSize: 12)
        note.textColor = .secondaryLabelColor

        [title, pressureLabel, sourceLabel, deviceLabel, positionLabel, tiltLabel, stabilizerLabel, undoButton, clearButton, note].forEach {
            panel.addArrangedSubview($0)
        }
        addSubview(panel)

        NSLayoutConstraint.activate([
            canvasView.leadingAnchor.constraint(equalTo: leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: trailingAnchor),
            canvasView.topAnchor.constraint(equalTo: topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: bottomAnchor),

            panel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            panel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            panel.widthAnchor.constraint(equalToConstant: 330)
        ])

        canvasView.onSample = { [weak self] sample in
            self?.updateHUD(sample)
        }
    }

    @objc private func clearCanvas() {
        canvasView.clearCanvas()
    }

    @objc private func undoLastStroke() {
        canvasView.undoLastStroke()
    }

    private func updateHUD(_ sample: CanvasInputSample) {
        pressureLabel.stringValue = String(format: "pressure: %.4f", sample.pressure)
        sourceLabel.stringValue = "source: \(sample.pressureSource.rawValue)"
        deviceLabel.stringValue = "device: \(sample.deviceKind.rawValue)"
        positionLabel.stringValue = String(format: "position: %.1f, %.1f", sample.location.x, sample.location.y)
        tiltLabel.stringValue = String(format: "tilt: %.3f, %.3f", sample.tilt.dx, sample.tilt.dy)
    }
}
