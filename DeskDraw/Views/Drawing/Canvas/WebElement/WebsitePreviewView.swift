import UIKit
import LinkPresentation

struct WebsiteMetadata {
  let title: String
  let urlString: String
  let icon: UIImage?
}

/// A compact website preview card that shows site icon, title and URL text.
final class WebsitePreviewView: UIView {
  /// Called when metadata has finished loading (success or error). Passes title and icon as Data for persistence.
  var onMetadataLoaded: ((_ title: String, _ iconData: Data?) -> Void)?

  private let imageView = UIImageView()
  private let titleLabel = UILabel()
  private let urlLabel = UILabel()
  private let logoContainerView = UIView()
  private let stackView = UIStackView()
  private let blurView: UIVisualEffectView

  override init(frame: CGRect) {
    let blurEffect = UIBlurEffect(style: .systemThinMaterialDark)
    blurView = UIVisualEffectView(effect: blurEffect)
    super.init(frame: frame)
    setupView()
  }

  required init?(coder: NSCoder) {
    let blurEffect = UIBlurEffect(style: .systemThinMaterialDark)
    blurView = UIVisualEffectView(effect: blurEffect)
    super.init(coder: coder)
    setupView()
  }

  private func setupView() {
    clipsToBounds = true
    layer.cornerRadius = 12

    blurView.frame = bounds
    blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(blurView)

    imageView.contentMode = .scaleAspectFit
    imageView.tintColor = .white
    imageView.layer.cornerRadius = 8
    imageView.clipsToBounds = true
    imageView.translatesAutoresizingMaskIntoConstraints = false

    logoContainerView.translatesAutoresizingMaskIntoConstraints = false
    logoContainerView.addSubview(imageView)

    titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
    titleLabel.textColor = .white
    titleLabel.numberOfLines = 1

    urlLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
    urlLabel.textColor = UIColor.white.withAlphaComponent(0.8)
    urlLabel.numberOfLines = 1

    let textStack = UIStackView(arrangedSubviews: [titleLabel, urlLabel])
    textStack.axis = .vertical
    textStack.alignment = .leading
    textStack.spacing = 0

    stackView.axis = .vertical
    stackView.alignment = .fill
    stackView.spacing = 4
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.addArrangedSubview(logoContainerView)
    stackView.addArrangedSubview(textStack)

    logoContainerView.setContentHuggingPriority(.defaultLow, for: .vertical)
    textStack.setContentHuggingPriority(.required, for: .vertical)

    blurView.contentView.addSubview(stackView)

    NSLayoutConstraint.activate([
      stackView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 12),
      stackView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -12),
      stackView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 8),
      stackView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -8),

      logoContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),

      imageView.widthAnchor.constraint(equalToConstant: 48),
      imageView.heightAnchor.constraint(equalToConstant: 48),
      imageView.centerXAnchor.constraint(equalTo: logoContainerView.centerXAnchor),
      imageView.centerYAnchor.constraint(equalTo: logoContainerView.centerYAnchor),
    ])

    setLoadingState()
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
}

