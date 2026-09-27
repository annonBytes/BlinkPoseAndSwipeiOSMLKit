import UIKit
import WebKit

// A small in-app browser for score sites. Any PDF the user opens or taps
// "download" on is intercepted, saved to a temporary file, and offered as an
// addition to the Library.
final class ScoreWebViewController: UIViewController, WKNavigationDelegate, WKDownloadDelegate {

    private let startURL: URL
    private let onImported: () -> Void
    private let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    private let progress = UIProgressView(progressViewStyle: .bar)
    private var progressObservation: NSKeyValueObservation?
    private var downloadDestination: URL?

    private lazy var backItem = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: webView, action: #selector(WKWebView.goBack))
    private lazy var forwardItem = UIBarButtonItem(image: UIImage(systemName: "chevron.right"), style: .plain, target: webView, action: #selector(WKWebView.goForward))
    private lazy var reloadItem = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: webView, action: #selector(WKWebView.reload))

    init(title: String, url: URL, onImported: @escaping () -> Void) {
        startURL = url
        self.onImported = onImported
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.progressTintColor = Theme.accent
        view.addSubview(progress)

        NSLayoutConstraint.activate([
            progress.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progress.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] web, _ in
            self?.progress.progress = Float(web.estimatedProgress)
            self?.progress.isHidden = web.estimatedProgress >= 1
        }

        navigationItem.rightBarButtonItems = [reloadItem, forwardItem, backItem]
        updateButtons()
        webView.load(URLRequest(url: startURL))
    }

    private func updateButtons() {
        backItem.isEnabled = webView.canGoBack
        forwardItem.isEnabled = webView.canGoForward
    }

    // MARK: Navigation

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { updateButtons() }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let isPDF = navigationResponse.response.mimeType == "application/pdf"
        let isAttachment = (navigationResponse.response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Disposition")?.lowercased().contains("attachment") == true
        decisionHandler(isPDF || isAttachment || !navigationResponse.canShowMIMEType ? .download : .allow)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { download.delegate = self }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { download.delegate = self }

    // MARK: Downloads

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(suggestedFilename)
        downloadDestination = destination
        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let file = downloadDestination else { return }
        downloadDestination = nil
        guard file.pathExtension.lowercased() == "pdf" else {
            present(message: "Only PDF scores can be added to your Library.".localized)
            return
        }
        guard EntitlementManager.hasUnlimitedAccess else {
            present(UINavigationController(rootViewController: PaywallViewController()), animated: true)
            return
        }
        do {
            let score = try ScoreLibrary.shared.importPDF(at: file)
            try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
            Theme.success()
            onImported()
            present(message: "Added “%@” to your Library.".localized(score.title))
        } catch {
            present(message: error.localizedDescription)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        present(message: error.localizedDescription)
    }

    private func present(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default))
        present(alert, animated: true)
    }
}
