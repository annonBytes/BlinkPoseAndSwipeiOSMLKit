import UIKit
import UniformTypeIdentifiers

// The app's root screen: the user's uploaded scores as a data-driven grid.
// First launch presents the one-time onboarding walkthrough.
final class LibraryViewController: UIViewController {

    private let library = ScoreLibrary.shared

    private lazy var statusBanner: UIButton = {
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        config.titleAlignment = .leading
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in self?.presentPaywall() })
        button.contentHorizontalAlignment = .leading
        button.backgroundColor = .secondarySystemBackground
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.register(LibraryScoreCell.self, forCellWithReuseIdentifier: LibraryScoreCell.identifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "Tap + to add your first PDF score".localized
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Library".localized
        navigationController?.navigationBar.prefersLargeTitles = true

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
        addButton.accessibilityLabel = "Add PDF".localized
        let metronomeButton = UIBarButtonItem(image: UIImage(systemName: "metronome"), style: .plain, target: self, action: #selector(showMetronome))
        metronomeButton.accessibilityLabel = "Metronome".localized
        let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(showSettings))
        settingsButton.accessibilityLabel = "Settings".localized
        navigationItem.rightBarButtonItems = [addButton, metronomeButton, settingsButton]

        setUpViews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !UserDefaults.standard.bool(forKey: OnboardingViewController.completedKey), presentedViewController == nil {
            presentOnboarding()
        }
    }

    private func setUpViews() {
        view.addSubview(statusBanner)
        view.addSubview(collectionView)
        view.addSubview(emptyStateLabel)
        NSLayoutConstraint.activate([
            statusBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            statusBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            collectionView.topAnchor.constraint(equalTo: statusBanner.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
    }

    private func refresh() {
        collectionView.reloadData()
        emptyStateLabel.isHidden = !library.scores.isEmpty
        updateStatusBanner()
    }

    private func updateStatusBanner() {
        var config = statusBanner.configuration
        if SubscriptionStore.shared.isSubscribed {
            config?.title = "✓ Premium — unlimited uploads".localized
            config?.baseForegroundColor = .secondaryLabel
        } else if TrialManager.shared.isActive {
            let days = TrialManager.shared.daysRemaining
            config?.title = String.localizedStringWithFormat(NSLocalizedString("trial_days_left_banner", comment: ""), days)
            config?.baseForegroundColor = .label
        } else {
            config?.title = "Trial ended — Subscribe for unlimited uploads".localized
            config?.baseForegroundColor = .systemRed
        }
        statusBanner.configuration = config
    }

    @objc private func addTapped() {
        guard EntitlementManager.hasUnlimitedAccess else {
            presentPaywall()
            return
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }

    private func presentPaywall() {
        let paywall = PaywallViewController()
        present(UINavigationController(rootViewController: paywall), animated: true)
    }

    private func presentOnboarding() {
        let nav = UINavigationController(rootViewController: OnboardingViewController())
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func showSettings() {
        present(UINavigationController(rootViewController: SettingsViewController()), animated: true)
    }

    @objc private func showMetronome() {
        present(UINavigationController(rootViewController: MetronomeViewController()), animated: true)
    }

    private func openScore(_ score: Score) {
        let viewer = ScoreViewerViewController(documentURL: library.fileURL(for: score), modality: score.preferredModality, score: score) { [weak self] newModality in
            self?.library.setPreferredModality(newModality, for: score)
        }
        navigationController?.pushViewController(viewer, animated: true)
    }
}

extension LibraryViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        library.scores.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: LibraryScoreCell.identifier, for: indexPath) as! LibraryScoreCell
        let score = library.scores[indexPath.item]
        cell.configure(with: score, thumbnail: library.thumbnail(for: score, size: CGSize(width: 160, height: 208)))
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (view.frame.width - 16 * 3) / 2
        return CGSize(width: width, height: width * 1.3 + 44)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        openScore(library.scores[indexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let score = library.scores[indexPath.item]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self else { return nil }

            let modalityMenu = UIMenu(title: "Page-Turn Modality".localized, options: .displayInline, children: ModalityKind.allCases.map { modality in
                UIAction(title: modality.displayName, state: score.preferredModality == modality ? .on : .off) { [weak self] _ in
                    self?.library.setPreferredModality(modality, for: score)
                    self?.refresh()
                }
            })

            var children: [UIMenuElement] = [modalityMenu]
            if !score.isBuiltIn {
                children.append(UIAction(title: "Delete".localized, image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                    self?.library.delete(score)
                    self?.refresh()
                })
            }
            return UIMenu(children: children)
        }
    }
}

extension LibraryViewController: UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let score = library.scores[indexPath.item]
        let dragItem = UIDragItem(itemProvider: NSItemProvider(object: score.title as NSString))
        dragItem.localObject = score
        return [dragItem]
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let item = coordinator.items.first, let sourceIndexPath = item.sourceIndexPath else { return }
        let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(item: library.scores.count - 1, section: 0)

        library.move(fromIndex: sourceIndexPath.item, toIndex: destinationIndexPath.item)
        collectionView.performBatchUpdates {
            collectionView.deleteItems(at: [sourceIndexPath])
            collectionView.insertItems(at: [destinationIndexPath])
        }
        coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }
}

extension LibraryViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            do {
                try library.importPDF(at: url)
            } catch {
                let alert = UIAlertController(title: "Couldn't Add PDF".localized, message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK".localized, style: .default))
                present(alert, animated: true)
            }
        }
        refresh()
    }
}
