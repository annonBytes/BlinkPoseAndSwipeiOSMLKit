import StoreKit
import UIKit

final class PaywallViewController: UIViewController {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 28)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let featuresLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.numberOfLines = 0
        label.text = ["Unlimited PDF uploads".localized, "Every page-turn modality".localized, "PDF annotation & markup".localized].map { "•  " + $0 }.joined(separator: "\n")
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var subscribeButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Subscribe".localized
        config.cornerStyle = .medium
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in self?.subscribeTapped() })
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var restoreButton: UIButton = {
        let button = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in self?.restoreTapped() })
        button.setTitle("Restore Purchases".localized, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))

        if TrialManager.shared.isActive {
            titleLabel.text = String.localizedStringWithFormat(NSLocalizedString("trial_days_left_title", comment: ""), TrialManager.shared.daysRemaining)
            messageLabel.text = "Subscribe now to keep unlimited uploads after your free trial ends.".localized
        } else {
            titleLabel.text = "Your Free Trial Has Ended".localized
            messageLabel.text = "Subscribe to keep uploading and playing your own sheet music. The Welcome score stays free forever.".localized
        }

        setUpViews()
        refreshProductPrice()
    }

    private func setUpViews() {
        [titleLabel, messageLabel, featuresLabel, subscribeButton, restoreButton, activityIndicator].forEach { view.addSubview($0) }
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            featuresLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 32),
            featuresLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            featuresLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            subscribeButton.topAnchor.constraint(equalTo: featuresLabel.bottomAnchor, constant: 40),
            subscribeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subscribeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            subscribeButton.heightAnchor.constraint(equalToConstant: 50),

            activityIndicator.centerXAnchor.constraint(equalTo: subscribeButton.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: subscribeButton.bottomAnchor, constant: 16),

            restoreButton.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 8),
            restoreButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func refreshProductPrice() {
        Task {
            await SubscriptionStore.shared.loadProducts()
            guard let product = SubscriptionStore.shared.products.first else { return }
            var config = subscribeButton.configuration
            config?.title = "Subscribe — %@/month".localized(product.displayPrice)
            subscribeButton.configuration = config
        }
    }

    private func subscribeTapped() {
        setLoading(true)
        Task {
            do {
                try await SubscriptionStore.shared.purchase()
                setLoading(false)
                if SubscriptionStore.shared.isSubscribed {
                    dismiss(animated: true)
                }
            } catch {
                setLoading(false)
                presentMessage(error.localizedDescription)
            }
        }
    }

    private func restoreTapped() {
        setLoading(true)
        Task {
            do {
                try await SubscriptionStore.shared.restore()
                setLoading(false)
                if SubscriptionStore.shared.isSubscribed {
                    dismiss(animated: true)
                } else {
                    presentMessage("No active subscription found to restore.".localized)
                }
            } catch {
                setLoading(false)
                presentMessage(error.localizedDescription)
            }
        }
    }

    private func setLoading(_ loading: Bool) {
        subscribeButton.isEnabled = !loading
        restoreButton.isEnabled = !loading
        loading ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
    }

    private func presentMessage(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default))
        present(alert, animated: true)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
