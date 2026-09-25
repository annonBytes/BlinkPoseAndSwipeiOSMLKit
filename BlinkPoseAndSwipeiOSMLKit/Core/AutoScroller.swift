import PDFKit
import UIKit

// Continuous vertical scrolling of a score at an adjustable speed, for
// pieces (or players) that prefer a steady scroll to discrete page turns.
// While active the PDFView is switched to continuous vertical layout; on stop
// the single-page layout is restored.
final class AutoScroller {
    static let speedRange: ClosedRange<Double> = 10...160
    private static let speedKey = "AutoScroll.speed"

    /// Points per second.
    static var speed: Double {
        get { UserDefaults.standard.object(forKey: speedKey) == nil ? 45 : UserDefaults.standard.double(forKey: speedKey) }
        set { UserDefaults.standard.set(min(max(newValue, speedRange.lowerBound), speedRange.upperBound), forKey: speedKey) }
    }

    var onFinished: (() -> Void)?
    private(set) var isRunning = false

    private weak var pdfView: PDFView?
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var offsetY: CGFloat = 0

    init(pdfView: PDFView) {
        self.pdfView = pdfView
    }

    deinit { link?.invalidate() }

    func start() {
        guard let pdfView, !isRunning else { return }
        let page = pdfView.currentPage
        pdfView.displayDirection = .vertical
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        if let page { pdfView.go(to: page) }
        pdfView.layoutIfNeeded()

        isRunning = true
        offsetY = scrollView?.contentOffset.y ?? 0
        lastTimestamp = 0
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func stop(restoreLayout: Bool = true) {
        guard isRunning else { return }
        isRunning = false
        link?.invalidate()
        link = nil
        guard let pdfView, restoreLayout else { return }
        let page = pdfView.currentPage
        pdfView.displayDirection = .horizontal
        pdfView.displayMode = .singlePage
        pdfView.autoScales = true
        if let page { pdfView.go(to: page) }
    }

    @objc private func step(_ link: CADisplayLink) {
        guard let scrollView else { return }
        defer { lastTimestamp = link.timestamp }
        guard lastTimestamp > 0 else { return }

        // Track manual drags: if the user moved the score, continue from there.
        if abs(scrollView.contentOffset.y - offsetY) > 2 { offsetY = scrollView.contentOffset.y }

        let maxY = scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        offsetY += CGFloat(Self.speed * (link.timestamp - lastTimestamp))
        if offsetY >= maxY {
            scrollView.contentOffset.y = maxY
            stop(restoreLayout: false)
            onFinished?()
            return
        }
        scrollView.contentOffset.y = offsetY
    }

    // PDFView hosts its own scroll view; find the one holding the pages.
    private var scrollView: UIScrollView? {
        func search(_ view: UIView) -> UIScrollView? {
            if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height { return scroll }
            for sub in view.subviews { if let found = search(sub) { return found } }
            return nil
        }
        return pdfView.flatMap(search)
    }
}
