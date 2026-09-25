import PDFKit
import UIKit

protocol AnnotationOverlayDelegate: AnyObject {
    func annotationOverlay(_ overlay: AnnotationOverlayView, didFinishStroke points: [CGPoint], tool: AnnotationTool, color: UIColor, on page: PDFPage)
    func annotationOverlay(_ overlay: AnnotationOverlayView, didTapToPlaceTextAt point: CGPoint, on page: PDFPage)
    func annotationOverlay(_ overlay: AnnotationOverlayView, didTapToEraseAt point: CGPoint, on page: PDFPage)
}

// Sits on top of the PDFView, only accepting touches while annotation mode
// is active (isUserInteractionEnabled toggled by the owning view controller).
// Touch points are collected in this view's own coordinate space — since it
// is pinned to the exact same frame as the PDFView, that space is identical
// to the PDFView's, and the delegate converts to page space via
// PDFView.convert(_:to:) when committing an annotation.
final class AnnotationOverlayView: UIView {
    weak var delegate: AnnotationOverlayDelegate?
    weak var pdfView: PDFView?

    var tool: AnnotationTool = .pen
    var color: UIColor = .systemRed

    private var currentPoints: [CGPoint] = []
    private let previewLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        previewLayer.fillColor = nil
        previewLayer.lineCap = .round
        previewLayer.lineJoin = .round
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        switch tool {
        case .pen, .highlighter:
            currentPoints = [point]
            updatePreview()
        case .eraser:
            eraseIfPossible(at: point)
        case .text:
            break
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        switch tool {
        case .pen, .highlighter:
            currentPoints.append(point)
            updatePreview()
        case .eraser:
            eraseIfPossible(at: point)
        case .text:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let pdfView, let page = pdfView.page(for: touch.location(in: self), nearest: true) else {
            clearStroke()
            return
        }

        switch tool {
        case .pen, .highlighter:
            let points = currentPoints
            clearStroke()
            guard points.count > 1 else { return }
            delegate?.annotationOverlay(self, didFinishStroke: points, tool: tool, color: color, on: page)
        case .text:
            delegate?.annotationOverlay(self, didTapToPlaceTextAt: touch.location(in: self), on: page)
        case .eraser:
            eraseIfPossible(at: touch.location(in: self))
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        clearStroke()
    }

    private func eraseIfPossible(at point: CGPoint) {
        guard let pdfView, let page = pdfView.page(for: point, nearest: true) else { return }
        delegate?.annotationOverlay(self, didTapToEraseAt: point, on: page)
    }

    private func clearStroke() {
        currentPoints = []
        previewLayer.path = nil
    }

    private func updatePreview() {
        let path = UIBezierPath()
        if let first = currentPoints.first {
            path.move(to: first)
            for point in currentPoints.dropFirst() {
                path.addLine(to: point)
            }
        }
        previewLayer.path = path.cgPath
        previewLayer.strokeColor = tool == .highlighter ? color.withAlphaComponent(0.4).cgColor : color.cgColor
        previewLayer.lineWidth = tool == .highlighter ? 16 : 3
    }
}
