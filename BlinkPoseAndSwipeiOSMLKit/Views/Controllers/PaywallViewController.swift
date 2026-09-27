import StoreKit
import UIKit

// Paywall laid out after the Figma "Perplexity" paywall: close and Restore at
// the top, a light wordmark with a tagline, a checklist of what you get,
// side-by-side Monthly and Free-trial cards, and a wide Subscribe button.
final class PaywallViewController: UIViewController {

    enum Reason { case general, autoTurn }
    private let reason: Reason

    init(reason: Reason = .general) {
        self.reason = reason
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Helpers

    private func label(_ text: String, size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = .white, lines: Int = 0, align: NSTextAlignment = .natural) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.numberOfLines = lines
        label.textAlignment = align
        return label
    }

    private func pin(_ inner: UIView, in card: UIView, insets: UIEdgeInsets) {
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: insets.top),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -insets.bottom),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: insets.left),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -insets.right),
        ])
    }

    // MARK: Top bar

    private lazy var closeButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
        config.baseForegroundColor = .white
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in self?.closeTapped() })
        button.accessibilityLabel = "Close".localized
        return button
    }()

    private lazy var restoreButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "Restore".localized
        config.baseForegroundColor = .white
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { var out = $0; out.font = .systemFont(ofSize: 15, weight: .medium); return out }
        return UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in self?.restoreTapped() })
    }()

    // MARK: Header

    private lazy var headerStack: UIStackView = {
        let wordmark = label("PageTurn", size: 40, weight: .light, align: .center)
        let tagline = label(reason == .autoTurn ? "Auto Turn is included with Premium".localized : "Unlock hands-free page turning".localized,
                            size: 16, color: UIColor.white.withAlphaComponent(0.8), align: .center)
        var views: [UIView] = [wordmark, tagline]
        if reason != .autoTurn {
            let trial = TrialManager.shared
            let status = trial.isActive
                ? String.localizedStringWithFormat(NSLocalizedString("trial_days_left_title", comment: ""), trial.daysRemaining)
                : "Your Free Trial Has Ended".localized
            views.append(statusPill(status))
        }
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        if views.count > 2 { stack.setCustomSpacing(16, after: tagline) }
        return stack
    }()

    private func statusPill(_ text: String) -> UIView {
        let pill = UIView()
        pill.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        pill.layer.cornerRadius = 14
        let text = label(text, size: 13, weight: .semibold, color: .white, lines: 1, align: .center)
        pin(text, in: pill, insets: UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14))
        return pill
    }

    // MARK: Checklist

    private lazy var checklist: UIStackView = {
        let items = [
            "Unlimited PDF uploads".localized,
            "Every page-turn modality".localized,
            "PDF annotation & markup".localized,
            "Performance mode with automatic page turning".localized,
        ]
        let rows = items.map { text -> UIView in
            let check = UIImageView(image: UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)))
            check.tintColor = Theme.accent
            check.contentMode = .scaleAspectFit
            check.setContentHuggingPriority(.required, for: .horizontal)
            check.widthAnchor.constraint(equalToConstant: 18).isActive = true
            let row = UIStackView(arrangedSubviews: [check, label(text, size: 15, weight: .medium)])
            row.spacing = 12
            row.alignment = .firstBaseline
            return row
        }
        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.spacing = 12
        return stack
    }()

    // MARK: Plan cards

    private var selectedPlan: SubscriptionStore.Plan = .yearly {
        didSet { monthlyCard.isSelected = selectedPlan == .monthly; yearlyCard.isSelected = selectedPlan == .yearly }
    }

    private lazy var monthlyCard: PlanCardView = {
        let card = PlanCardView(title: "Monthly".localized, billed: "Billed monthly".localized)
        card.addAction(UIAction { [weak self] _ in self?.selectedPlan = .monthly }, for: .touchUpInside)
        return card
    }()

    private lazy var yearlyCard: PlanCardView = {
        let card = PlanCardView(title: "Yearly".localized, billed: "Billed yearly".localized)
        card.isSelected = true
        card.addAction(UIAction { [weak self] _ in self?.selectedPlan = .yearly }, for: .touchUpInside)
        return card
    }()

    private lazy var planRow: UIStackView = {
        let row = UIStackView(arrangedSubviews: [monthlyCard, yearlyCard])
        row.distribution = .fillEqually
        row.spacing = 12
        row.heightAnchor.constraint(equalToConstant: 128).isActive = true
        return row
    }()

    private lazy var trialNote: UILabel = label(
        "Your free trial needs no card. Subscribe any time.".localized,
        size: 13, weight: .medium, color: UIColor.white.withAlphaComponent(0.65), align: .center)

    // MARK: Subscribe + legal

    private lazy var subscribeButton: GradientButton = {
        let button = GradientButton(title: "Subscribe".localized)
        var config = button.configuration
        config?.image = UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold))
        config?.imagePlacement = .trailing
        config?.imagePadding = 8
        button.configuration = config
        button.addAction(UIAction { [weak self] _ in self?.subscribeTapped() }, for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 56).isActive = true
        button.layer.shadowOpacity = 0.35
        button.layer.shadowRadius = 16
        button.layer.shadowOffset = CGSize(width: 0, height: 8)
        return button
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private lazy var linksRow: UIStackView = {
        func link(_ title: String, _ url: URL) -> UIButton {
            let button = UIButton(type: .system, primaryAction: UIAction { _ in UIApplication.shared.open(url) })
            button.setTitle(title, for: .normal)
            button.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            return button
        }
        let row = UIStackView(arrangedSubviews: [link("Terms of Use".localized, LegalLinks.termsOfUse), link("Privacy Policy".localized, LegalLinks.privacyPolicy)])
        row.spacing = 24
        return row
    }()

    private lazy var legalLabel: UILabel = label(
        "Payment is charged to your Apple ID at confirmation. The subscription renews automatically each month or year, depending on your plan, unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings › Apple ID › Subscriptions.".localized,
        size: 11, color: UIColor.white.withAlphaComponent(0.5), align: .center)

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        setUpViews()
        refreshProductPrice()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private func setUpViews() {
        let backdrop = PaywallBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdrop)

        let bar = UIView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        restoreButton.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(closeButton)
        bar.addSubview(restoreButton)
        view.addSubview(bar)

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        func centred(_ content: UIView) -> UIStackView {
            let row = UIStackView(arrangedSubviews: [UIView(), content, UIView()])
            row.distribution = .equalCentering
            return row
        }
        var arranged: [UIView] = [headerStack, checklist, planRow, subscribeButton]
        if reason != .autoTurn && TrialManager.shared.isActive { arranged.append(trialNote) }
        arranged += [activityIndicator, centred(linksRow), legalLabel]
        let stack = UIStackView(arrangedSubviews: arranged)
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 16
        stack.setCustomSpacing(34, after: headerStack)
        stack.setCustomSpacing(30, after: checklist)
        stack.setCustomSpacing(4, after: activityIndicator)
        stack.setCustomSpacing(8, after: subscribeButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 48),
            closeButton.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 10),
            closeButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            restoreButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -10),
            restoreButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            scroll.topAnchor.constraint(equalTo: bar.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -24),
        ])
    }

    private func refreshProductPrice() {
        Task {
            await SubscriptionStore.shared.loadProducts()
            let store = SubscriptionStore.shared
            let monthly = store.product(for: .monthly)
            let yearly = store.product(for: .yearly)
            monthlyCard.setPrice(monthly?.displayPrice)
            yearlyCard.setPrice(yearly?.displayPrice)
            if let monthly, let yearly, monthly.price > 0 {
                let full = monthly.price * 12
                let saving = NSDecimalNumber(decimal: (full - yearly.price) / full * 100).intValue
                yearlyCard.setBadge(saving > 0 ? "Save %d%%".localized(saving) : nil)
            }
        }
    }

    private func subscribeTapped() {
        setLoading(true)
        Task {
            do {
                try await SubscriptionStore.shared.purchase(plan: selectedPlan)
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


/// A selectable plan card: title, big price, optional "Save x%" badge, billing note.
final class PlanCardView: UIControl {
    private let priceLabel = UILabel()
    private let badgeLabel = UILabel()
    private let titleLabel = UILabel()
    private let billedLabel = UILabel()
    private let checkBadge = UIImageView()

    init(title: String, billed: String) {
        super.init(frame: .zero)
        layer.cornerRadius = 18

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        priceLabel.text = "—"
        priceLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        priceLabel.textColor = .white
        priceLabel.adjustsFontSizeToFitWidth = true
        priceLabel.minimumScaleFactor = 0.7
        badgeLabel.font = .systemFont(ofSize: 11, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.textAlignment = .center
        badgeLabel.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        badgeLabel.isHidden = true
        billedLabel.text = billed
        billedLabel.font = .systemFont(ofSize: 12, weight: .medium)

        let badgeRow = UIStackView(arrangedSubviews: [badgeLabel, UIView()])
        let stack = UIStackView(arrangedSubviews: [titleLabel, priceLabel, badgeRow, UIView(), billedLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        checkBadge.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .regular))
        checkBadge.backgroundColor = Theme.background
        checkBadge.layer.cornerRadius = 12
        checkBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkBadge)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            checkBadge.centerXAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            checkBadge.centerYAnchor.constraint(equalTo: topAnchor, constant: 2),
        ])
        updateStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isSelected: Bool { didSet { updateStyle() } }

    func setPrice(_ text: String?) { priceLabel.text = text ?? "—" }

    func setBadge(_ text: String?) {
        badgeLabel.text = text.map { "  \($0)  " }
        badgeLabel.isHidden = text == nil
    }

    private func updateStyle() {
        backgroundColor = isSelected ? Theme.accent.withAlphaComponent(0.10) : Theme.card
        layer.borderWidth = isSelected ? 1.5 : 1
        layer.borderColor = (isSelected ? Theme.accent : Theme.hairline).cgColor
        titleLabel.textColor = isSelected ? Theme.accent : .secondaryLabel
        billedLabel.textColor = isSelected ? Theme.accent : .secondaryLabel
        checkBadge.tintColor = Theme.accent
        checkBadge.isHidden = !isSelected
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}
