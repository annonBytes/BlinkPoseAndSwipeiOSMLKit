import UIKit

// Lets a user tune a face gesture to how *they* make it, and try it live:
// two meters show what the camera reads for the left and right gesture, with a
// marker at the level that turns a page. Styles give a quick starting point;
// sliders fine-tune it. Changes save instantly and apply to real page turning.
final class GestureCalibrationViewController: UIViewController {

    private enum Style: CaseIterable {
        case subtle, natural, deliberate

        var title: String {
            switch self {
            case .subtle: return "Subtle".localized
            case .natural: return "Natural".localized
            case .deliberate: return "Deliberate".localized
            }
        }
        var sensitivity: Float {
            switch self {
            case .subtle: return 0.3
            case .natural: return 0.5
            case .deliberate: return 0.75
            }
        }
        var holdMultiplier: Double {
            switch self {
            case .subtle: return 0.5
            case .natural: return 1
            case .deliberate: return 2
            }
        }
    }

    private static let methods: [(kind: ModalityKind, title: String)] = [
        (.wink, "Winking".localized), (.headTilt, "Head Tilt".localized), (.mouthMove, "Mouth Movement".localized),
    ]

    private let settings = GestureSettings.shared
    private var method: ModalityKind
    private var detector: GestureDetector?
    private var nextCount = 0
    private var backCount = 0

    private let nextMeter = MeterView()
    private let backMeter = MeterView()
    private let resultLabel = UILabel()
    private let styleControl = UISegmentedControl(items: Style.allCases.map(\.title))
    private let leftSlider = UISlider()
    private let rightSlider = UISlider()
    private let holdSlider = UISlider()
    private let holdValueLabel = UILabel()

    init(method: ModalityKind = .wink) {
        self.method = Self.methods.contains { $0.kind == method } ? method : .wink
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Calibrate Gestures".localized
        view.backgroundColor = .systemGroupedBackground

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
        ])

        // Which gesture
        let methodControl = UISegmentedControl(items: Self.methods.map(\.title))
        methodControl.selectedSegmentIndex = Self.methods.firstIndex { $0.kind == method } ?? 0
        methodControl.addAction(UIAction { [weak self, weak methodControl] _ in
            guard let self, let index = methodControl?.selectedSegmentIndex else { return }
            self.method = Self.methods[index].kind
            self.loadProfile()
            self.startDetector()
        }, for: .valueChanged)
        stack.addArrangedSubview(methodControl)

        stack.addArrangedSubview(label("Try your gesture now. The bars show what the camera sees — a page turns when a bar passes its white marker.".localized, size: 14, color: .secondaryLabel))

        // Live meters
        nextMeter.caption = "Right — next page".localized
        backMeter.caption = "Left — previous page".localized
        stack.addArrangedSubview(card([nextMeter, backMeter]))

        resultLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        resultLabel.textColor = Theme.accent
        resultLabel.textAlignment = .center
        resultLabel.text = "Waiting for a gesture…".localized
        stack.addArrangedSubview(resultLabel)

        // Style presets
        stack.addArrangedSubview(header("Style".localized))
        styleControl.addAction(UIAction { [weak self] _ in self?.applyStyle() }, for: .valueChanged)
        stack.addArrangedSubview(card([styleControl]))
        stack.addArrangedSubview(label("Subtle: small, quick movements. Natural: the default. Deliberate: bigger, held gestures that avoid accidental turns.".localized, size: 13, color: .secondaryLabel))

        // Fine tuning
        stack.addArrangedSubview(header("Fine tune".localized))
        for slider in [leftSlider, rightSlider] {
            slider.minimumValue = 0
            slider.maximumValue = 1
            slider.minimumTrackTintColor = Theme.accent
            slider.addAction(UIAction { [weak self] _ in self?.slidersChanged() }, for: .valueChanged)
        }
        holdSlider.minimumValue = 0.05
        holdSlider.maximumValue = 0.6
        holdSlider.minimumTrackTintColor = Theme.accent
        holdSlider.addAction(UIAction { [weak self] _ in self?.slidersChanged() }, for: .valueChanged)
        holdValueLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        holdValueLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true

        stack.addArrangedSubview(card([
            sliderRow("Left".localized, leftSlider),
            sliderRow("Right".localized, rightSlider),
            sliderRow("Hold".localized, holdSlider, trailing: holdValueLabel),
        ]))
        stack.addArrangedSubview(label("Left and Right set how strong each gesture must be — lower if pages are hard to turn, higher if they turn by accident. Hold sets how long a gesture must last to count.".localized, size: 13, color: .secondaryLabel))

        var reset = UIButton.Configuration.plain()
        reset.title = "Reset to Default".localized
        reset.baseForegroundColor = .systemRed
        let resetButton = UIButton(configuration: reset, primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            self.settings.resetProfile(for: self.method.faceConfig?.name ?? "")
            self.loadProfile()
        })
        stack.addArrangedSubview(resetButton)

        loadProfile()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startDetector()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        detector?.stop()
        detector = nil
    }

    // MARK: - Detector

    private func startDetector() {
        detector?.stop()
        nextCount = 0
        backCount = 0
        resultLabel.text = "Waiting for a gesture…".localized
        nextMeter.value = 0
        backMeter.value = 0

        let detector = method.makeDetector()
        (detector as? FaceMeasuring)?.onMeasurement = { [weak self] measurement in
            self?.nextMeter.update(value: measurement.advance, threshold: measurement.advanceThreshold)
            self?.backMeter.update(value: measurement.goBack, threshold: measurement.goBackThreshold)
        }
        detector.onAdvance = { [weak self] in
            guard let self else { return }
            self.nextCount += 1
            self.showResult()
        }
        detector.onGoBack = { [weak self] in
            guard let self else { return }
            self.backCount += 1
            self.showResult()
        }
        detector.attach(to: self, pageView: view)
        detector.start()
        self.detector = detector
    }

    private func showResult() {
        resultLabel.text = "Next page ×%d   ·   Previous page ×%d".localized(nextCount, backCount)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Profile

    private var gestureName: String { method.faceConfig?.name ?? "" }

    private func loadProfile() {
        guard let config = method.faceConfig else { return }
        let profile = settings.profile(for: gestureName)
        leftSlider.value = profile.leftSensitivity
        rightSlider.value = profile.rightSensitivity
        holdSlider.value = Float(profile.holdTime ?? config.holdTimeThreshold)
        updateHoldLabel()
        updateStyleSelection(profile: profile, config: config)
    }

    private func applyStyle() {
        guard let config = method.faceConfig, styleControl.selectedSegmentIndex >= 0 else { return }
        let style = Style.allCases[styleControl.selectedSegmentIndex]
        let profile = GestureProfile(leftSensitivity: style.sensitivity, rightSensitivity: style.sensitivity,
                                     holdTime: config.holdTimeThreshold * style.holdMultiplier)
        settings.setProfile(profile, for: gestureName)
        leftSlider.value = profile.leftSensitivity
        rightSlider.value = profile.rightSensitivity
        holdSlider.value = Float(profile.holdTime ?? config.holdTimeThreshold)
        updateHoldLabel()
    }

    private func slidersChanged() {
        guard let config = method.faceConfig else { return }
        let profile = GestureProfile(leftSensitivity: leftSlider.value, rightSensitivity: rightSlider.value,
                                     holdTime: TimeInterval(holdSlider.value))
        settings.setProfile(profile, for: gestureName)
        updateHoldLabel()
        updateStyleSelection(profile: profile, config: config)
    }

    private func updateHoldLabel() {
        holdValueLabel.text = String(format: "%.2fs", holdSlider.value)
    }

    // Highlight a style only when the current numbers actually match it.
    private func updateStyleSelection(profile: GestureProfile, config: FaceGestureConfig) {
        let hold = profile.holdTime ?? config.holdTimeThreshold
        let match = Style.allCases.firstIndex { style in
            abs(profile.leftSensitivity - style.sensitivity) < 0.02 && abs(profile.rightSensitivity - style.sensitivity) < 0.02
                && abs(hold - config.holdTimeThreshold * style.holdMultiplier) < 0.02
        }
        styleControl.selectedSegmentIndex = match ?? UISegmentedControl.noSegment
    }

    // MARK: - Building blocks

    private func header(_ text: String) -> UILabel {
        label(text.uppercased(), size: 13, color: .secondaryLabel)
    }

    private func label(_ text: String, size: CGFloat, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: size)
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func card(_ rows: [UIView]) -> UIStackView {
        let inner = UIStackView(arrangedSubviews: rows)
        inner.axis = .vertical
        inner.spacing = 14
        inner.isLayoutMarginsRelativeArrangement = true
        inner.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        inner.backgroundColor = .secondarySystemGroupedBackground
        inner.layer.cornerRadius = 12
        return inner
    }

    private func sliderRow(_ title: String, _ slider: UISlider, trailing: UIView? = nil) -> UIView {
        let titleLabel = label(title, size: 17, color: .label)
        titleLabel.widthAnchor.constraint(equalToConstant: 56).isActive = true
        let row = UIStackView(arrangedSubviews: [titleLabel, slider] + (trailing.map { [$0] } ?? []))
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        return row
    }
}

// A horizontal level bar with a white marker at the trigger threshold.
final class MeterView: UIView {
    var caption = "" { didSet { captionLabel.text = caption } }
    var value: Float = 0 { didSet { setNeedsLayout() } }
    private var threshold: Float = 0.5

    private let captionLabel = UILabel()
    private let track = UIView()
    private let fill = UIView()
    private let marker = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        captionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        captionLabel.textColor = .secondaryLabel
        captionLabel.translatesAutoresizingMaskIntoConstraints = false

        track.backgroundColor = .tertiarySystemFill
        track.layer.cornerRadius = 8
        track.clipsToBounds = true
        track.translatesAutoresizingMaskIntoConstraints = false
        fill.backgroundColor = Theme.accent
        track.addSubview(fill)
        marker.backgroundColor = .white
        track.addSubview(marker)

        addSubview(captionLabel)
        addSubview(track)
        NSLayoutConstraint.activate([
            captionLabel.topAnchor.constraint(equalTo: topAnchor),
            captionLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            captionLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 6),
            track.leadingAnchor.constraint(equalTo: leadingAnchor),
            track.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.bottomAnchor.constraint(equalTo: bottomAnchor),
            track.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(value: Float, threshold: Float) {
        self.threshold = threshold
        self.value = value
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = track.bounds.width
        let level = CGFloat(min(max(value, 0), 1))
        fill.frame = CGRect(x: 0, y: 0, width: width * level, height: track.bounds.height)
        fill.backgroundColor = value >= threshold ? .systemGreen : Theme.accent
        marker.frame = CGRect(x: width * CGFloat(min(max(threshold, 0), 1)) - 1.5, y: 0, width: 3, height: track.bounds.height)
    }
}
