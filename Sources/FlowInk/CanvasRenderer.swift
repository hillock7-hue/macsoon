import AppKit
import Metal
import MetalKit

private struct StrokeVertex {
    var position: SIMD2<Float>
    var color: SIMD4<Float>
}

final class CanvasRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private var vertices: [StrokeVertex] = []
    private var viewportSize: CGSize = .zero
    private let clearColor = MTLClearColor(red: 0.96, green: 0.955, blue: 0.94, alpha: 1)

    init(view: MTKView) {
        guard
            let device = view.device,
            let commandQueue = device.makeCommandQueue()
        else {
            fatalError("Metal is not available on this Mac.")
        }

        self.device = device
        self.commandQueue = commandQueue

        do {
            let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
            guard
                let vertexFunction = library.makeFunction(name: "stroke_vertex"),
                let fragmentFunction = library.makeFunction(name: "stroke_fragment")
            else {
                fatalError("Failed to load Metal shader functions.")
            }

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].rgbBlendOperation = .add
            descriptor.colorAttachments[0].alphaBlendOperation = .add
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to create Metal pipeline: \(error)")
        }

        super.init()
        view.clearColor = clearColor
        view.delegate = self
    }

    func clear() {
        vertices.removeAll(keepingCapacity: true)
    }

    func addSegment(from start: CanvasInputSample, to end: CanvasInputSample, brush: BrushSettings) {
        guard viewportSize.width > 1, viewportSize.height > 1 else { return }

        let pressure = max(0.02, CGFloat(end.pressure))
        let width = brush.minimumSize + (brush.maximumSize - brush.minimumSize) * pressure
        let alpha = brush.minimumOpacity + (brush.maximumOpacity - brush.minimumOpacity) * pressure

        let dx = end.location.x - start.location.x
        let dy = end.location.y - start.location.y
        let length = max(0.001, sqrt(dx * dx + dy * dy))
        let nx = -dy / length
        let ny = dx / length
        let halfWidth = width * 0.5

        let p0 = CGPoint(x: start.location.x + nx * halfWidth, y: start.location.y + ny * halfWidth)
        let p1 = CGPoint(x: start.location.x - nx * halfWidth, y: start.location.y - ny * halfWidth)
        let p2 = CGPoint(x: end.location.x + nx * halfWidth, y: end.location.y + ny * halfWidth)
        let p3 = CGPoint(x: end.location.x - nx * halfWidth, y: end.location.y - ny * halfWidth)

        let color = SIMD4<Float>(
            Float(brush.color.redComponent),
            Float(brush.color.greenComponent),
            Float(brush.color.blueComponent),
            Float(alpha)
        )

        appendTriangle(p0, p1, p2, color: color)
        appendTriangle(p2, p1, p3, color: color)
    }

    private func appendTriangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, color: SIMD4<Float>) {
        vertices.append(StrokeVertex(position: ndc(a), color: color))
        vertices.append(StrokeVertex(position: ndc(b), color: color))
        vertices.append(StrokeVertex(position: ndc(c), color: color))
    }

    private func ndc(_ point: CGPoint) -> SIMD2<Float> {
        let x = Float(point.x / viewportSize.width * 2 - 1)
        let y = Float(point.y / viewportSize.height * 2 - 1)
        return SIMD2<Float>(x, y)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = view.bounds.size
    }

    func draw(in view: MTKView) {
        viewportSize = view.bounds.size

        guard
            let descriptor = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else {
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        if !vertices.isEmpty {
            encoder.setVertexBytes(vertices, length: MemoryLayout<StrokeVertex>.stride * vertices.count, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        }
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct StrokeVertex {
        float2 position;
        float4 color;
    };

    struct VertexOut {
        float4 position [[position]];
        float4 color;
    };

    vertex VertexOut stroke_vertex(const device StrokeVertex *vertices [[buffer(0)]],
                                   uint vertexID [[vertex_id]]) {
        VertexOut out;
        out.position = float4(vertices[vertexID].position, 0.0, 1.0);
        out.color = vertices[vertexID].color;
        return out;
    }

    fragment float4 stroke_fragment(VertexOut in [[stage_in]]) {
        return in.color;
    }
    """
}
