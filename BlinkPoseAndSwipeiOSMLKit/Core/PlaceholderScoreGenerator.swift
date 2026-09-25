import UIKit

// Draws a copyright-free placeholder PDF for demoing page-turning — plain
// staff-line decoration and a page number, not real notation. Used wherever
// the app previously loaded a bundled sample PDF.
enum PlaceholderScoreGenerator {
    static func generate(title: String = "Sample Score".localized, pageCount: Int = 6) -> Data {
        let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 at 72dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        return renderer.pdfData { context in
            for pageIndex in 0..<pageCount {
                context.beginPage()
                draw(pageIndex: pageIndex, title: title, in: pageBounds)
            }
        }
    }

    private static func draw(pageIndex: Int, title: String, in bounds: CGRect) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black,
        ]
        (title as NSString).draw(at: CGPoint(x: 48, y: 48), withAttributes: titleAttributes)

        let pageLabelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.darkGray,
        ]
        ("Page %d".localized(pageIndex + 1) as NSString).draw(at: CGPoint(x: 48, y: 84), withAttributes: pageLabelAttributes)

        guard let path = UIGraphicsGetCurrentContext() else { return }
        path.setStrokeColor(UIColor.black.cgColor)
        path.setLineWidth(1)

        let staffLeft: CGFloat = 48
        let staffRight: CGFloat = bounds.width - 48
        var y: CGFloat = 140

        for _ in 0..<8 {
            for lineIndex in 0..<5 {
                let lineY = y + CGFloat(lineIndex) * 8
                path.move(to: CGPoint(x: staffLeft, y: lineY))
                path.addLine(to: CGPoint(x: staffRight, y: lineY))
            }
            y += 70
        }
        path.strokePath()
    }
}
