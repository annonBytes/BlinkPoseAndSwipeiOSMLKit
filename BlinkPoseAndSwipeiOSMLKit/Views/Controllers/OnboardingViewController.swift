import AVFoundation
import PDFKit
import UIKit

struct OnboardingPage {
    enum Action {
        case none
        case tryModality(ModalityKind)
        case requestCamera
    }

    let symbolName: String
    let title: String
    let body: String
    let action: Action

    static let all: [OnboardingPage] = [
        OnboardingPage(symbolName: "music.note.list", title: "Turn pages hands-free".localized,
                       body: "Keep playing while PageTurn turns your pages — with a tap, a swipe, a pedal, or just your face.".localized, action: .none),
        OnboardingPage(symbolName: "hand.tap", title: "Tap, swipe or pedal".localized,
                       body: "Tap the screen edges, swipe like a paper book, or pair a Bluetooth page-turner pedal. Switch any time while you play.".localized, action: .tryModality(.tap)),
        OnboardingPage(symbolName: "brain.head.profile", title: "Use your face".localized,
                       body: "Wink, tilt your head, or move your lips from side to side to turn pages — no hands needed.".localized, action: .none),
        OnboardingPage(symbolName: "camera", title: "Allow camera access".localized,
                       body: "PageTurn watches your face through the front camera to spot winks, head tilts and mouth movements. Nothing is recorded and nothing leaves your device.".localized, action: .requestCamera),
    ]
}

// First-run walkthrough following the Figma concept: a dark bottom sheet over
// a dimmed score page, one card per way of turning pages, circular back and
// forward arrows. Shown once, on first launch.
final class OnboardingViewController: UIViewController {

    static let completedKey = "Onboarding.completed"

    private let pages = OnboardingPage.all
    private var currentIndex = 0

    private let backdrop: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleToFill
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let sheet: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 32
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = PagingFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(OnboardingCell.self, forCellWithReuseIdentifier: OnboardingCell.identifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    private let pageControl: UIPageControl = {
        let control = UIPageControl()
        control.currentPageIndicatorTintColor = Theme.accent
        control.pageIndicatorTintColor = .tertiaryLabel
        control.isUserInteractionEnabled = false
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    private lazy var previousButton = makeArrowButton(systemName: "arrow.left") { [weak self] in self?.go(by: -1) }
    private lazy var nextButton = makeArrowButton(systemName: "arrow.right") { [weak self] in self?.go(by: 1) }

    private lazy var closeButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "xmark")
        config.cornerStyle = .capsule
        config.baseBackgroundColor = UIColor.black.withAlphaComponent(0.45)
        config.baseForegroundColor = .white
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in self?.finish() })
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        // Shown exactly once: counts as seen the moment it appears.
        UserDefaults.standard.set(true, forKey: Self.completedKey)

        backdrop.image = Self.backdropImage()
        let dim = UIView()
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        dim.translatesAutoresizingMaskIntoConstraints = false

        pageControl.numberOfPages = pages.count
        [backdrop, dim, closeButton, sheet].forEach { view.addSubview($0) }
        [collectionView, pageControl, previousButton, nextButton].forEach { sheet.addSubview($0) }

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.heightAnchor.constraint(equalTo: backdrop.widthAnchor, multiplier: 850.0 / 600.0),
            dim.topAnchor.constraint(equalTo: view.topAnchor),
            dim.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dim.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dim.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),

            sheet.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sheet.widthAnchor.constraint(lessThanOrEqualToConstant: 560),   // keep the card readable on iPad
            sheet.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor),
            sheet.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor),
            sheet.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            collectionView.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: sheet.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: sheet.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 250),

            previousButton.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 28),
            previousButton.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 4),
            previousButton.bottomAnchor.constraint(equalTo: sheet.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            nextButton.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -28),
            nextButton.centerYAnchor.constraint(equalTo: previousButton.centerYAnchor),

            pageControl.centerXAnchor.constraint(equalTo: sheet.centerXAnchor),
            pageControl.centerYAnchor.constraint(equalTo: previousButton.centerYAnchor),
        ])
        let fullWidth = sheet.widthAnchor.constraint(equalTo: view.widthAnchor)
        fullWidth.priority = .defaultHigh   // full width on iPhone; capped at 560 on iPad
        fullWidth.isActive = true
        updateControls()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // The sample score's first page, shown dimmed behind the sheet.
    private static func backdropImage() -> UIImage? {
        guard let page = PDFDocument(url: ScoreViewerViewController.demoDocumentURL)?.page(at: 0) else { return nil }
        return page.thumbnail(of: CGSize(width: 600, height: 850), for: .mediaBox)
    }

    private func makeArrowButton(systemName: String, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: systemName)
        config.cornerStyle = .capsule
        config.baseBackgroundColor = .tertiarySystemFill
        config.baseForegroundColor = .label
        let button = UIButton(configuration: config, primaryAction: UIAction { _ in action() })
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 48).isActive = true
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return button
    }

    private func go(by delta: Int) {
        let target = currentIndex + delta
        if target >= pages.count {
            finish()
            return
        }
        guard target >= 0 else { return }
        currentIndex = target
        collectionView.scrollToItem(at: IndexPath(item: target, section: 0), at: .centeredHorizontally, animated: true)
        updateControls()
    }

    private func updateControls() {
        pageControl.currentPage = currentIndex
        previousButton.isHidden = currentIndex == 0
        let isLast = currentIndex == pages.count - 1
        nextButton.configuration?.image = UIImage(systemName: isLast ? "checkmark" : "arrow.right")
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.completedKey)
        dismiss(animated: true)
    }

    // MARK: - Page actions

    private func actionTitle(for action: OnboardingPage.Action) -> String? {
        switch action {
        case .none:
            return nil
        case .tryModality:
            return "Try it now".localized
        case .requestCamera:
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: return "Camera allowed".localized
            case .notDetermined: return "Allow camera".localized
            default: return "Open Settings".localized
            }
        }
    }

    private func perform(_ action: OnboardingPage.Action) {
        switch action {
        case .none:
            break
        case .tryModality(let modality):
            let viewer = ScoreViewerViewController(documentURL: ScoreViewerViewController.demoDocumentURL, modality: modality)
            navigationController?.pushViewController(viewer, animated: true)
        case .requestCamera:
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                    DispatchQueue.main.async { self?.collectionView.reloadData() }
                }
            case .denied, .restricted:
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            default:
                break
            }
        }
    }
}

extension OnboardingViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        pages.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OnboardingCell.identifier, for: indexPath) as! OnboardingCell
        let page = pages[indexPath.item]
        let granted: Bool = {
            if case .requestCamera = page.action { return AVCaptureDevice.authorizationStatus(for: .video) == .authorized }
            return false
        }()
        cell.configure(with: page, actionTitle: actionTitle(for: page.action), actionDone: granted) { [weak self] in
            self?.perform(page.action)
        }
        return cell
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let width = scrollView.bounds.width
        guard width > 0 else { return }
        currentIndex = Int((scrollView.contentOffset.x / width).rounded())
        updateControls()
    }
}

final class OnboardingCell: UICollectionViewCell {
    static let identifier = "OnboardingCell"

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private var onAction: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        iconView.tintColor = .label
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        iconView.widthAnchor.constraint(equalToConstant: 36).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 36).isActive = true

        titleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        titleLabel.numberOfLines = 0

        bodyLabel.font = .systemFont(ofSize: 17)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 0

        actionButton.addAction(UIAction { [weak self] _ in self?.onAction?() }, for: .touchUpInside)

        let titleRow = UIStackView(arrangedSubviews: [iconView, titleLabel])
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 12

        let stack = UIStackView(arrangedSubviews: [titleRow, bodyLabel, actionButton])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.setCustomSpacing(20, after: bodyLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with page: OnboardingPage, actionTitle: String?, actionDone: Bool, onAction: @escaping () -> Void) {
        iconView.image = UIImage(systemName: page.symbolName)
        titleLabel.text = page.title
        bodyLabel.text = page.body
        self.onAction = onAction

        actionButton.isHidden = actionTitle == nil
        var config = UIButton.Configuration.filled()
        config.title = actionTitle
        config.image = actionDone ? UIImage(systemName: "checkmark") : nil
        config.imagePadding = 6
        config.cornerStyle = .capsule
        config.baseBackgroundColor = actionDone ? .tertiarySystemFill : Theme.accent
        config.baseForegroundColor = actionDone ? .label : .black
        actionButton.configuration = config
        actionButton.isEnabled = !actionDone
    }
}

// Every page is exactly the collection view's size; deriving it inside the
// layout (rather than from the view controller) keeps it correct even when the
// collection view is laid out later than its parent.
final class PagingFlowLayout: UICollectionViewFlowLayout {
    override func prepare() {
        if let collectionView, collectionView.bounds.width > 0, itemSize != collectionView.bounds.size {
            itemSize = collectionView.bounds.size
        }
        super.prepare()
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        newBounds.size != collectionView?.bounds.size
    }
}
