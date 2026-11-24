import UIKit
import WebKit

/// YouTube uygulamasındaki gibi alttaki mini oynatıcı.
/// Videodan çıkınca video burada sürer: dokun = büyüt, yana kaydır veya ✕ = kapat.
final class MiniPlayerView: UIView {
    static let height: CGFloat = 64

    var onExpand: ((_ videoID: String, _ time: Double) -> Void)?
    var onClose: (() -> Void)?

    private let videoID: String
    private let webView: WKWebView
    private let titleLabel = UILabel()
    private let playButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private var isPlaying: Bool

    /// Sayfada sadece videoyu bırakır, onu pencereye sığdırır ve oynatır.
    private static func pageScript(autoplay: Bool) -> String {
        """
        (function () {
          var css = 'html, body { background: #000 !important; overflow: hidden !important; }' +
            'body * { visibility: hidden !important; }' +
            'video { visibility: visible !important; }' +
            '#player-container-id { position: fixed !important; inset: 0 !important; width: 100vw !important;' +
            ' height: 100vh !important; padding: 0 !important; margin: 0 !important; transform: none !important; }' +
            '#player-container-id #player, #movie_player, .html5-video-container { position: absolute !important;' +
            ' inset: 0 !important; width: 100% !important; height: 100% !important; padding: 0 !important; }' +
            'video.html5-main-video { position: absolute !important; inset: 0 !important; width: 100% !important;' +
            ' height: 100% !important; object-fit: cover !important; }';
          var style = document.createElement('style');
          style.textContent = css;
          (document.head || document.documentElement).appendChild(style);
          if (!\(autoplay)) return;
          var tries = 0;
          var timer = setInterval(function () {
            var v = document.querySelector('video');
            if (v && v.paused) { v.play().catch(function () {}); }
            if ((v && !v.paused) || ++tries > 60) clearInterval(timer);
          }, 250);
        })();
        """
    }

    init(videoID: String, time: Double, title: String, autoplay: Bool) {
        self.videoID = videoID
        self.isPlaying = autoplay

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"
        config.userContentController.addUserScript(
            WKUserScript(source: MiniPlayerView.pageScript(autoplay: autoplay), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: config)

        super.init(frame: .zero)
        buildLayout(title: title)

        let start = max(0, Int(time))
        if let url = URL(string: "https://m.youtube.com/watch?v=\(videoID)&t=\(start)s") {
            webView.load(URLRequest(url: url))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) kullanılmıyor")
    }

    // MARK: Görünüm

    private func buildLayout(title: String) {
        backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(white: 0.14, alpha: 1) : UIColor(white: 0.97, alpha: 1)
        }
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 3)

        let videoFrame = UIView()
        videoFrame.backgroundColor = .black
        videoFrame.layer.cornerRadius = 12
        videoFrame.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        videoFrame.clipsToBounds = true
        videoFrame.translatesAutoresizingMaskIntoConstraints = false
        addSubview(videoFrame)

        webView.isUserInteractionEnabled = false // dokunuşlar mini oynatıcıya gelsin
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        videoFrame.addSubview(webView)

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        configure(playButton, symbol: isPlaying ? "pause.fill" : "play.fill", label: "Oynat veya durdur")
        playButton.addTarget(self, action: #selector(togglePlay), for: .touchUpInside)
        configure(closeButton, symbol: "xmark", label: "Mini oynatıcıyı kapat")
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            videoFrame.leadingAnchor.constraint(equalTo: leadingAnchor),
            videoFrame.topAnchor.constraint(equalTo: topAnchor),
            videoFrame.bottomAnchor.constraint(equalTo: bottomAnchor),
            videoFrame.widthAnchor.constraint(equalTo: videoFrame.heightAnchor, multiplier: 16.0 / 9.0),

            webView.leadingAnchor.constraint(equalTo: videoFrame.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: videoFrame.trailingAnchor),
            webView.topAnchor.constraint(equalTo: videoFrame.topAnchor),
            webView.bottomAnchor.constraint(equalTo: videoFrame.bottomAnchor),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            playButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor),
            playButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 44),
            playButton.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.leadingAnchor.constraint(equalTo: videoFrame.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: playButton.leadingAnchor, constant: -4),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(expandTapped)))
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
    }

    private func configure(_ button: UIButton, symbol: String, label: String) {
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = .label
        button.accessibilityLabel = label
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
    }

    // MARK: Hareketler

    @objc private func togglePlay() {
        let js = "(function(){var v=document.querySelector('video');if(!v)return false;" +
            "if(v.paused){v.play();return true}v.pause();return false})()"
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self = self, let playing = result as? Bool else { return }
            self.isPlaying = playing
            self.playButton.setImage(UIImage(systemName: playing ? "pause.fill" : "play.fill"), for: .normal)
        }
    }

    @objc private func closeTapped() {
        dismiss(toLeft: false)
    }

    @objc private func expandTapped() {
        let js = "(function(){var v=document.querySelector('video');return v?v.currentTime:0})()"
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self = self else { return }
            let time = (result as? Double) ?? (result as? NSNumber)?.doubleValue ?? 0
            self.onExpand?(self.videoID, time)
        }
    }

    /// Yana kaydırınca kapanır.
    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let dx = pan.translation(in: superview).x
        switch pan.state {
        case .changed:
            transform = CGAffineTransform(translationX: dx, y: 0)
            alpha = max(0.3, 1 - abs(dx) / bounds.width)
        case .ended, .cancelled:
            if abs(dx) > bounds.width * 0.35 {
                dismiss(toLeft: dx < 0)
            } else {
                UIView.animate(withDuration: 0.2) {
                    self.transform = .identity
                    self.alpha = 1
                }
            }
        default:
            break
        }
    }

    private func dismiss(toLeft: Bool) {
        let distance = (superview?.bounds.width ?? 400) * (toLeft ? -1 : 1)
        UIView.animate(withDuration: 0.2, animations: {
            self.transform = CGAffineTransform(translationX: distance, y: 0)
            self.alpha = 0
        }, completion: { _ in
            self.onClose?()
        })
    }

    /// Sesi hemen keser; görünümden kaldırmadan önce çağrılır.
    func stop() {
        webView.pauseAllMediaPlayback(completionHandler: nil)
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
    }
}
