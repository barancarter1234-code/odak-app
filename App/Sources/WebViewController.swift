import UIKit
import WebKit

/// Siteyi tam ekran açar (adres çubuğu yok) ve Odak script'ini her sayfaya ekler.
final class WebViewController: UIViewController {
    /// Uygulama içinde açılan alan adları. Diğer bağlantılar Safari'de açılır.
    private static let allowedHosts = [
        "instagram.com", "facebook.com",
        "youtube.com", "youtu.be", "google.com", "google.com.tr",
    ]

    private let webView: WKWebView
    private let startURL: URL

    init() {
        let host = Bundle.main.object(forInfoDictionaryKey: "OdakStartHost") as? String ?? "www.instagram.com"
        startURL = URL(string: "https://\(host)/") ?? URL(string: "https://www.instagram.com/")!

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // girişler ve ayarlar kalıcı
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // Siteler bizi normal mobil Safari sansın (Google girişi ve tam mobil site için)
        config.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"

        webView = WKWebView(frame: .zero, configuration: config)
        super.init(nibName: nil, bundle: nil)
        install(script: ScriptStore.current())
        // Script'ten gelen mesajlar (mini oynatıcı için)
        config.userContentController.add(WeakScriptMessageHandler(self), name: "odak")
    }

    private var lastUpdateCheck = Date.distantPast
    private var miniPlayer: MiniPlayerView?
    private var colorObservations: [NSKeyValueObservation] = []
    private var statusBarStyle: UIStatusBarStyle = .default

    override var preferredStatusBarStyle: UIStatusBarStyle { statusBarStyle }

    /// Odak script'ini her sayfanın başına ekler (önceki sürümün yerine).
    private func install(script source: String) {
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        guard !source.isEmpty else { return }
        controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    }

    /// GitHub'da yeni script varsa kurar ve sayfayı bir kez yeniler. En fazla 15 dakikada bir bakar.
    @objc private func checkForScriptUpdate() {
        guard Date().timeIntervalSince(lastUpdateCheck) > 15 * 60 else { return }
        lastUpdateCheck = Date()
        ScriptStore.fetchUpdate { [weak self] update in
            guard let self = self, let update = update else { return }
            self.install(script: update)
            self.webView.reload()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) kullanılmıyor")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true // kenardan kaydırarak geri
        webView.allowsLinkPreview = false // basılı tutunca bağlantı önizlemesi açılmasın (yerli uygulama gibi)
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        view.addSubview(webView)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: guide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        webView.load(URLRequest(url: startURL))

        // Üst ve alt şeritler sayfanın rengini alsın (siyah şerit kalmasın)
        colorObservations = [
            webView.observe(\.themeColor, options: [.new]) { [weak self] _, _ in self?.updateBarColors() },
            webView.observe(\.underPageBackgroundColor, options: [.new]) { [weak self] _, _ in self?.updateBarColors() },
        ]

        checkForScriptUpdate()
        NotificationCenter.default.addObserver(
            self, selector: #selector(checkForScriptUpdate),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    /// Durum çubuğu ve alt şerit rengini sayfanın üst rengine eşitler.
    private func updateBarColors() {
        var color: UIColor = webView.underPageBackgroundColor ?? .systemBackground
        // Sayfanın bildirdiği renk saydamsa (YouTube izleme sayfası gibi) arka plan rengini kullan
        if let theme = webView.themeColor, alphaOf(theme) > 0.5 {
            color = theme
        }
        view.backgroundColor = color
        webView.backgroundColor = color
        webView.scrollView.backgroundColor = color

        let style: UIStatusBarStyle = luminanceOf(color) < 0.5 ? .lightContent : .darkContent
        if style != statusBarStyle {
            statusBarStyle = style
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    private func components(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.resolvedColor(with: traitCollection).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    private func alphaOf(_ color: UIColor) -> CGFloat {
        components(color).a
    }

    private func luminanceOf(_ color: UIColor) -> CGFloat {
        let c = components(color)
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateBarColors()
    }

    // MARK: Instagram hesap değiştirme

    private var isInstagram: Bool {
        startURL.host?.contains("instagram.com") ?? false
    }

    /// Profil fotoğrafına basılı tutunca açılan hesap listesi.
    private func showAccountSheet() {
        guard isInstagram, presentedViewController == nil else { return }
        let manager = AccountManager.shared
        let sheet = AccountSheetController(accounts: manager.accounts, current: manager.current)
        sheet.onSelect = { [weak self] username in self?.switchAccount(to: username) }
        sheet.onAdd = { [weak self] in self?.addAccount() }
        sheet.onRemove = { username in manager.remove(username: username) }

        let navigation = UINavigationController(rootViewController: sheet)
        if let presentation = navigation.sheetPresentationController {
            presentation.detents = [.medium(), .large()]
            presentation.prefersGrabberVisible = true
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        present(navigation, animated: true)
    }

    private func switchAccount(to username: String) {
        let cookies = webView.configuration.websiteDataStore.httpCookieStore
        AccountManager.shared.switchAccount(to: username, cookieStore: cookies) { [weak self] in
            guard let url = URL(string: "https://www.instagram.com/") else { return }
            self?.webView.load(URLRequest(url: url))
        }
    }

    private func addAccount() {
        let cookies = webView.configuration.websiteDataStore.httpCookieStore
        AccountManager.shared.prepareNewLogin(cookieStore: cookies) { [weak self] in
            guard let url = URL(string: "https://www.instagram.com/accounts/login/") else { return }
            self?.webView.load(URLRequest(url: url))
        }
    }

    // MARK: Mini oynatıcı

    private func showMiniPlayer(videoID: String, time: Double, title: String, playing: Bool) {
        closeMiniPlayer()
        let mini = MiniPlayerView(videoID: videoID, time: time, title: title, autoplay: playing)
        mini.onClose = { [weak self] in self?.closeMiniPlayer() }
        mini.onExpand = { [weak self] id, time in
            guard let self = self else { return }
            self.closeMiniPlayer()
            if let url = URL(string: "https://m.youtube.com/watch?v=\(id)&t=\(max(0, Int(time)))s") {
                self.webView.load(URLRequest(url: url))
            }
        }
        mini.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mini)
        NSLayoutConstraint.activate([
            mini.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            mini.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            // YouTube'un alt menüsünün hemen üstü
            mini.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -56),
            mini.heightAnchor.constraint(equalToConstant: MiniPlayerView.height),
        ])
        mini.alpha = 0
        mini.transform = CGAffineTransform(translationX: 0, y: 30)
        UIView.animate(withDuration: 0.25) {
            mini.alpha = 1
            mini.transform = .identity
        }
        miniPlayer = mini
    }

    private func closeMiniPlayer() {
        guard let mini = miniPlayer else { return }
        mini.stop()
        mini.removeFromSuperview()
        miniPlayer = nil
    }

    @objc private func pullToRefresh() {
        webView.reload()
    }

    private func stopRefreshing() {
        webView.scrollView.refreshControl?.endRefreshing()
    }

    static func isAllowedHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return allowedHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// JavaScript uyarılarını gösterir; ekranda başka pencere varsa hemen vazgeçer.
    private func presentAlert(_ alert: UIAlertController, otherwise fallback: () -> Void) {
        guard presentedViewController == nil, viewIfLoaded?.window != nil else {
            fallback()
            return
        }
        present(alert, animated: true)
    }
}

// MARK: - Gezinme

extension WebViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else {
            decisionHandler(.allow)
            return
        }
        switch scheme {
        case "http", "https":
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
            if isMainFrame && !Self.isAllowedHost(url.host) {
                UIApplication.shared.open(url) // dış bağlantı: Safari
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        case "about", "blob", "data":
            decisionHandler(.allow)
        case "mailto", "tel", "sms":
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        default:
            // instagram://, youtube:// gibi gerçek uygulamayı açmaya çalışan bağlantılar
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        stopRefreshing()
        updateBarColors()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        stopRefreshing()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        stopRefreshing()
    }

    // Web içeriği bellek yüzünden kapanırsa sayfayı yeniden yükle
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

// MARK: - Pencereler ve uyarılar

extension WebViewController: WKUIDelegate {
    // target="_blank" bağlantıları aynı ekranda aç
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            if Self.isAllowedHost(url.host) {
                webView.load(navigationAction.request)
            } else {
                UIApplication.shared.open(url)
            }
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Tamam", style: .default) { _ in completionHandler() })
        presentAlert(alert) { completionHandler() }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Vazgeç", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "Evet", style: .default) { _ in completionHandler(true) })
        presentAlert(alert) { completionHandler(false) }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Vazgeç", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "Tamam", style: .default) { [weak alert] _ in
            completionHandler(alert?.textFields?.first?.text)
        })
        presentAlert(alert) { completionHandler(nil) }
    }

    // Kamera/mikrofon: sadece izinli sitelere
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        decisionHandler(Self.isAllowedHost(origin.host) ? .grant : .deny)
    }
}

// MARK: - Script mesajları

extension WebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "mini":
            // Video kimliği sadece harf, rakam, - ve _ olabilir
            guard let id = body["id"] as? String, !id.isEmpty,
                  id.range(of: "^[A-Za-z0-9_-]{1,20}$", options: .regularExpression) != nil else { return }
            let time = (body["time"] as? NSNumber)?.doubleValue ?? 0
            let title = body["title"] as? String ?? ""
            let playing = body["playing"] as? Bool ?? true
            showMiniPlayer(videoID: id, time: time, title: title, playing: playing)
        case "watch":
            closeMiniPlayer()
        case "igProfile":
            // Instagram kullanıcı adı: harf, rakam, nokta, alt çizgi
            guard isInstagram, let username = body["username"] as? String,
                  username.range(of: "^[A-Za-z0-9._]{1,30}$", options: .regularExpression) != nil else { return }
            AccountManager.shared.didSeeProfile(username: username, avatarURL: body["avatar"] as? String)
        case "accounts":
            showAccountSheet()
        default:
            break
        }
    }
}

/// Mesaj işleyicisini zayıf tutar; WKUserContentController onu güçlü tuttuğu için döngü oluşmasın.
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
