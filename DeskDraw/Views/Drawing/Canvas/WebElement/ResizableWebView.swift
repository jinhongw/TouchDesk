import WebKit
import UIKit

class ResizableWebView: UIView, UIGestureRecognizerDelegate {
  let controlPointTouchSize: CGFloat = 32
  private let controlPointVisualSize: CGFloat = 10
  private let controlPointBorderWidth: CGFloat = 2
  private let toolButtonSize: CGFloat = 23
  private let fullscreenSafeMargin: CGFloat = 12
  private var controlPoints: [ControlPointView] = []
  private var previewView: WebsitePreviewView
  private var deleteButton: UIButton
  private var fullscreenButton: UIButton
  private var dragStartPoint: CGPoint?
  private let minimumDragDistance: CGFloat = 5.0

  var isLocked: Bool = false {
    didSet { updateInteractionState() }
  }

  var webId: UUID?
  var onSizeChanged: ((CGSize) -> Void)?
  var onPositionChanged: ((CGPoint) -> Void)?
  var onTapped: (() -> Void)?
  var onQuickSelected: (() -> Void)?
  var onDelete: (() -> Void)?
  var onEnterFullScreen: (() -> Void)?
  /// Called when the preview card has finished loading (metadata or error). Passes title and iconData for persistence.
  var onPreviewLoaded: ((_ title: String, _ iconData: Data?) -> Void)?

  var isSelectorActive: Bool = false {
    didSet { updateInteractionState() }
  }

  var editingId: UUID? {
    didSet { updateInteractionState() }
  }

  private func updateInteractionState() {
    let shouldShowControls = (isSelectorActive || webId == editingId) && !isLocked
    controlPoints.forEach { $0.isHidden = !shouldShowControls }
    updateDragGesture()
    updateDeleteButtonVisibility()
    fullscreenButton.isHidden = false
  }

  private func updateDeleteButtonVisibility() {
    deleteButton.isHidden = !(isSelectorActive || webId == editingId) || isLocked
  }

  private func updateDragGesture() {
    gestureRecognizers?.forEach { gesture in
      if gesture is UIPanGestureRecognizer {
        gesture.isEnabled = (isSelectorActive || webId == editingId) && !isLocked
      }
    }
    layer.zPosition = ((isSelectorActive || webId == editingId) && !isLocked) ? 1 : -1
  }

  init(url: String, size: CGSize, cachedTitle: String? = nil, cachedIconData: Data? = nil) {
    previewView = WebsitePreviewView(frame: .zero)
    deleteButton = UIButton(type: .system)
    fullscreenButton = UIButton(type: .system)

    super.init(frame: .zero)
    backgroundColor = .clear
    isMultipleTouchEnabled = true

    previewView.backgroundColor = .clear
    previewView.frame = CGRect(
      x: controlPointTouchSize / 2,
      y: controlPointTouchSize / 2,
      width: size.width,
      height: size.height
    )
    addSubview(previewView)
    previewView.onMetadataLoaded = { [weak self] title, iconData in
      self?.onPreviewLoaded?(title, iconData)
    }

    if cachedTitle != nil || cachedIconData != nil {
      previewView.configureWithCached(title: cachedTitle, iconData: cachedIconData, urlString: url)
    }
    if let u = URL(string: url) {
      previewView.load(from: u)
    }

    deleteButton.frame = CGRect(x: 0, y: 0, width: toolButtonSize, height: toolButtonSize)
    deleteButton.isHidden = true

    let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
    let blurView = UIVisualEffectView(effect: blurEffect)
    blurView.frame = deleteButton.bounds
    blurView.layer.cornerRadius = toolButtonSize / 2
    blurView.clipsToBounds = true
    blurView.isUserInteractionEnabled = false
    deleteButton.insertSubview(blurView, at: 0)

    var configButton = UIButton.Configuration.plain()
    configButton.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 10, weight: .regular)
    configButton.image = UIImage(systemName: "trash")
    configButton.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 0.5, bottom: 0, trailing: 0)
    configButton.baseForegroundColor = .white
    deleteButton.configuration = configButton

    deleteButton.contentVerticalAlignment = .center
    deleteButton.contentHorizontalAlignment = .center
    deleteButton.imageView?.contentMode = .center
    deleteButton.tintColor = .white
    deleteButton.layer.cornerRadius = toolButtonSize / 2
    deleteButton.clipsToBounds = true

    addSubview(deleteButton)
    deleteButton.addTarget(self, action: #selector(handleDelete), for: .touchUpInside)

    // Fullscreen button setup (always visible at top-right inside card)
    fullscreenButton.frame = CGRect(x: 0, y: 0, width: toolButtonSize, height: toolButtonSize)
    let fullscreenBlurView = UIVisualEffectView(effect: blurEffect)
    fullscreenBlurView.frame = fullscreenButton.bounds
    fullscreenBlurView.layer.cornerRadius = toolButtonSize / 2
    fullscreenBlurView.clipsToBounds = true
    fullscreenBlurView.isUserInteractionEnabled = false
    fullscreenButton.insertSubview(fullscreenBlurView, at: 0)

    var fullscreenConfig = UIButton.Configuration.plain()
    fullscreenConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 10, weight: .regular)
    fullscreenConfig.image = UIImage(systemName: "arrow.up.left.and.arrow.down.right")
    fullscreenConfig.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 0.5, bottom: 0, trailing: 0)
    fullscreenConfig.baseForegroundColor = .white
    fullscreenButton.configuration = fullscreenConfig

    fullscreenButton.contentVerticalAlignment = .center
    fullscreenButton.contentHorizontalAlignment = .center
    fullscreenButton.imageView?.contentMode = .center
    fullscreenButton.tintColor = .white
    fullscreenButton.layer.cornerRadius = toolButtonSize / 2
    fullscreenButton.clipsToBounds = true
    addSubview(fullscreenButton)
    fullscreenButton.addTarget(self, action: #selector(handleEnterFullScreen), for: .touchUpInside)

    setupControlPoints()
    setupDragGesture()
    setupTapGesture()
    setupPinchGesture()
    updateInteractionState()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// Updates the preview content when the saved URL changes (e.g. after full-screen navigation).
  func updateURL(_ url: String) {
    if let u = URL(string: url) {
      previewView.load(from: u, forceLoadingState: true)
    }
  }

  private func setupControlPoints() {
    controlPoints.forEach { $0.removeFromSuperview() }
    controlPoints.removeAll()
    let inset = controlPointTouchSize / 2
    let positions = [
      CGPoint(x: inset, y: inset),
      CGPoint(x: bounds.width - inset, y: inset),
      CGPoint(x: inset, y: bounds.height - inset),
      CGPoint(x: bounds.width - inset, y: bounds.height - inset),
    ]

    for (index, position) in positions.enumerated() {
      let controlPoint = createControlPoint(at: position)
      controlPoint.tag = index
      controlPoint.isHidden = webId != editingId
      addSubview(controlPoint)
      controlPoints.append(controlPoint)

      let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleControlPointPan(_:)))
      panGesture.maximumNumberOfTouches = 1
      controlPoint.addGestureRecognizer(panGesture)
    }
  }

  private func createControlPoint(at position: CGPoint) -> ControlPointView {
    let controlPoint = ControlPointView(
      visualSize: controlPointVisualSize,
      touchSize: controlPointTouchSize
    )
    controlPoint.frame = CGRect(
      x: position.x - controlPointTouchSize / 2,
      y: position.y - controlPointTouchSize / 2,
      width: controlPointTouchSize,
      height: controlPointTouchSize
    )
    controlPoint.isUserInteractionEnabled = true
    return controlPoint
  }

  @objc private func handleDelete() {
    if !isLocked { onDelete?() }
  }

  @objc private func handleEnterFullScreen() {
    if !isLocked { onEnterFullScreen?() }
  }

  /// Renders the preview card (WebsitePreviewView) to an image for thumbnail cache. Call on main thread.
  func snapshotPreview() -> UIImage? {
    guard bounds.size.width > 0, bounds.size.height > 0 else { return nil }
    let inset = controlPointTouchSize / 2
    let cardSize = CGSize(width: bounds.width - inset * 2, height: bounds.height - inset * 2)
    guard cardSize.width > 0, cardSize.height > 0 else { return nil }
    let format = UIGraphicsImageRendererFormat()
    format.opaque = false
    let renderer = UIGraphicsImageRenderer(size: cardSize, format: format)
    return renderer.image { _ in
      previewView.drawHierarchy(in: CGRect(origin: .zero, size: cardSize), afterScreenUpdates: true)
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let inset = controlPointTouchSize / 2
    let webFrame = bounds.inset(by: UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset))
    previewView.frame = webFrame

    deleteButton.frame = CGRect(
      x: bounds.width / 2 - toolButtonSize / 2,
      y: inset - toolButtonSize / 2,
      width: toolButtonSize,
      height: toolButtonSize
    )

    fullscreenButton.frame = CGRect(
      x: bounds.width - inset - fullscreenSafeMargin - toolButtonSize,
      y: inset + fullscreenSafeMargin,
      width: toolButtonSize,
      height: toolButtonSize
    )

    updateControlPointsPosition()
  }

  private func updateControlPointsPosition() {
    guard controlPoints.count == 4 else { return }
    let inset = controlPointTouchSize / 2
    let positions = [
      CGPoint(x: inset, y: inset),
      CGPoint(x: bounds.width - inset, y: inset),
      CGPoint(x: inset, y: bounds.height - inset),
      CGPoint(x: bounds.width - inset, y: bounds.height - inset),
    ]
    for (index, position) in positions.enumerated() {
      controlPoints[index].center = position
    }
  }

  private func setupDragGesture() {
    let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleTranslationPan(_:)))
    panGesture.maximumNumberOfTouches = 1
    addGestureRecognizer(panGesture)
  }

  @objc private func handleControlPointPan(_ gesture: UIPanGestureRecognizer) {
    if isLocked { return }
    guard let controlPoint = gesture.view else { return }
    switch gesture.state {
    case .began:
      alpha = 0.5
    case .changed:
      let translation = gesture.translation(in: self)
      let cornerIndex = controlPoint.tag
      var newSize = bounds.size
      var scale: CGFloat = 1.0
      switch cornerIndex {
      case 0:
        let widthChange = -translation.x
        scale = (bounds.width + widthChange) / bounds.width
      case 1:
        let widthChange = translation.x
        scale = (bounds.width + widthChange) / bounds.width
      case 2:
        let widthChange = -translation.x
        scale = (bounds.width + widthChange) / bounds.width
      case 3:
        let widthChange = translation.x
        scale = (bounds.width + widthChange) / bounds.width
      default:
        break
      }
      newSize.width *= scale
      newSize.height *= scale
      let minSize: CGFloat = 120
      if newSize.width >= minSize, newSize.height >= minSize { frame.size = newSize }
      gesture.setTranslation(.zero, in: self)
    case .ended, .cancelled:
      alpha = 1.0
      onSizeChanged?(bounds.size)
    default:
      alpha = 1.0
    }
  }

  @objc private func handleTranslationPan(_ gesture: UIPanGestureRecognizer) {
    if isLocked { return }
    switch gesture.state {
    case .began:
      dragStartPoint = gesture.location(in: superview)
    case .changed:
      guard let startPoint = dragStartPoint else { return }
      let currentPoint = gesture.location(in: superview)
      let distance = hypot(currentPoint.x - startPoint.x, currentPoint.y - startPoint.y)
      if alpha == 1.0, distance < minimumDragDistance { return }
      if alpha == 1.0 {
        alpha = 0.5
        deleteButton.isHidden = true
      }
      let translation = gesture.translation(in: superview)
      center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
      gesture.setTranslation(.zero, in: superview)
    case .ended, .cancelled:
      dragStartPoint = nil
      alpha = 1.0
      // 统一恢复显隐
      updateInteractionState()
      onPositionChanged?(frame.origin)
    default:
      dragStartPoint = nil
    }
  }

  private func setupTapGesture() {
    let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
    doubleTapGesture.numberOfTapsRequired = 2
    doubleTapGesture.delegate = self
    doubleTapGesture.cancelsTouchesInView = false
    addGestureRecognizer(doubleTapGesture)

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    tapGesture.delegate = self
    tapGesture.require(toFail: doubleTapGesture)
    addGestureRecognizer(tapGesture)
  }

  @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
    if !isLocked, !isSelectorActive, webId == editingId {
      onTapped?()
    }
  }

  @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
    if !isLocked {
      if isSelectorActive { return }
      if webId == editingId {
        onTapped?()
      } else {
        onQuickSelected?()
      }
    }
  }

  private func setupPinchGesture() {
    let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
    pinchGesture.delegate = self
    addGestureRecognizer(pinchGesture)
  }

  @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
    if isLocked { return }

    switch gesture.state {
    case .began:
      onQuickSelected?()
      alpha = 0.5
      deleteButton.isHidden = true
    case .changed:
      let scale = gesture.scale
      let minContentSize: CGFloat = 120
      let minSize = minContentSize + controlPointTouchSize
      let newSize = CGSize(
        width: max(bounds.width * scale, minSize),
        height: max(bounds.height * scale, minSize)
      )
      let oldCenter = center
      bounds.size = newSize
      center = oldCenter
      gesture.scale = 1
    case .ended, .cancelled:
      alpha = 1.0
      updateInteractionState()
      onSizeChanged?(bounds.size)
      onPositionChanged?(frame.origin)
    default:
      alpha = 1.0
    }
  }

  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    false
  }

  override func removeFromSuperview() {
    deleteButton.removeTarget(nil, action: nil, for: .allEvents)
    fullscreenButton.removeTarget(nil, action: nil, for: .allEvents)
    gestureRecognizers?.forEach { removeGestureRecognizer($0) }
    controlPoints.forEach {
      $0.gestureRecognizers?.forEach { $0.removeTarget(nil, action: nil) }
      $0.removeFromSuperview()
    }
    controlPoints.removeAll()
    onSizeChanged = nil
    onPositionChanged = nil
    onTapped = nil
    onQuickSelected = nil
    onDelete = nil
    onEnterFullScreen = nil
    onPreviewLoaded = nil
    previewView.onMetadataLoaded = nil
    super.removeFromSuperview()
  }

  deinit {
    deleteButton.removeTarget(nil, action: nil, for: .allEvents)
    fullscreenButton.removeTarget(nil, action: nil, for: .allEvents)
    gestureRecognizers?.forEach { removeGestureRecognizer($0) }
    controlPoints.forEach {
      $0.gestureRecognizers?.forEach { $0.removeTarget(nil, action: nil) }
      $0.removeFromSuperview()
    }
    controlPoints.removeAll()
    onSizeChanged = nil
    onPositionChanged = nil
    onTapped = nil
    onQuickSelected = nil
    onDelete = nil
    onEnterFullScreen = nil
    onPreviewLoaded = nil
    previewView.onMetadataLoaded = nil
  }
}
