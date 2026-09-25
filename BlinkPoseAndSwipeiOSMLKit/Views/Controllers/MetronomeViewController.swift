import UIKit

final class MetronomeViewController: UIViewController {

    private let engine = MetronomeEngine()
    private var tapTimestamps: [Date] = []

    private let bpmLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 64, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let bpmCaptionLabel: UILabel = {
        let label = UILabel()
        label.text = "BPM".localized
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let beatIndicator: GestureFeedbackView = {
        let view = GestureFeedbackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var slider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 30
        slider.maximumValue = 260
        slider.value = Float(engine.bpm)
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()

    private lazy var timeSignatureControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["2/4", "3/4", "4/4", "6/8"])
        control.selectedSegmentIndex = 2
        control.addTarget(self, action: #selector(timeSignatureChanged), for: .valueChanged)
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    private lazy var tapTempoButton: UIButton = {
        let button = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in self?.tapTempo() })
        button.setTitle("Tap Tempo".localized, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var playButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Start".localized
        config.cornerStyle = .capsule
        config.baseBackgroundColor = .systemGreen
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in self?.togglePlayback() })
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Metronome".localized
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))

        setUpViews()
        updateBPMLabel()

        engine.onBeat = { [weak self] beatIndex in
            guard let self else { return }
            self.beatIndicator.showActive()
            let duration = 60.0 / self.engine.bpm * 0.35
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.beatIndicator.showIdle()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        engine.stop()
        playButton.configuration?.title = "Start".localized
    }

    private func setUpViews() {
        [beatIndicator, bpmLabel, bpmCaptionLabel, slider, timeSignatureControl, tapTempoButton, playButton].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            beatIndicator.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            beatIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            beatIndicator.widthAnchor.constraint(equalToConstant: 32),
            beatIndicator.heightAnchor.constraint(equalToConstant: 32),

            bpmLabel.topAnchor.constraint(equalTo: beatIndicator.bottomAnchor, constant: 24),
            bpmLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            bpmCaptionLabel.topAnchor.constraint(equalTo: bpmLabel.bottomAnchor, constant: 2),
            bpmCaptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            slider.topAnchor.constraint(equalTo: bpmCaptionLabel.bottomAnchor, constant: 32),
            slider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            slider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            timeSignatureControl.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 32),
            timeSignatureControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            timeSignatureControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            tapTempoButton.topAnchor.constraint(equalTo: timeSignatureControl.bottomAnchor, constant: 24),
            tapTempoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            playButton.topAnchor.constraint(equalTo: tapTempoButton.bottomAnchor, constant: 40),
            playButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            playButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
            playButton.heightAnchor.constraint(equalToConstant: 56),
        ])
    }

    private func updateBPMLabel() {
        bpmLabel.text = "\(Int(engine.bpm.rounded()))"
    }

    @objc private func sliderChanged() {
        engine.bpm = Double(slider.value)
        updateBPMLabel()
    }

    @objc private func timeSignatureChanged() {
        let beatsPerMeasure = [2, 3, 4, 6][timeSignatureControl.selectedSegmentIndex]
        engine.beatsPerMeasure = beatsPerMeasure
    }

    private func tapTempo() {
        let now = Date()
        tapTimestamps.append(now)
        tapTimestamps = tapTimestamps.filter { now.timeIntervalSince($0) < 2.5 }.suffix(6).map { $0 }

        guard tapTimestamps.count > 1 else { return }
        let intervals = zip(tapTimestamps, tapTimestamps.dropFirst()).map { $1.timeIntervalSince($0) }
        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        guard averageInterval > 0 else { return }

        let tappedBPM = 60.0 / averageInterval
        engine.bpm = tappedBPM
        slider.value = Float(engine.bpm)
        updateBPMLabel()
    }

    private func togglePlayback() {
        if engine.isPlaying {
            engine.stop()
            playButton.configuration?.title = "Start".localized
            playButton.configuration?.baseBackgroundColor = .systemGreen
            beatIndicator.showIdle()
        } else {
            engine.start()
            playButton.configuration?.title = "Stop".localized
            playButton.configuration?.baseBackgroundColor = .systemRed
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
