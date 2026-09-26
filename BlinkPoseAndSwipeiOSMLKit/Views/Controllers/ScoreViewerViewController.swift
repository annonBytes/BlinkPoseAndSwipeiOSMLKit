import PDFKit
import UIKit
import UniformTypeIdentifiers

// Single PDF viewer shared by every modality, replacing the six near-duplicate
// Practice/test view controllers. The gesture detector is injected and
// swappable at runtime via setModality(_:), which is what makes switching
// modalities mid-document possible.
final class ScoreViewerViewController: UIViewController, PDFViewDelegate, PDFDocumentDelegate {

    // Generated placeholder — the bundled "Lavalse_d_Amelie.pdf" turned out to
    // be a mislabeled copy of an unrelated, copyrighted worksheet (see repo
    // history), so demo content is synthesized instead of shipped as a file.
    static let demoDocumentURL: URL = {
        #if DEBUG
        if let devScore = ScoreLibrary.devSeedURLs.first { return devScore }
        #endif
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("demo-score.pdf")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? PlaceholderScoreGenerator.generate().write(to: url)
        }
        return url
    }()

    private let pdfView = PDFView()
    private let feedbackView = GestureFeedbackView()
    private let annotationOverlay = AnnotationOverlayView()
    private let documentURL: URL
    private var detector: GestureDetector
    private var currentModality: ModalityKind

    // Practice = everything available. Performance = only unobtrusive
    // modalities, fewer controls, screen kept awake, and paid auto-turn.
    private enum PlayMode { case practice, performance }
    private var playMode: PlayMode = .practice
    private var stashedModality: ModalityKind?
    private var countdownTimer: Timer?
    private var isCountingDown = false
    private let onModalityChanged: ((ModalityKind) -> Void)?

    // MIDI auto page turning — only for scores that live in the library.
    private let scoreID: UUID?
    private let library = ScoreLibrary.shared
    private lazy var midiController = MIDIPageTurnController(pdfView: pdfView)
    private lazy var followController: ScoreFollowController = {
        let controller = ScoreFollowController(currentPage: { [weak self] in self?.currentPageIndex ?? 0 })
        controller.onNavigate = { [weak self] index in
            guard let self else { return }
            self.turnPage(toIndex: index, forward: index > self.currentPageIndex)
        }
        controller.onStateChanged = { [weak self] state in self?.followStateChanged(state) }
        return controller
    }()
    private lazy var pageAnimator = PageTurnAnimator(pdfView: pdfView)
    private lazy var autoScroller: AutoScroller = {
        let scroller = AutoScroller(pdfView: pdfView)
        scroller.onFinished = { [weak self] in self?.autoScrollFinished() }
        return scroller
    }()

    /// Zero-based inclusive page range the player is repeating; a single page
    /// means "stay on this page". Turns wrap inside the range.
    private var repeatRange: ClosedRange<Int>? {
        didSet { toolsButton.menu = makeToolsMenu(); updateRepeatBadge() }
    }

    private lazy var toolsButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "ellipsis")
        config.cornerStyle = .capsule
        config.baseBackgroundColor = .secondarySystemBackground
        config.baseForegroundColor = Theme.accent
        let button = UIButton(configuration: config)
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = "Tools".localized
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }()

    private let repeatLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = Theme.accent
        label.isHidden = true
        return label
    }()

    private var currentScore: Score? {
        scoreID.flatMap { library.score(withID: $0) }
    }

    private let midiStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = Theme.accent
        label.isHidden = true
        return label
    }()

    private var lastZoomedSize = CGSize.zero

    private var currentAnnotationTool: AnnotationTool = .pen {
        didSet {
            annotationOverlay.tool = currentAnnotationTool
            updateToolButtonStates()
        }
    }

    private var currentAnnotationColor: UIColor = .systemRed {
        didSet {
            annotationOverlay.color = currentAnnotationColor
            colorButton.tintColor = currentAnnotationColor
        }
    }

    private var isAnnotating = false {
        didSet {
            annotationOverlay.isUserInteractionEnabled = isAnnotating
            annotationToolbar.isHidden = !isAnnotating
            annotateButton.tintColor = isAnnotating ? .systemBlue : nil
            if isAnnotating {
                detector.stop()
            } else {
                detector.start()
                saveAnnotations()
            }
        }
    }

    private lazy var annotateButton: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "pencil.and.outline"), style: .plain, target: self, action: #selector(toggleAnnotationMode))
        item.accessibilityLabel = "Annotate".localized
        return item
    }()

    private lazy var modalityButton: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "arrow.triangle.swap"), menu: makeModalityMenu())
        item.accessibilityLabel = "Page-Turn Modality".localized
        return item
    }()

    private lazy var settingsButton: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(showSettings))
        item.accessibilityLabel = "Settings".localized
        return item
    }()

    private lazy var colorButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "circle.fill"), for: .normal)
        button.tintColor = currentAnnotationColor
        button.addTarget(self, action: #selector(colorTapped), for: .touchUpInside)
        return button
    }()

    private lazy var toolButtons: [AnnotationTool: UIButton] = Dictionary(uniqueKeysWithValues: AnnotationTool.allCases.map { tool in
        let button = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in self?.currentAnnotationTool = tool })
        button.setImage(UIImage(systemName: tool.systemImageName), for: .normal)
        button.layer.cornerRadius = 6
        return (tool, button)
    })

    private lazy var annotationToolbar: UIStackView = {
        let arranged = AnnotationTool.allCases.map { toolButtons[$0]! } + [colorButton]
        let stack = UIStackView(arrangedSubviews: arranged)
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.spacing = 20
        stack.isHidden = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.backgroundColor = .secondarySystemBackground
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 10, left: 24, bottom: 10, right: 24)
        stack.layer.cornerRadius = 16
        stack.clipsToBounds = true
        return stack
    }()

    init(documentURL: URL, modality: ModalityKind, score: Score? = nil, onModalityChanged: ((ModalityKind) -> Void)? = nil) {
        self.scoreID = score?.id
        self.scoreTitle = score?.title ?? documentURL.deletingPathExtension().lastPathComponent
        self.documentURL = documentURL
        self.currentModality = modality
        self.detector = modality.makeDetector()
        self.onModalityChanged = onModalityChanged
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let scoreTitle: String

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
        let backButton = UIBarButtonItem(image: UIImage(systemName: "folder"), style: .plain, target: self, action: #selector(backTapped))
        backButton.accessibilityLabel = "Back".localized
        navigationItem.leftBarButtonItem = backButton
        navigationItem.rightBarButtonItems = [annotateButton, modalityButton, settingsButton]

        setUpPDFView()
        setUpFeedbackView()
        installDetector(detector)
        setUpAnnotationOverlay()
        updateToolButtonStates()
        setUpMIDI()
        setUpTools()

        NotificationCenter.default.addObserver(self, selector: #selector(updatePageTitle), name: .PDFViewPageChanged, object: pdfView)
        updatePageTitle()
    }

    @objc private func updatePageTitle() {
        guard let document = pdfView.document, let page = pdfView.currentPage else { return }
        let pageText = "Page %d of %d".localized(document.index(for: page) + 1, document.pageCount)
        if #available(iOS 26.0, *) {
            navigationItem.title = scoreTitle
            navigationItem.subtitle = pageText
        } else {
            navigationItem.title = "\(scoreTitle) · \(pageText)"
        }
        midiController.pageChanged()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        detector.start()
        becomeFirstResponder()
        UIApplication.shared.isIdleTimerDisabled = playMode == .performance
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        detector.stop()
        cancelAutoTurn()
        autoScroller.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        saveAnnotations()
    }

    func setModality(_ newModality: ModalityKind, persist: Bool = true) {
        currentModality = newModality
        detector.stop()
        installDetector(newModality.makeDetector())
        detector.start()
        modalityButton.menu = makeModalityMenu()
        if persist { onModalityChanged?(newModality) }
    }

    private func makeModalityMenu() -> UIMenu {
        let modeSection = UIMenu(options: .displayInline, children: [
            UIAction(title: "Practice".localized, image: UIImage(systemName: "music.note"), state: playMode == .practice ? .on : .off) { [weak self] _ in
                self?.setPlayMode(.practice)
            },
            UIAction(title: "Performance".localized, image: UIImage(systemName: "theatermasks"), state: playMode == .performance ? .on : .off) { [weak self] _ in
                self?.setPlayMode(.performance)
            },
        ])
        let kinds = ModalityKind.allCases.filter { playMode == .practice || $0.isPerformanceSafe }
        let actions = kinds.map { kind in
            UIAction(title: kind.displayName, state: kind == currentModality ? .on : .off) { [weak self] _ in
                self?.setModality(kind)
            }
        }
        return UIMenu(title: "Page-Turn Modality".localized, children: [modeSection] + actions)
    }

    private func setPlayMode(_ mode: PlayMode) {
        guard mode != playMode else { return }
        playMode = mode

        if mode == .performance {
            if isAnnotating { isAnnotating = false }
            if !currentModality.isPerformanceSafe {
                stashedModality = currentModality
                setModality(.tap, persist: false)
            }
        } else {
            cancelAutoTurn()
            if let stashed = stashedModality {
                stashedModality = nil
                setModality(stashed, persist: false)
            }
        }

        navigationItem.rightBarButtonItems = mode == .performance ? [modalityButton] : [annotateButton, modalityButton, settingsButton]
        modalityButton.image = UIImage(systemName: mode == .performance ? "theatermasks.fill" : "arrow.triangle.swap")
        modalityButton.menu = makeModalityMenu()
        refreshToolsMenu()
        UIApplication.shared.isIdleTimerDisabled = mode == .performance
    }

    private func installDetector(_ newDetector: GestureDetector) {
        detector = newDetector
        feedbackView.setModality(currentModality)
        detector.attach(to: self, pageView: pdfView)
        detector.onAdvance = { [weak self] in self?.turnPage(forward: true) }
        detector.onGoBack = { [weak self] in self?.turnPage(forward: false) }
        detector.onGestureBegan = { [weak self] in self?.feedbackView.showActive() }
        detector.onGestureEnded = { [weak self] in self?.feedbackView.showIdle() }
    }

    private func turnPage(forward: Bool) {
        guard let document = pdfView.document, let current = pdfView.currentPage else { return }
        let index = document.index(for: current)

        if let range = repeatRange {
            if range.count == 1 { feedbackView.showActive(); feedbackView.showIdle(); return }   // stay put
            let target = forward ? (index >= range.upperBound ? range.lowerBound : index + 1)
                                 : (index <= range.lowerBound ? range.upperBound : index - 1)
            turnPage(toIndex: target, forward: forward)
            return
        }

        if autoScroller.isRunning {
            if forward { pdfView.goToNextPage(nil) } else { pdfView.goToPreviousPage(nil) }
            return
        }

        pageAnimator.turn(forward: forward) {
            if forward { pdfView.goToNextPage(nil) } else { pdfView.goToPreviousPage(nil) }
        }
    }

    private func turnPage(toIndex index: Int, forward: Bool) {
        guard let page = pdfView.document?.page(at: index) else { return }
        if autoScroller.isRunning { pdfView.go(to: page); return }
        pageAnimator.turn(forward: forward) { pdfView.go(to: page) }
    }

    // Used by MIDI auto-turn: jumps to a page, animating in the direction of travel.
    private func turnPage(toIndex index: Int) {
        guard let document = pdfView.document, let page = document.page(at: index), let current = pdfView.currentPage, page !== current else { return }
        pageAnimator.turn(forward: index > document.index(for: current)) { pdfView.go(to: page) }
    }

    private func setUpPDFView() {
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.displayDirection = .horizontal
        pdfView.displayMode = .singlePage
        pdfView.autoScales = true

        if let document = PDFDocument(url: documentURL) {
            pdfView.document = document
            document.delegate = self
        }

        view.addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    private func setUpFeedbackView() {
        feedbackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(feedbackView)
        NSLayoutConstraint.activate([
            feedbackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            feedbackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            feedbackView.widthAnchor.constraint(equalToConstant: 40),
            feedbackView.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    private func setUpAnnotationOverlay() {
        annotationOverlay.pdfView = pdfView
        annotationOverlay.delegate = self
        annotationOverlay.tool = currentAnnotationTool
        annotationOverlay.color = currentAnnotationColor
        annotationOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(annotationOverlay)
        NSLayoutConstraint.activate([
            annotationOverlay.leadingAnchor.constraint(equalTo: pdfView.leadingAnchor),
            annotationOverlay.trailingAnchor.constraint(equalTo: pdfView.trailingAnchor),
            annotationOverlay.topAnchor.constraint(equalTo: pdfView.topAnchor),
            annotationOverlay.bottomAnchor.constraint(equalTo: pdfView.bottomAnchor),
        ])

        view.addSubview(annotationToolbar)
        NSLayoutConstraint.activate([
            annotationToolbar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            annotationToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    private func updateToolButtonStates() {
        for (tool, button) in toolButtons {
            button.backgroundColor = tool == currentAnnotationTool ? .systemGray4 : .clear
        }
    }

    private func saveAnnotations() {
        guard let document = pdfView.document else { return }
        document.write(to: documentURL)
    }

    @objc private func backTapped() {
        navigationController?.popToRootViewController(animated: true)
    }

    @objc private func showSettings() {
        let settings = SettingsViewController(currentMethod: currentModality, onMethodChanged: { [weak self] method in
            self?.setModality(method)
        }, onTrackingChanged: { [weak self] in
            guard let self else { return }
            self.setModality(self.currentModality)
        }, onDismiss: { [weak self] in
            self?.detector.start()
        }, onWillCalibrate: { [weak self] in
            self?.detector.stop()
        })
        // The calibration screen needs the camera to itself.
        detector.stop()
        present(UINavigationController(rootViewController: settings), animated: true)
    }

    @objc private func toggleAnnotationMode() {
        isAnnotating.toggle()
    }

    @objc private func colorTapped() {
        let colors: [(String, UIColor)] = [
            ("Red".localized, .systemRed), ("Blue".localized, .systemBlue), ("Green".localized, .systemGreen),
            ("Yellow".localized, .systemYellow), ("Black".localized, .label),
        ]
        let sheet = UIAlertController(title: "Color".localized, message: nil, preferredStyle: .actionSheet)
        for (name, color) in colors {
            sheet.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in self?.currentAnnotationColor = color })
        }
        sheet.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = colorButton
            popover.sourceRect = colorButton.bounds
        }
        present(sheet, animated: true)
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesBegan(presses, with: event)
        guard let key = presses.first?.key, let handler = detector as? HardwareKeyHandling else { return }
        handler.handleKeyPress(key)
    }
}

// MARK: - MIDI auto page turning

extension ScoreViewerViewController: UIDocumentPickerDelegate {
    // MARK: - Zoom

    private static let zoomFactors: [CGFloat] = [1, 1.25, 1.5, 2, 2.5, 3]

    private func makeZoomMenu() -> UIMenu {
        let mode = ZoomSetting.current
        let fit = UIAction(title: "Fit Page".localized, image: UIImage(systemName: "arrow.up.left.and.arrow.down.right"), state: mode == .fitPage ? .on : .off) { [weak self] _ in
            self?.setZoom(.fitPage)
        }
        let width = UIAction(title: "Fit Width".localized, image: UIImage(systemName: "arrow.left.and.right"), state: mode == .fitWidth ? .on : .off) { [weak self] _ in
            self?.setZoom(.fitWidth)
        }
        let steps = UIMenu(options: .displayInline, children: [
            UIAction(title: "Zoom In".localized, image: UIImage(systemName: "plus.magnifyingglass")) { [weak self] _ in self?.stepZoom(by: 1) },
            UIAction(title: "Zoom Out".localized, image: UIImage(systemName: "minus.magnifyingglass")) { [weak self] _ in self?.stepZoom(by: -1) },
        ])
        return UIMenu(title: "Zoom".localized, image: UIImage(systemName: "magnifyingglass"), children: [fit, width, steps])
    }

    private func setZoom(_ setting: ZoomSetting) {
        ZoomSetting.current = setting
        applyZoom()
        refreshToolsMenu()
    }

    private func stepZoom(by direction: Int) {
        var index: Int
        switch ZoomSetting.current {
        case .fitPage: index = 0
        case .fitWidth: index = 0
        case .factor(let value): index = Self.zoomFactors.enumerated().min { abs($0.element - value) < abs($1.element - value) }?.offset ?? 0
        }
        index = min(max(index + direction, 0), Self.zoomFactors.count - 1)
        setZoom(index == 0 ? .fitPage : .factor(Self.zoomFactors[index]))
    }

    /// Applies the chosen zoom to the current layout. Zoom is remembered and
    /// re-applied after rotation so people who need larger notation keep it.
    private func applyZoom() {
        guard !autoScroller.isRunning else { return }
        let fitScale = pdfView.scaleFactorForSizeToFit
        switch ZoomSetting.current {
        case .fitPage:
            pdfView.autoScales = true
        case .fitWidth:
            guard let page = pdfView.currentPage else { return }
            let pageWidth = page.bounds(for: pdfView.displayBox).width
            guard pageWidth > 0 else { return }
            pdfView.autoScales = false
            pdfView.scaleFactor = pdfView.bounds.width / pageWidth
        case .factor(let value):
            pdfView.autoScales = false
            pdfView.scaleFactor = fitScale * value
        }
        if let page = pdfView.currentPage, ZoomSetting.current != .fitPage {
            // Start each page at its top edge so the first line is what you see.
            pdfView.go(to: CGRect(x: 0, y: page.bounds(for: pdfView.displayBox).maxY, width: 1, height: 1), on: page)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if lastZoomedSize != pdfView.bounds.size {
            lastZoomedSize = pdfView.bounds.size
            applyZoom()
        }
    }

    // MARK: - Tools (go to page, repeat, auto scroll)

    private func setUpTools() {
        let stack = UIStackView(arrangedSubviews: [midiStatusLabel, repeatLabel, toolsButton])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -76),
        ])
        toolsButton.menu = makeToolsMenu()
    }

    private func refreshToolsMenu() {
        toolsButton.menu = makeToolsMenu()
    }

    /// Highlights the tools button while MIDI playback, recording or mic following is running.
    private func setToolsActive(_ active: Bool) {
        toolsButton.configuration?.baseBackgroundColor = active ? Theme.accent : .secondarySystemBackground
        toolsButton.configuration?.baseForegroundColor = active ? .black : Theme.accent
    }

    private var pageCount: Int { pdfView.document?.pageCount ?? 0 }

    private var currentPageIndex: Int {
        guard let document = pdfView.document, let page = pdfView.currentPage else { return 0 }
        return document.index(for: page)
    }

    private func makeToolsMenu() -> UIMenu {
        let goTo = UIAction(title: "Go to Page…".localized, image: UIImage(systemName: "arrow.right.to.line")) { [weak self] _ in self?.promptGoToPage() }

        var repeatItems: [UIMenuElement] = []
        if repeatRange != nil {
            repeatItems.append(UIAction(title: "Stop Repeating".localized, image: UIImage(systemName: "stop.fill"), attributes: .destructive) { [weak self] _ in self?.repeatRange = nil })
        } else {
            repeatItems.append(UIAction(title: "Stay on This Page".localized, image: UIImage(systemName: "repeat.1")) { [weak self] _ in
                guard let self else { return }
                self.repeatRange = self.currentPageIndex...self.currentPageIndex
            })
            repeatItems.append(UIAction(title: "Loop Pages…".localized, image: UIImage(systemName: "repeat")) { [weak self] _ in self?.promptLoopPages() })
        }
        let repeatMenu = UIMenu(title: "Repeat".localized, options: .displayInline, children: repeatItems)

        var scrollItems: [UIMenuElement] = []
        if autoScroller.isRunning {
            scrollItems.append(UIAction(title: "Stop Auto Scroll".localized, image: UIImage(systemName: "stop.fill"), attributes: .destructive) { [weak self] _ in self?.setAutoScroll(false) })
        } else {
            scrollItems.append(UIAction(title: "Start Auto Scroll".localized, image: UIImage(systemName: "arrow.down.to.line")) { [weak self] _ in self?.setAutoScroll(true) })
        }
        let speeds: [(String, Double)] = [("Slower".localized, -10), ("Faster".localized, 10)]
        scrollItems.append(UIMenu(title: "Scroll Speed".localized + " (\(Int(AutoScroller.speed)))", image: UIImage(systemName: "speedometer"), children: speeds.map { name, delta in
            UIAction(title: name, image: UIImage(systemName: delta < 0 ? "minus" : "plus")) { [weak self] _ in
                AutoScroller.speed += delta
                self?.toolsButton.menu = self?.makeToolsMenu()
            }
        }))
        let scrollMenu = UIMenu(title: "Auto Scroll".localized, options: .displayInline, children: scrollItems)

        var children: [UIMenuElement] = [goTo, makeZoomMenu(), repeatMenu, scrollMenu]
        if currentScore != nil {
            let midi = makeMIDIMenu()
            children.append(UIMenu(title: midi.title, image: UIImage(systemName: "music.note"), children: midi.children))
        }
        return UIMenu(title: "Tools".localized, children: children)
    }

    private func setAutoScroll(_ on: Bool) {
        if on {
            repeatRange = nil
            autoScroller.start()
        } else {
            autoScroller.stop()
            applyZoom()
        }
        toolsButton.menu = makeToolsMenu()
        updateRepeatBadge()
    }

    private func autoScrollFinished() {
        autoScroller.stop()
        applyZoom()
        toolsButton.menu = makeToolsMenu()
        updateRepeatBadge()
    }

    private func updateRepeatBadge() {
        if let range = repeatRange {
            repeatLabel.text = range.count == 1
                ? "Repeating page %d".localized(range.lowerBound + 1)
                : "Looping pages %d–%d".localized(range.lowerBound + 1, range.upperBound + 1)
            repeatLabel.isHidden = false
        } else if autoScroller.isRunning {
            repeatLabel.text = "Auto Scroll".localized
            repeatLabel.isHidden = false
        } else {
            repeatLabel.isHidden = true
        }
    }

    private func promptGoToPage() {
        let alert = UIAlertController(title: "Go to Page".localized, message: "Enter a page number (1–%d).".localized(pageCount), preferredStyle: .alert)
        alert.addTextField { $0.keyboardType = .numberPad; $0.placeholder = "\(self.currentPageIndex + 1)" }
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "Go".localized, style: .default) { [weak self, weak alert] _ in
            guard let self, let number = Int(alert?.textFields?.first?.text ?? ""), (1...max(self.pageCount, 1)).contains(number) else { return }
            self.turnPage(toIndex: number - 1, forward: number - 1 > self.currentPageIndex)
        })
        present(alert, animated: true)
    }

    private func promptLoopPages() {
        let alert = UIAlertController(title: "Loop Pages".localized, message: "Enter a page number (1–%d).".localized(pageCount), preferredStyle: .alert)
        alert.addTextField { $0.keyboardType = .numberPad; $0.placeholder = "From page".localized; $0.text = "\(self.currentPageIndex + 1)" }
        alert.addTextField { $0.keyboardType = .numberPad; $0.placeholder = "To page".localized }
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "Repeat".localized, style: .default) { [weak self, weak alert] _ in
            guard let self, let fields = alert?.textFields,
                  let from = Int(fields[0].text ?? ""), let to = Int(fields[1].text ?? ""),
                  from <= to, from >= 1, to <= self.pageCount else { return }
            self.repeatRange = (from - 1)...(to - 1)
            self.turnPage(toIndex: from - 1, forward: from - 1 > self.currentPageIndex)
        })
        present(alert, animated: true)
    }

    fileprivate func setUpMIDI() {
        guard scoreID != nil else { return }

        midiController.onModeChanged = { [weak self] mode in self?.midiModeChanged(mode) }
        midiController.onNavigate = { [weak self] index in self?.turnPage(toIndex: index) }
        midiController.onRecordingFinished = { [weak self] marks in self?.saveRecordedMarks(marks) }
        refreshToolsMenu()
    }

    private func midiModeChanged(_ mode: MIDIPageTurnController.Mode) {
        switch mode {
        case .idle:
            midiStatusLabel.isHidden = true
        case .playing:
            midiStatusLabel.text = "Auto page turn on".localized
            midiStatusLabel.isHidden = false
        case .recording:
            midiStatusLabel.text = "Recording page turns…".localized
            midiStatusLabel.isHidden = false
        }
        setToolsActive(mode != .idle)
        refreshToolsMenu()
    }

    private func makeMIDIMenu() -> UIMenu {
        guard let score = currentScore else { return UIMenu() }
        if playMode == .performance { return makeAutoTurnMenu(for: score) }
        var items: [UIMenuElement] = []

        if midiController.mode != .idle {
            items.append(UIAction(title: "Stop".localized, image: UIImage(systemName: "stop.fill"), attributes: .destructive) { [weak self] _ in
                self?.midiController.stop()
            })
        } else if let midiURL = library.midiURL(for: score) {
            let hasMarks = !(score.pageMarks ?? []).isEmpty
            items.append(UIAction(title: "Play with Auto Page Turn".localized, image: UIImage(systemName: "play.fill"), attributes: hasMarks ? [] : .disabled) { [weak self] _ in
                self?.startAutoPlay(midiURL: midiURL, marks: score.pageMarks ?? [])
            })
            items.append(UIAction(title: "Record Page Turns".localized, image: UIImage(systemName: "record.circle")) { [weak self] _ in
                self?.confirmRecording(midiURL: midiURL)
            })
            items.append(UIMenu(options: .displayInline, children: [
                UIAction(title: "Replace MIDI File…".localized, image: UIImage(systemName: "arrow.triangle.2.circlepath")) { [weak self] _ in
                    self?.presentMIDIPicker()
                },
                UIAction(title: "Remove MIDI File".localized, image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                    guard let self, let score = self.currentScore else { return }
                    self.library.removeMIDI(from: score)
                    self.refreshToolsMenu()
                },
            ]))
        } else {
            items.append(UIAction(title: "Attach MIDI File…".localized, image: UIImage(systemName: "plus")) { [weak self] _ in
                self?.presentMIDIPicker()
            })
        }
        return UIMenu(title: "MIDI".localized, children: items)
    }

    private func makeAutoTurnMenu(for score: Score) -> UIMenu {
        var items: [UIMenuElement] = []
        if isCountingDown || midiController.mode != .idle || followController.isActive {
            items.append(UIAction(title: "Stop".localized, image: UIImage(systemName: "stop.fill"), attributes: .destructive) { [weak self] _ in
                self?.cancelAutoTurn()
            })
        } else if let midiURL = library.midiURL(for: score), let marks = score.pageMarks, !marks.isEmpty {
            items.append(UIAction(title: "Start Auto Turn".localized, image: UIImage(systemName: "play.circle")) { [weak self] _ in
                self?.startAutoTurn(midiURL: midiURL, marks: marks)
            })
            let followItems = FollowMode.allCases.map { mode in
                UIAction(title: mode.title, subtitle: mode.explanation,
                         image: UIImage(systemName: mode == .notes ? "music.note.list" : "metronome"),
                         state: mode == FollowMode.current ? .on : .off) { [weak self] _ in
                    FollowMode.current = mode
                    self?.startFollowing(midiURL: midiURL, marks: marks, mode: mode)
                }
            }
            items.append(UIMenu(title: "Follow My Playing".localized, image: UIImage(systemName: "ear"), children: followItems))
        } else {
            items.append(UIAction(title: "Record page turns in Practice mode first".localized, attributes: .disabled) { _ in })
        }
        return UIMenu(title: "Auto Turn".localized, children: items)
    }

    // Auto Turn is a paid feature. A short count-in gives the player time to
    // start playing, because the recorded page turns are relative to beat 0.
    private func startAutoTurn(midiURL: URL, marks: [PageMark]) {
        guard EntitlementManager.hasPerformanceAccess else {
            present(UINavigationController(rootViewController: PaywallViewController(reason: .autoTurn)), animated: true)
            return
        }

        var remaining = 3
        isCountingDown = true
        midiStatusLabel.text = "Starting in %d…".localized(remaining)
        midiStatusLabel.isHidden = false
        refreshToolsMenu()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            remaining -= 1
            if remaining > 0 {
                self.midiStatusLabel.text = "Starting in %d…".localized(remaining)
                return
            }
            timer.invalidate()
            self.countdownTimer = nil
            self.isCountingDown = false
            do {
                try self.midiController.startPlaying(midiURL: midiURL, marks: marks, silent: true)
            } catch {
                self.midiStatusLabel.isHidden = true
                self.refreshToolsMenu()
                self.presentMIDIMessage(title: "Couldn't Play MIDI File".localized, message: error.localizedDescription)
            }
        }
    }

    private func startFollowing(midiURL: URL, marks: [PageMark], mode: FollowMode) {
        guard EntitlementManager.hasPerformanceAccess else {
            present(UINavigationController(rootViewController: PaywallViewController(reason: .autoTurn)), animated: true)
            return
        }
        followController.start(midiURL: midiURL, marks: marks, mode: mode) { [weak self] error in
            guard let self else { return }
            if let error {
                self.presentMIDIMessage(title: "Couldn't Start Listening".localized, message: error.localizedDescription)
            }
            self.refreshToolsMenu()
        }
    }

    private func followStateChanged(_ state: ScoreFollowController.State) {
        switch state {
        case .idle: midiStatusLabel.isHidden = true
        case .listening:
            midiStatusLabel.text = "Listening…".localized
            midiStatusLabel.isHidden = false
        case .following:
            midiStatusLabel.text = "Following your playing".localized
            midiStatusLabel.isHidden = false
        }
        setToolsActive(state != .idle)
        refreshToolsMenu()
    }

    fileprivate func cancelAutoTurn() {
        followController.stop()
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountingDown = false
        midiController.stop()
        midiStatusLabel.isHidden = true
        refreshToolsMenu()
    }

    private func presentMIDIPicker() {
        guard EntitlementManager.hasUnlimitedAccess else {
            present(UINavigationController(rootViewController: PaywallViewController()), animated: true)
            return
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.midi])
        picker.delegate = self
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let score = currentScore else { return }
        do {
            try library.attachMIDI(at: url, to: score)
            refreshToolsMenu()
        } catch {
            presentMIDIMessage(title: "Couldn't Add MIDI File".localized, message: error.localizedDescription)
        }
    }

    private func confirmRecording(midiURL: URL) {
        let alert = UIAlertController(
            title: "Record Page Turns".localized,
            message: "The MIDI will play from the start. Turn the pages yourself at the right moments — PageTurn remembers where, then turns them for you next time.".localized,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "Start Recording".localized, style: .default) { [weak self] _ in
            do {
                try self?.midiController.startRecording(midiURL: midiURL)
            } catch {
                self?.presentMIDIMessage(title: "Couldn't Play MIDI File".localized, message: error.localizedDescription)
            }
        })
        present(alert, animated: true)
    }

    private func startAutoPlay(midiURL: URL, marks: [PageMark]) {
        do {
            try midiController.startPlaying(midiURL: midiURL, marks: marks)
        } catch {
            presentMIDIMessage(title: "Couldn't Play MIDI File".localized, message: error.localizedDescription)
        }
    }

    private func saveRecordedMarks(_ marks: [PageMark]) {
        guard let score = currentScore else { return }
        library.setPageMarks(marks, for: score)
        refreshToolsMenu()
        presentMIDIMessage(title: "Page turns saved".localized, message: String.localizedStringWithFormat(NSLocalizedString("midi_marks_saved", comment: ""), marks.count))
    }

    private func presentMIDIMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default))
        present(alert, animated: true)
    }
}

extension ScoreViewerViewController: AnnotationOverlayDelegate {
    func annotationOverlay(_ overlay: AnnotationOverlayView, didFinishStroke points: [CGPoint], tool: AnnotationTool, color: UIColor, on page: PDFPage) {
        guard points.count > 1 else { return }
        let pagePoints = points.map { pdfView.convert($0, to: page) }

        let path = UIBezierPath()
        path.move(to: pagePoints[0])
        for point in pagePoints.dropFirst() {
            path.addLine(to: point)
        }

        let lineWidth: CGFloat = tool == .highlighter ? 14 : 3
        let bounds = path.bounds.insetBy(dx: -lineWidth, dy: -lineWidth)

        let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
        annotation.color = tool == .highlighter ? color.withAlphaComponent(0.35) : color
        let border = PDFBorder()
        border.lineWidth = lineWidth
        annotation.border = border
        annotation.add(path)

        page.addAnnotation(annotation)
        saveAnnotations()
    }

    func annotationOverlay(_ overlay: AnnotationOverlayView, didTapToPlaceTextAt point: CGPoint, on page: PDFPage) {
        let alert = UIAlertController(title: "Add Note".localized, message: nil, preferredStyle: .alert)
        alert.addTextField()
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "Add".localized, style: .default) { [weak self, weak alert] _ in
            guard let self, let text = alert?.textFields?.first?.text, !text.isEmpty else { return }
            let pagePoint = self.pdfView.convert(point, to: page)
            let bounds = CGRect(x: pagePoint.x, y: pagePoint.y - 20, width: 180, height: 40)
            let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
            annotation.contents = text
            annotation.font = .systemFont(ofSize: 14)
            annotation.fontColor = self.currentAnnotationColor
            page.addAnnotation(annotation)
            self.saveAnnotations()
        })
        present(alert, animated: true)
    }

    func annotationOverlay(_ overlay: AnnotationOverlayView, didTapToEraseAt point: CGPoint, on page: PDFPage) {
        let pagePoint = pdfView.convert(point, to: page)
        guard let annotation = page.annotation(at: pagePoint) else { return }
        page.removeAnnotation(annotation)
        saveAnnotations()
    }
}
