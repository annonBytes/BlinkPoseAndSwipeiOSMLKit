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

    private var currentScore: Score? {
        scoreID.flatMap { library.score(withID: $0) }
    }

    private lazy var midiButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "music.note")
        config.cornerStyle = .capsule
        config.baseBackgroundColor = .secondarySystemBackground
        config.baseForegroundColor = Theme.accent
        let button = UIButton(configuration: config)
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = "MIDI".localized
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }()

    private let midiStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = Theme.accent
        label.isHidden = true
        return label
    }()

    private lazy var midiStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [midiButton, midiStatusLabel])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

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
        self.documentURL = documentURL
        self.currentModality = modality
        self.detector = modality.makeDetector()
        self.onModalityChanged = onModalityChanged
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
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

        NotificationCenter.default.addObserver(self, selector: #selector(updatePageTitle), name: .PDFViewPageChanged, object: pdfView)
        updatePageTitle()
    }

    @objc private func updatePageTitle() {
        guard let document = pdfView.document, let page = pdfView.currentPage else { return }
        title = "Page %d of %d".localized(document.index(for: page) + 1, document.pageCount)
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
        midiButton.menu = makeMIDIMenu()
        UIApplication.shared.isIdleTimerDisabled = mode == .performance
    }

    private func installDetector(_ newDetector: GestureDetector) {
        detector = newDetector
        detector.attach(to: self, pageView: pdfView)
        detector.onAdvance = { [weak self] in
            guard let self else { return }
            self.pdfView.goToNextPage(self.pdfView.next)
        }
        detector.onGoBack = { [weak self] in
            guard let self else { return }
            self.pdfView.goToPreviousPage(self.pdfView.canGoBack)
        }
        detector.onGestureBegan = { [weak self] in self?.feedbackView.showActive() }
        detector.onGestureEnded = { [weak self] in self?.feedbackView.showIdle() }
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
            feedbackView.widthAnchor.constraint(equalToConstant: 28),
            feedbackView.heightAnchor.constraint(equalToConstant: 28),
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
    fileprivate func setUpMIDI() {
        guard scoreID != nil else { return }

        view.addSubview(midiStack)
        NSLayoutConstraint.activate([
            midiStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            midiStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -76),
        ])

        midiController.onModeChanged = { [weak self] mode in self?.midiModeChanged(mode) }
        midiController.onRecordingFinished = { [weak self] marks in self?.saveRecordedMarks(marks) }
        midiButton.menu = makeMIDIMenu()
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
        midiButton.configuration?.baseBackgroundColor = mode == .idle ? .secondarySystemBackground : Theme.accent
        midiButton.configuration?.baseForegroundColor = mode == .idle ? Theme.accent : .black
        midiButton.menu = makeMIDIMenu()
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
                    self.midiButton.menu = self.makeMIDIMenu()
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
        if isCountingDown || midiController.mode != .idle {
            items.append(UIAction(title: "Stop".localized, image: UIImage(systemName: "stop.fill"), attributes: .destructive) { [weak self] _ in
                self?.cancelAutoTurn()
            })
        } else if let midiURL = library.midiURL(for: score), let marks = score.pageMarks, !marks.isEmpty {
            items.append(UIAction(title: "Start Auto Turn".localized, image: UIImage(systemName: "play.circle")) { [weak self] _ in
                self?.startAutoTurn(midiURL: midiURL, marks: marks)
            })
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
        midiButton.menu = makeMIDIMenu()

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
                self.midiButton.menu = self.makeMIDIMenu()
                self.presentMIDIMessage(title: "Couldn't Play MIDI File".localized, message: error.localizedDescription)
            }
        }
    }

    fileprivate func cancelAutoTurn() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountingDown = false
        midiController.stop()
        midiStatusLabel.isHidden = true
        midiButton.menu = makeMIDIMenu()
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
            midiButton.menu = makeMIDIMenu()
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
        midiButton.menu = makeMIDIMenu()
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
