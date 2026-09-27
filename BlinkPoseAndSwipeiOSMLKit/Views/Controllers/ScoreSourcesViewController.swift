import UIKit

// Where players can browse free sheet music online. Each source opens in
// ScoreWebViewController, which lets the user add any PDF they download
// straight to their Library. PageTurn only opens the public sites; it does
// not host, copy or redistribute anything from them.
final class ScoreSourcesViewController: UITableViewController {

    struct Source {
        let title: String
        let detail: String
        let symbol: String
        let url: URL
    }

    private let sources: [Source] = [
        Source(title: "IMSLP",
               detail: "The Petrucci Music Library: hundreds of thousands of public-domain scores.".localized,
               symbol: "books.vertical", url: URL(string: "https://imslp.org")!),
        Source(title: "Mutopia Project",
               detail: "Free-to-print classical scores, carefully typeset and openly licensed.".localized,
               symbol: "music.quarternote.3", url: URL(string: "https://www.mutopiaproject.org")!),
        Source(title: "CPDL",
               detail: "The Choral Public Domain Library: choral and vocal music.".localized,
               symbol: "person.3", url: URL(string: "https://www.cpdl.org")!),
    ]

    private let onImported: () -> Void

    init(onImported: @escaping () -> Void) {
        self.onImported = onImported
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Browse Scores".localized
        view.backgroundColor = Theme.background
        tableView.backgroundColor = Theme.background
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
    }

    @objc private func closeTapped() { dismiss(animated: true) }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "PageTurn isn't affiliated with these sites. Only download scores that are in the public domain or that you have the right to use.".localized
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sources.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let source = sources[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var content = UIListContentConfiguration.subtitleCell()
        content.text = source.title
        content.textProperties.font = .systemFont(ofSize: 17, weight: .semibold)
        content.secondaryText = source.detail
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.numberOfLines = 0
        content.image = UIImage(systemName: source.symbol)
        content.imageProperties.tintColor = Theme.accent
        cell.contentConfiguration = content
        cell.backgroundColor = Theme.card
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let source = sources[indexPath.row]
        navigationController?.pushViewController(ScoreWebViewController(title: source.title, url: source.url, onImported: onImported), animated: true)
    }
}
