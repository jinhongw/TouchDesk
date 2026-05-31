import UIKit
import LinkPresentation
import WebKit

struct WebsiteMetadata {
  let title: String
  let urlString: String
  let icon: UIImage?
}

/// A compact website preview card that shows site icon, title and URL text.
final class WebsitePreviewView: UIView, WKUIDelegate {
  /// Called when metadata has finished loading (success or error). Passes title and icon as Data for persistence.
  var onMetadataLoaded: ((_ title: String, _ iconData: Data?) -> Void)?

  private let imageView = UIImageView()
  private let titleLabel = UILabel()
  private let urlLabel = UILabel()
  private let textStack = UIStackView()
  private let blurView: UIVisualEffectView
  private let webView: WKWebView
  private var currentURL: URL?
  private var isPreviewEnabled = false

  override init(frame: CGRect) {
    let blurEffect = UIBlurEffect(style: .systemThinMaterialDark)
    blurView = UIVisualEffectView(effect: blurEffect)
    webView = Self.makePreviewWebView()
    super.init(frame: frame)
    setupView()
  }

  required init?(coder: NSCoder) {
    let blurEffect = UIBlurEffect(style: .systemThinMaterialDark)
    blurView = UIVisualEffectView(effect: blurEffect)
    webView = Self.makePreviewWebView()
    super.init(coder: coder)
    setupView()
  }

  private static func makePreviewWebView() -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = true
    configuration.allowsAirPlayForMediaPlayback = true
    configuration.mediaTypesRequiringUserActionForPlayback = []
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.allowsBackForwardNavigationGestures = true
    webView.backgroundColor = .clear
    webView.isOpaque = false
    return webView
  }

  private func setupView() {
    clipsToBounds = true
    layer.cornerRadius = 12

    blurView.frame = bounds
    blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(blurView)

    webView.frame = bounds
    webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    webView.uiDelegate = self
    webView.isHidden = true
    addSubview(webView)

    imageView.contentMode = .scaleAspectFit
    imageView.tintColor = .white
    imageView.layer.cornerRadius = 8
    imageView.clipsToBounds = true
    imageView.translatesAutoresizingMaskIntoConstraints = false

    titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
    titleLabel.textColor = .white
    titleLabel.numberOfLines = 1

    urlLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
    urlLabel.textColor = UIColor.white.withAlphaComponent(0.8)
    urlLabel.numberOfLines = 1

    textStack.axis = .vertical
    textStack.alignment = .leading
    textStack.spacing = 0
    textStack.translatesAutoresizingMaskIntoConstraints = false
    textStack.addArrangedSubview(titleLabel)
    textStack.addArrangedSubview(urlLabel)

    textStack.setContentHuggingPriority(.required, for: .vertical)

    blurView.contentView.addSubview(textStack)
    blurView.contentView.addSubview(imageView)

    NSLayoutConstraint.activate([
      textStack.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 12),
      textStack.trailingAnchor.constraint(lessThanOrEqualTo: blurView.contentView.trailingAnchor, constant: -12),
      textStack.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
      textStack.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -12),

      imageView.widthAnchor.constraint(equalToConstant: 48),
      imageView.heightAnchor.constraint(equalToConstant: 48),
      imageView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 12),
      imageView.topAnchor.constraint(greaterThanOrEqualTo: blurView.contentView.topAnchor, constant: 12),
    ])

    setLoadingState()
  }

  func webView(
    _ webView: WKWebView,
    createWebViewWith configuration: WKWebViewConfiguration,
    for navigationAction: WKNavigationAction,
    windowFeatures: WKWindowFeatures
  ) -> WKWebView? {
    if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
      webView.load(URLRequest(url: url))
    }
    return nil
  }

  func setPreviewEnabled(_ enabled: Bool) {
    isPreviewEnabled = enabled
    blurView.isHidden = enabled
    webView.isHidden = !enabled
    guard enabled else { return }
    loadCurrentURLInPreviewIfNeeded(force: false)
  }

  /// True when we are showing persisted metadata (not loading and not error).
  private var hasCachedContent: Bool {
    let t = titleLabel.text
    return t != nil && t != "Loading..." && t != "Failed to load"
  }

  private func setLoadingState() {
    imageView.image = UIImage(systemName: "globe")
    titleLabel.text = "Loading..."
    urlLabel.text = nil
  }

  private func setErrorState(for url: URL) {
    imageView.image = UIImage(systemName: "exclamationmark.triangle")
    titleLabel.text = "Failed to load"
    urlLabel.text = url.host ?? url.absoluteString
    onMetadataLoaded?(titleLabel.text ?? "Failed to load", nil)
  }

  func configure(with metadata: WebsiteMetadata) {
    if let icon = metadata.icon {
      imageView.image = icon
    } else {
      imageView.image = UIImage(systemName: "globe")
    }
    titleLabel.text = metadata.title
    urlLabel.text = metadata.urlString
    let iconData = metadata.icon?.pngData()
    onMetadataLoaded?(metadata.title, iconData)
  }

  /// Show persisted metadata immediately (e.g. when opening a drawing) before load(from:) completes.
  func configureWithCached(title: String?, iconData: Data?, urlString: String?) {
    if let iconData, let icon = UIImage(data: iconData) {
      imageView.image = icon
    } else {
      imageView.image = UIImage(systemName: "globe")
    }
    titleLabel.text = title ?? "Loading..."
    urlLabel.text = urlString ?? nil
  }

  func load(from url: URL, forceLoadingState: Bool = false) {
    currentURL = url
    loadCurrentURLInPreviewIfNeeded(force: forceLoadingState)

    if forceLoadingState || titleLabel.text == nil || titleLabel.text == "Loading..." {
      setLoadingState()
    }

    // LPMetadataProvider is a one-shot object; create a new instance per fetch.
    let provider = LPMetadataProvider()
    provider.startFetchingMetadata(for: url) { [weak self] linkMetadata, error in
      DispatchQueue.main.async {
        guard let self = self else { return }

        if let error = error {
          print(#function, "Failed to fetch metadata: \(error.localizedDescription)")
          if !self.hasCachedContent {
            self.setErrorState(for: url)
          }
          return
        }

        guard let linkMetadata = linkMetadata else {
          if !self.hasCachedContent {
            self.setErrorState(for: url)
          }
          return
        }

        var iconImage: UIImage?
        if let imageProvider = linkMetadata.imageProvider {
          imageProvider.loadObject(ofClass: UIImage.self) { object, _ in
            DispatchQueue.main.async {
              if let image = object as? UIImage {
                iconImage = image
              }
              let title = linkMetadata.title ?? (url.host ?? url.absoluteString)
              let metadata = WebsiteMetadata(
                title: title,
                urlString: url.absoluteString,
                icon: iconImage
              )
              self.configure(with: metadata)
            }
          }
        } else if let iconProvider = linkMetadata.iconProvider {
          iconProvider.loadObject(ofClass: UIImage.self) { object, _ in
            DispatchQueue.main.async {
              if let image = object as? UIImage {
                iconImage = image
              }
              let title = linkMetadata.title ?? (url.host ?? url.absoluteString)
              let metadata = WebsiteMetadata(
                title: title,
                urlString: url.absoluteString,
                icon: iconImage
              )
              self.configure(with: metadata)
            }
          }
        } else {
          let title = linkMetadata.title ?? (url.host ?? url.absoluteString)
          let metadata = WebsiteMetadata(
            title: title,
            urlString: url.absoluteString,
            icon: nil
          )
          self.configure(with: metadata)
        }
      }
    }
  }

  private func loadCurrentURLInPreviewIfNeeded(force: Bool) {
    guard isPreviewEnabled, let currentURL else { return }
    guard force || webView.url != currentURL else { return }
    webView.load(URLRequest(url: currentURL))
  }
}
