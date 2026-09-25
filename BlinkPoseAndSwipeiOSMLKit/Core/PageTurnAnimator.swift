import PDFKit
import UIKit

enum PageTransitionStyle: String, CaseIterable {
    case curl, slide, none

    private static let key = "PageTransition.style"

    static var current: PageTransitionStyle {
        get { UserDefaults.standard.string(forKey: key).flatMap(PageTransitionStyle.init(rawValue:)) ?? .curl }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    var title: String {
        switch self {
        case .curl: return "Curl".localized
        case .slide: return "Slide".localized
        case .none: return "None".localized
        }
    }
}

enum PageTransitionAxis: String, CaseIterable {
    case horizontal, vertical

    private static let key = "PageTransition.axis"

    static var current: PageTransitionAxis {
        get { UserDefaults.standard.string(forKey: key).flatMap(PageTransitionAxis.init(rawValue:)) ?? .horizontal }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    var title: String {
        switch self {
        case .horizontal: return "Sideways".localized
        case .vertical: return "Up & Down".localized
        }
    }
}

enum PageTransitionSpeed {
    static let range: ClosedRange<Float> = 0.15...1.0
    private static let key = "PageTransition.duration"

    /// Seconds a full page turn takes.
    static var duration: TimeInterval {
        get { UserDefaults.standard.object(forKey: key) == nil ? 0.45 : UserDefaults.standard.double(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// Animates page changes on a PDFView. The pages are rendered to images
// directly (instead of snapshotting the PDFView, which draws lazily and can
// show blank pages mid-animation), so the old and new page are always exact.
final class PageTurnAnimator {
    private struct Snapshot {
        let image: UIImage
        let frame: CGRect
    }

    private weak var pdfView: PDFView?
    private var overlay: UIView?
    private var duration: TimeInterval = 0.45
    private var vertical = false

    init(pdfView: PDFView) {
        self.pdfView = pdfView
    }

    /// Runs `change` (which must move the PDFView to another page) and animates
    /// the transition. `forward` decides the direction of the animation.
    func turn(forward: Bool, style: PageTransitionStyle = .current, change: () -> Void) {
        finishCurrentAnimation()
        duration = PageTransitionSpeed.duration
        vertical = PageTransitionAxis.current == .vertical

        guard style != .none,
              !UIAccessibility.isReduceMotionEnabled,
              let pdfView, let container = pdfView.superview,
              let oldPage = pdfView.currentPage,
              let old = snapshot(of: oldPage, in: pdfView) else {
            change()
            return
        }

        change()
        pdfView.layoutIfNeeded()

        // Nothing moved (e.g. already on the last page): no animation.
        guard let newPage = pdfView.currentPage, newPage !== oldPage,
              let new = snapshot(of: newPage, in: pdfView) else { return }

        let overlay = UIView(frame: pdfView.frame)
        overlay.isUserInteractionEnabled = false
        overlay.clipsToBounds = true
        var perspective = CATransform3DIdentity
        perspective.m34 = -1.0 / 900
        overlay.layer.sublayerTransform = perspective
        container.insertSubview(overlay, aboveSubview: pdfView)
        self.overlay = overlay

        let finish: (Bool) -> Void = { [weak self, weak overlay] _ in
            overlay?.removeFromSuperview()
            if self?.overlay === overlay { self?.overlay = nil }
        }

        switch style {
        case .curl: animateCurl(in: overlay, old: old, new: new, forward: forward, completion: finish)
        case .slide: animateSlide(in: overlay, old: old, new: new, forward: forward, completion: finish)
        case .none: break
        }
    }

    // MARK: - Styles

    // A page hinged on its left (or, vertically, top) edge swings away (forward) or back in (backward).
    private func animateCurl(in overlay: UIView, old: Snapshot, new: Snapshot, forward: Bool, completion: @escaping (Bool) -> Void) {
        let swinging = forward ? old : new
        let flap = makeHingedPage(swinging)

        if !forward {
            // The page being turned back to lands on top of the page it replaces.
            overlay.addSubview(makePageView(old))
        }
        overlay.addSubview(flap.view)

        let open = vertical ? CATransform3DMakeRotation(.pi / 2, 1, 0, 0) : CATransform3DMakeRotation(-.pi / 2, 0, 1, 0)
        if forward {
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseIn], animations: {
                flap.view.layer.transform = open
                flap.shade.alpha = 0.55
            }, completion: completion)
        } else {
            flap.view.layer.transform = open
            flap.shade.alpha = 0.55
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut], animations: {
                flap.view.layer.transform = CATransform3DIdentity
                flap.shade.alpha = 0
            }, completion: completion)
        }
    }

    private func animateSlide(in overlay: UIView, old: Snapshot, new: Snapshot, forward: Bool, completion: @escaping (Bool) -> Void) {
        let vertical = self.vertical
        let travel = vertical ? overlay.bounds.height : overlay.bounds.width
        if forward {
            let page = makePageView(old)
            overlay.addSubview(page)
            UIView.animate(withDuration: duration * 0.8, delay: 0, options: [.curveEaseInOut], animations: {
                page.transform = (vertical ? CGAffineTransform(translationX: 0, y: -travel) : CGAffineTransform(translationX: -travel, y: 0))
            }, completion: completion)
        } else {
            overlay.addSubview(makePageView(old))
            let page = makePageView(new)
            page.transform = (vertical ? CGAffineTransform(translationX: 0, y: -travel) : CGAffineTransform(translationX: -travel, y: 0))
            overlay.addSubview(page)
            UIView.animate(withDuration: duration * 0.8, delay: 0, options: [.curveEaseInOut], animations: {
                page.transform = .identity
            }, completion: completion)
        }
    }

    // MARK: - Helpers

    private func finishCurrentAnimation() {
        overlay?.subviews.forEach { $0.layer.removeAllAnimations() }
        overlay?.removeFromSuperview()
        overlay = nil
    }

    private func makePageView(_ snapshot: Snapshot) -> UIImageView {
        let view = UIImageView(image: snapshot.image)
        view.frame = snapshot.frame
        return view
    }

    private func makeHingedPage(_ snapshot: Snapshot) -> (view: UIImageView, shade: UIView) {
        let view = UIImageView(image: snapshot.image)
        view.layer.anchorPoint = vertical ? CGPoint(x: 0.5, y: 0) : CGPoint(x: 0, y: 0.5)   // hinge on the spine
        view.frame = snapshot.frame                        // set after the anchor so it stays in place
        let shade = UIView(frame: view.bounds)
        shade.backgroundColor = .black
        shade.alpha = 0
        view.addSubview(shade)
        return (view, shade)
    }

    private func snapshot(of page: PDFPage, in pdfView: PDFView) -> Snapshot? {
        let box = pdfView.displayBox
        let bounds = page.bounds(for: box)
        let frame = pdfView.convert(bounds, from: page)
        guard frame.width > 1, frame.height > 1, bounds.width > 0, bounds.height > 0 else { return nil }

        let image = UIGraphicsImageRenderer(size: frame.size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: frame.size))
            let cg = context.cgContext
            cg.translateBy(x: 0, y: frame.height)
            cg.scaleBy(x: frame.width / bounds.width, y: -frame.height / bounds.height)
            cg.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
            page.draw(with: box, to: cg)
        }
        return Snapshot(image: image, frame: frame)
    }
}
