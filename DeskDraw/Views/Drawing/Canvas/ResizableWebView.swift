import WebKit
import UIKit

class ResizableWebView: UIView {
  let controlPointTouchSize: CGFloat = 32
  private let controlPointVisualSize: CGFloat = 10
  private let controlPointBorderWidth: CGFloat = 2
  private let toolButtonSize: CGFloat = 23
  private var controlPoints: [ControlPointView] = []
  private var webContentView: WKWebView
  private var deleteButton: UIButton
  private var confirmButton: UIButton
  private var editButton: UIButton
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
  var onDelete: (() -> Void)?
  var onBeginEditing: (() -> Void)?
  var onFinishEditing: (() -> Void)?
  var onEnterFullScreen: (() -> Void)?

  var isSelectorActive: Bool = false {
    didSet { updateInteractionState() }
  }

  var editingId: UUID? {
    didSet { updateInteractionState() }
  }

  private func updateInteractionState() {
    let shouldShowControls = webId == editingId && !isLocked
    controlPoints.forEach { $0.isHidden = !shouldShowControls }
    updateDragGesture()
    updateDeleteButtonVisibility()
    let isEditing = (webId == editingId) && !isLocked
    deleteButton.isHidden = !isEditing
    confirmButton.isHidden = !isEditing
    editButton.isHidden = isEditing || !isSelectorActive
    fullscreenButton.isHidden = !shouldShowControls
  }

  private func updateDeleteButtonVisibility() {
    deleteButton.isHidden = webId != editingId || isLocked
  }

  private func updateDragGesture() {
    gestureRecognizers?.forEach { gesture in
      if gesture is UIPanGestureRecognizer {
        gesture.isEnabled = webId == editingId && !isLocked
      }
    }
    layer.zPosition = (webId == editingId && !isLocked) ? 1 : -1
  }

  init(url: String, size: CGSize) {
    let config = WKWebViewConfiguration()
    config.allowsInlineMediaPlayback = true
    webContentView = WKWebView(frame: .zero, configuration: config)
    deleteButton = UIButton(type: .system)
    confirmButton = UIButton(type: .system)
    editButton = UIButton(type: .system)
    fullscreenButton = UIButton(type: .system)

    super.init(frame: .zero)
    backgroundColor = .clear

    webContentView.backgroundColor = .clear
    webContentView.isOpaque = false
    webContentView.frame = CGRect(
      x: controlPointTouchSize / 2,
      y: controlPointTouchSize / 2,
      width: size.width,
      height: size.height
    )
    addSubview(webContentView)

    if let u = URL(string: url) {
      webContentView.load(URLRequest(url: u))
    }

    deleteButton.frame = CGRect(x: 0, y: 0, width: toolButtonSize, height: toolButtonSize)

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

    // Confirm button setup
    confirmButton.frame = CGRect(x: 0, y: 0, width: toolButtonSize, height: toolButtonSize)
    let confirmBlurView = UIVisualEffectView(effect: blurEffect)
    confirmBlurView.frame = confirmButton.bounds
    confirmBlurView.layer.cornerRadius = toolButtonSize / 2
    confirmBlurView.clipsToBounds = true
    confirmBlurView.isUserInteractionEnabled = false
    confirmButton.insertSubview(confirmBlurView, at: 0)

    var confirmConfig = UIButton.Configuration.plain()
    confirmConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 10, weight: .regular)
    confirmConfig.image = UIImage(systemName: "checkmark")
    confirmConfig.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 0.5, bottom: 0, trailing: 0)
    confirmConfig.baseForegroundColor = .white
    confirmButton.configuration = confirmConfig

    confirmButton.contentVerticalAlignment = .center
    confirmButton.contentHorizontalAlignment = .center
    confirmButton.imageView?.contentMode = .center
    confirmButton.tintColor = .white
    confirmButton.layer.cornerRadius = toolButtonSize / 2
    confirmButton.clipsToBounds = true
    addSubview(confirmButton)
    confirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)

    // Edit button setup
    editButton.frame = CGRect(x: 0, y: 0, width: toolButtonSize, height: toolButtonSize)
    let editBlurView = UIVisualEffectView(effect: blurEffect)
    editBlurView.frame = editButton.bounds
    editBlurView.layer.cornerRadius = toolButtonSize / 2
    editBlurView.clipsToBounds = true
    editBlurView.isUserInteractionEnabled = false
    editButton.insertSubview(editBlurView, at: 0)

    var editConfig = UIButton.Configuration.plain()
    editConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 10, weight: .regular)
    editConfig.image = UIImage(systemName: "pencil.line")
    editConfig.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 0.5, bottom: 0, trailing: 0)
    editConfig.baseForegroundColor = .white
    editButton.configuration = editConfig

    editButton.contentVerticalAlignment = .center
    editButton.contentHorizontalAlignment = .center
    editButton.imageView?.contentMode = .center
    editButton.tintColor = .white
    editButton.layer.cornerRadius = toolButtonSize / 2
    editButton.clipsToBounds = true
    addSubview(editButton)
    editButton.addTarget(self, action: #selector(handleEdit), for: .touchUpInside)

    // Fullscreen button setup
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
    updateInteractionState()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
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

  @objc private func handleConfirm() {
    if !isLocked { onFinishEditing?() }
  }

  @objc private func handleEdit() {
    if !isLocked { onBeginEditing?() }
  }

  @objc private func handleEnterFullScreen() {
    if !isLocked { onEnterFullScreen?() }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let inset = controlPointTouchSize / 2
    let webFrame = bounds.inset(by: UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset))
    webContentView.frame = webFrame

    deleteButton.frame = CGRect(
      x: bounds.width / 2 - toolButtonSize / 2,
      y: inset - toolButtonSize / 2,
      width: toolButtonSize,
      height: toolButtonSize
    )

    // Confirm button at right side of delete button
    confirmButton.frame = deleteButton.frame.offsetBy(dx: 36, dy: 0)

    // Edit button shares the same position as delete button when non-editing
    editButton.frame = deleteButton.frame

    // Fullscreen button placed to the left of delete button
    fullscreenButton.frame = deleteButton.frame.offsetBy(dx: -36, dy: 0)

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
        // 隐藏顶部按钮，避免拖拽时遮挡
        deleteButton.isHidden = true
        confirmButton.isHidden = true
        editButton.isHidden = true
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
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    addGestureRecognizer(tapGesture)
  }

  @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
    if !isLocked { onTapped?() }
  }

  override func removeFromSuperview() {
    deleteButton.removeTarget(nil, action: nil, for: .allEvents)
    confirmButton.removeTarget(nil, action: nil, for: .allEvents)
    editButton.removeTarget(nil, action: nil, for: .allEvents)
    gestureRecognizers?.forEach { removeGestureRecognizer($0) }
    controlPoints.forEach {
      $0.gestureRecognizers?.forEach { $0.removeTarget(nil, action: nil) }
      $0.removeFromSuperview()
    }
    controlPoints.removeAll()
    onSizeChanged = nil
    onPositionChanged = nil
    onTapped = nil
    onDelete = nil
    onBeginEditing = nil
    onFinishEditing = nil
    super.removeFromSuperview()
  }

  deinit {
    deleteButton.removeTarget(nil, action: nil, for: .allEvents)
    confirmButton.removeTarget(nil, action: nil, for: .allEvents)
    editButton.removeTarget(nil, action: nil, for: .allEvents)
    gestureRecognizers?.forEach { removeGestureRecognizer($0) }
    controlPoints.forEach {
      $0.gestureRecognizers?.forEach { $0.removeTarget(nil, action: nil) }
      $0.removeFromSuperview()
    }
    controlPoints.removeAll()
    onSizeChanged = nil
    onPositionChanged = nil
    onTapped = nil
    onDelete = nil
    onBeginEditing = nil
    onFinishEditing = nil
  }
}

