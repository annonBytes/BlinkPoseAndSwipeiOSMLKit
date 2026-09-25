import UIKit

final class LibraryScoreCell: UICollectionViewCell {
    static let identifier = "LibraryScoreCell"

    private let thumbnailView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .secondarySystemBackground
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let modalityLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
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

    private func setUpViews() {
        contentView.addSubview(thumbnailView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(modalityLabel)

        NSLayoutConstraint.activate([
            thumbnailView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailView.heightAnchor.constraint(equalTo: thumbnailView.widthAnchor, multiplier: 1.3),

            titleLabel.topAnchor.constraint(equalTo: thumbnailView.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            modalityLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            modalityLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            modalityLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    func configure(with score: Score, thumbnail: UIImage?) {
        thumbnailView.image = thumbnail
        titleLabel.text = score.isBuiltIn ? score.title.localized : score.title
        modalityLabel.text = score.preferredModality.displayName
    }
}
