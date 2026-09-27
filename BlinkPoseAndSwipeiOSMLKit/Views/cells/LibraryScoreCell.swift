import UIKit

final class LibraryScoreCell: UICollectionViewCell {
    static let identifier = "LibraryScoreCell"

    /// Height of the text under the thumbnail.
    static let captionHeight: CGFloat = 58
    /// Sheet music is close to A4, so the thumbnail box matches it.
    static let thumbnailRatio: CGFloat = 1.4

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 10
        view.layer.borderColor = Theme.hairline.cgColor
        view.layer.borderWidth = 1
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.55
        view.layer.shadowRadius = 12
        view.layer.shadowOffset = CGSize(width: 0, height: 6)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let thumbnailView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 10
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let modalityIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = Theme.accent
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let modalityLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailView.image = nil
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            }
        }
    }

    private func setUpViews() {
        contentView.addSubview(cardView)
        cardView.addSubview(thumbnailView)
        contentView.addSubview(titleLabel)
        let modalityStack = UIStackView(arrangedSubviews: [modalityIcon, modalityLabel])
        modalityStack.axis = .horizontal
        modalityStack.spacing = 5
        modalityStack.alignment = .center
        modalityStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(modalityStack)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.heightAnchor.constraint(equalTo: cardView.widthAnchor, multiplier: Self.thumbnailRatio),

            thumbnailView.topAnchor.constraint(equalTo: cardView.topAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),

            titleLabel.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),

            modalityStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            modalityStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            modalityIcon.widthAnchor.constraint(equalToConstant: 14),
            modalityIcon.heightAnchor.constraint(equalToConstant: 14),
        ])
    }

    func configure(with score: Score, thumbnail: UIImage?) {
        thumbnailView.image = thumbnail
        titleLabel.text = score.isBuiltIn ? score.title.localized : score.title
        modalityLabel.text = score.preferredModality.displayName
        modalityIcon.image = UIImage(named: "modality-\(score.preferredModality.rawValue)")
    }
}
