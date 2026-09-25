import ARKit
import UIKit

// Gesture tuning screen following the Figma "Settings" design: control
// method, invert toggle, separate left/right turn thresholds, turn speed, and
// a device-capability note. The control-method section only appears when
// opened from a score, since it changes that score's active modality.
final class SettingsViewController: UIViewController {

    private static let faceMethods: [ModalityKind] = [.mouthMove, .wink, .headTilt]

    private let settings = GestureSettings.shared
    private let currentMethod: ModalityKind?
    private let onMethodChanged: ((ModalityKind) -> Void)?
    private let onTrackingChanged: (() -> Void)?
    private let onDismiss: (() -> Void)?
    private let onWillCalibrate: (() -> Void)?

    private let stack = UIStackView()
    private lazy var animationSpeedLabel = makeLabel(text: "", size: 16, color: .label)
    private lazy var speedValueLabel = makeLabel(text: "", size: 16, color: .label)

    init(currentMethod: ModalityKind? = nil, onMethodChanged: ((ModalityKind) -> Void)? = nil, onTrackingChanged: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil, onWillCalibrate: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
        self.onWillCalibrate = onWillCalibrate
        self.currentMethod = currentMethod
        self.onMethodChanged = onMethodChanged
        self.onTrackingChanged = onTrackingChanged
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings".localized
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
        ])

        buildSections()
    }

    private func buildSections() {
        if let currentMethod {
            addHeader("Control Method".localized)
            let control = UISegmentedControl(items: ["Mouth Movement".localized, "Winking".localized, "Head Tilt".localized])
            control.selectedSegmentIndex = Self.faceMethods.firstIndex(of: currentMethod) ?? UISegmentedControl.noSegment
            control.addAction(UIAction { [weak self, weak control] _ in
                guard let self, let index = control?.selectedSegmentIndex, index >= 0 else { return }
                self.onMethodChanged?(Self.faceMethods[index])
            }, for: .valueChanged)
            addCard([control], footer: "Mouth Movement: move your lips left or right with your mouth closed. Winking: wink one eye. Head Tilt: tilt your head to either side.".localized)
        }

        addHeader("Control Direction".localized)
        let invert = UISwitch()
        invert.isOn = settings.invertControls
        invert.addAction(UIAction { [weak self, weak invert] _ in
            self?.settings.invertControls = invert?.isOn ?? false
        }, for: .valueChanged)
        addCard([row(title: "Invert controls".localized, trailing: invert)],
                footer: "Off: gesture right to go to the next page, left to go back. On: the opposite.".localized)

        addHeader("Gestures".localized)
        var calibrate = UIButton.Configuration.plain()
        calibrate.title = "Calibrate & test gestures".localized
        calibrate.image = UIImage(systemName: "slider.horizontal.3")
        calibrate.imagePadding = 8
        calibrate.contentInsets = .zero
        let calibrateButton = UIButton(configuration: calibrate, primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            self.onWillCalibrate?()
            self.navigationController?.pushViewController(GestureCalibrationViewController(method: self.currentMethod ?? .wink), animated: true)
        })
        calibrateButton.contentHorizontalAlignment = .leading
        addCard([calibrateButton], footer: "Not everyone winks the same way. Try each gesture live and tune it to match yours.".localized)

        addHeader("Speed".localized)
        let speedRow = sliderRow(title: nil, value: Float(settings.turnInterval), range: 0.1...1.0, trailingLabel: speedValueLabel) { [weak self] in
            self?.settings.turnInterval = TimeInterval($0)
            self?.updateSpeedLabel()
        }
        updateSpeedLabel()
        addCard([speedRow], footer: "Adjust the time between page turns, if you gesture continuously.".localized)

        addHeader("Page Turn Animation".localized)
        let transition = UISegmentedControl(items: PageTransitionStyle.allCases.map(\.title))
        transition.selectedSegmentIndex = PageTransitionStyle.allCases.firstIndex(of: PageTransitionStyle.current) ?? 0
        transition.addAction(UIAction { [weak transition] _ in
            guard let index = transition?.selectedSegmentIndex, index >= 0 else { return }
            PageTransitionStyle.current = PageTransitionStyle.allCases[index]
        }, for: .valueChanged)
        let axis = UISegmentedControl(items: PageTransitionAxis.allCases.map(\.title))
        axis.selectedSegmentIndex = PageTransitionAxis.allCases.firstIndex(of: PageTransitionAxis.current) ?? 0
        axis.addAction(UIAction { [weak axis] _ in
            guard let index = axis?.selectedSegmentIndex, index >= 0 else { return }
            PageTransitionAxis.current = PageTransitionAxis.allCases[index]
        }, for: .valueChanged)
        let animationSpeed = sliderRow(title: nil, value: Float(PageTransitionSpeed.duration), range: PageTransitionSpeed.range, trailingLabel: animationSpeedLabel) { [weak self] in
            PageTransitionSpeed.duration = TimeInterval($0)
            self?.updateAnimationSpeedLabel()
        }
        updateAnimationSpeedLabel()
        addCard([transition, axis, animationSpeed], footer: "Choose the style, the direction the page moves, and how long a turn takes. Faster turns suit quick passages. Turned off automatically if Reduce Motion is on.".localized)

        addHeader("Alternate Controls".localized)
        if ARFaceTrackingConfiguration.isSupported {
            let force = UISwitch()
            force.isOn = settings.forceFallbackTracking
            force.addAction(UIAction { [weak self, weak force] _ in
                self?.settings.forceFallbackTracking = force?.isOn ?? false
                self?.onTrackingChanged?()
            }, for: .valueChanged)
            addCard([row(title: "Use less-accurate method".localized, trailing: force)],
                    footer: "Your device supports advanced face tracking. PageTurn can use a less-accurate method on older devices, or you can force it to use that method by turning this on.".localized)
        } else {
            addCard([makeLabel(text: "Your device doesn't support advanced face tracking, so PageTurn uses a less-accurate method with the front camera instead.".localized, size: 15, color: .label)])
        }

        addLegalLinks()
    }

    private func addLegalLinks() {
        addHeader("About".localized)
        func link(_ title: String, _ url: URL) -> UIButton {
            var config = UIButton.Configuration.plain()
            config.title = title
            config.contentInsets = .zero
            let button = UIButton(configuration: config, primaryAction: UIAction { _ in UIApplication.shared.open(url) })
            button.contentHorizontalAlignment = .leading
            return button
        }
        addCard([link("Terms of Use".localized, LegalLinks.termsOfUse), link("Privacy Policy".localized, LegalLinks.privacyPolicy)])
    }

    private func updateAnimationSpeedLabel() {
        animationSpeedLabel.text = String(format: "%.2fs", PageTransitionSpeed.duration)
    }

    private func updateSpeedLabel() {
        speedValueLabel.text = String(format: "%.1fs", settings.turnInterval)
    }

    // MARK: - Building blocks

    private func addHeader(_ text: String) {
        let label = makeLabel(text: text.uppercased(), size: 13, color: .secondaryLabel)
        stack.addArrangedSubview(label)
        stack.setCustomSpacing(6, after: label)
    }

    private func addCard(_ rows: [UIView], footer: String? = nil) {
        let inner = UIStackView(arrangedSubviews: rows)
        inner.axis = .vertical
        inner.spacing = 14
        inner.isLayoutMarginsRelativeArrangement = true
        inner.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        inner.backgroundColor = .secondarySystemGroupedBackground
        inner.layer.cornerRadius = 12
        stack.addArrangedSubview(inner)

        if let footer {
            let label = makeLabel(text: footer, size: 13, color: .secondaryLabel)
            stack.addArrangedSubview(label)
            stack.setCustomSpacing(20, after: label)
        } else {
            stack.setCustomSpacing(20, after: inner)
        }
    }

    private func row(title: String, trailing: UIView) -> UIView {
        let row = UIStackView(arrangedSubviews: [makeLabel(text: title, size: 17, color: .label), trailing])
        row.axis = .horizontal
        row.alignment = .center
        return row
    }

    private func sliderRow(title: String?, value: Float, range: ClosedRange<Float>, trailingLabel: UILabel? = nil, onChange: @escaping (Float) -> Void) -> UIView {
        let slider = UISlider()
        slider.minimumValue = range.lowerBound
        slider.maximumValue = range.upperBound
        slider.value = value
        slider.minimumTrackTintColor = .systemOrange
        slider.addAction(UIAction { [weak slider] _ in onChange(slider?.value ?? value) }, for: .valueChanged)

        var views: [UIView] = []
        if let title {
            let label = makeLabel(text: title, size: 17, color: .label)
            label.widthAnchor.constraint(equalToConstant: 52).isActive = true
            views.append(label)
        }
        if let trailingLabel {
            trailingLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
            views.append(trailingLabel)
        }
        views.append(slider)

        let row = UIStackView(arrangedSubviews: views)
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        return row
    }

    private func makeLabel(text: String, size: CGFloat, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: size)
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if navigationController?.isBeingDismissed == true || isBeingDismissed { onDismiss?() }
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }
}
