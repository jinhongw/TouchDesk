import UIKit

class ResizableImageView: UIView {
  let controlPointTouchSize: CGFloat = 32 // 触控区域大小
  private let controlPointVisualSize: CGFloat = 10 // 视觉大小
  private let controlPointBorderWidth: CGFloat = 2
  private let toolButtonSize: CGFloat = 23
  private var controlPoints: [ControlPointView] = []
  private var imageContentView: UIImageView
  private var deleteButton: UIButton
  private var dragStartPoint: CGPoint?
  private let minimumDragDistance: CGFloat = 5.0

  var imageId: UUID?
  var onSizeChanged: ((CGSize) -> Void)?
  var onPositionChanged: ((CGPoint) -> Void)?
  var onTapped: (() -> Void)?
  var onDelete: (() -> Void)?

  var image: UIImage? {
    get { imageContentView.image }
    set { imageContentView.image = newValue }
  }

  var editingId: UUID? {
    didSet {
      // 根据编辑状态显示或隐藏控制点
      controlPoints.forEach { $0.isHidden = imageId != editingId }
      // 根据编辑状态更新拖拽手势
      updateDragGesture()
      // 根据编辑状态更新删除按钮显示
      updateDeleteButtonVisibility()
    }
  }

  init(image: UIImage?, size: CGSize) {
    // 先初始化 imageContentView
    imageContentView = UIImageView(image: image)
    imageContentView.contentMode = .scaleAspectFit
    
    // 初始化删除按钮
    deleteButton = UIButton(type: .system)
    deleteButton.isHidden = true
    
    super.init(frame: .zero)
    backgroundColor = .clear // 确保背景透明

    imageContentView.frame = CGRect(
      x: controlPointTouchSize / 2,
      y: controlPointTouchSize / 2,
      width: size.width,
      height: size.height
    )
    // 添加 imageContentView 作为子视图
    addSubview(imageContentView)
    
    // 添加删除按钮
    deleteButton.frame = CGRect(x: 0, y: 0, width: toolButtonSize, height: toolButtonSize)
    
    // 创建并配置毛玻璃效果
    let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
    let blurView = UIVisualEffectView(effect: blurEffect)
    blurView.frame = deleteButton.bounds
    blurView.layer.cornerRadius = toolButtonSize / 2
    blurView.clipsToBounds = true
    blurView.isUserInteractionEnabled = false
    deleteButton.insertSubview(blurView, at: 0)
    
    // 配置按钮样式
    var config = UIButton.Configuration.plain()
    config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 10, weight: .regular)
    config.image = UIImage(systemName: "trash")
    config.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 0.5, bottom: 0, trailing: 0)
    config.baseForegroundColor = .white
    deleteButton.configuration = config
    
    // 确保按钮内容居中
    deleteButton.contentVerticalAlignment = .center
    deleteButton.contentHorizontalAlignment = .center
    deleteButton.imageView?.contentMode = .center
    deleteButton.tintColor = .white
    deleteButton.hoverStyle = .init(effect: .automatic, shape: .circle)
    
    addSubview(deleteButton)
    deleteButton.addTarget(self, action: #selector(handleDelete), for: .touchUpInside)
    
    setupControlPoints()
    setupDragGesture()
    setupTapGesture()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupControlPoints() {
    // 移除现有的控制点
    controlPoints.forEach { $0.removeFromSuperview() }
    controlPoints.removeAll()
    let inset = controlPointTouchSize / 2
    // 创建四个角落的控制点，使用相同的位置计算逻辑
    let positions = [
      CGPoint(x: inset, y: inset), // 左上
      CGPoint(x: bounds.width - inset, y: inset), // 右上
      CGPoint(x: inset, y: bounds.height - inset), // 左下
      CGPoint(x: bounds.width - inset, y: bounds.height - inset), // 右下
    ]

    for (index, position) in positions.enumerated() {
      let controlPoint = createControlPoint(at: position)
      controlPoint.tag = index
      // 根据编辑状态设置控制点的显示状态
      controlPoint.isHidden = imageId != editingId
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

  private func updateDeleteButtonVisibility() {
    deleteButton.isHidden = imageId != editingId
  }

  @objc private func handleDelete() {
    onDelete?()
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    // 计算实际图片内容的区域（去掉控制点的触控区域）
    let inset = controlPointTouchSize / 2
    let imageFrame = bounds.inset(by: UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset))
    imageContentView.frame = imageFrame

    // 更新删除按钮位置
    deleteButton.frame = CGRect(
      x: bounds.width / 2 - toolButtonSize / 2,
      y: inset - toolButtonSize / 2,
      width: toolButtonSize,
      height: toolButtonSize
    )

    updateControlPointsPosition()
  }

  private func updateControlPointsPosition() {
    guard controlPoints.count == 4 else { return }

    let inset = controlPointTouchSize / 2
    // 创建四个角落的控制点，使用 imageContentView 的边界来定位
    let positions = [
      CGPoint(x: inset, y: inset), // 左上
      CGPoint(x: bounds.width - inset, y: inset), // 右上
      CGPoint(x: inset, y: bounds.height - inset), // 左下
      CGPoint(x: bounds.width - inset, y: bounds.height - inset), // 右下
    ]

    for (index, position) in positions.enumerated() {
      controlPoints[index].center = position
    }
  }

  private func setupDragGesture() {
    let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleImageTranslationPan(_:)))
    addGestureRecognizer(panGesture)
  }

  private func updateDragGesture() {
    // 只在编辑状态下启用拖拽手势
    gestureRecognizers?.forEach { gesture in
      if gesture is UIPanGestureRecognizer {
        gesture.isEnabled = imageId == editingId
      }
    }
    layer.zPosition = imageId == editingId ? 1 : -1
  }

  @objc private func handleControlPointPan(_ gesture: UIPanGestureRecognizer) {
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
      case 0: // 左上角
        let widthChange = -translation.x
        scale = (bounds.width + widthChange) / bounds.width
      case 1: // 右上角
        let widthChange = translation.x
        scale = (bounds.width + widthChange) / bounds.width
      case 2: // 左下角
        let widthChange = -translation.x
        scale = (bounds.width + widthChange) / bounds.width
      case 3: // 右下角
        let widthChange = translation.x
        scale = (bounds.width + widthChange) / bounds.width
      default:
        break
      }

      // 保持宽高比
      newSize.width *= scale
      newSize.height *= scale

      // 限制最小尺寸
      let minSize: CGFloat = 50
      if newSize.width >= minSize && newSize.height >= minSize {
        frame.size = newSize
      }
      
      gesture.setTranslation(.zero, in: self)
      
    case .ended, .cancelled:
      alpha = 1.0
      // 只在手势结束时才触发回调更新数据
      onSizeChanged?(bounds.size)
    default:
      alpha = 1.0
    }
  }

  @objc private func handleImageTranslationPan(_ gesture: UIPanGestureRecognizer) {
    switch gesture.state {
    case .began:
      dragStartPoint = gesture.location(in: superview)
    case .changed:
      guard let startPoint = dragStartPoint else { return }
      let currentPoint = gesture.location(in: superview)
      let distance = hypot(currentPoint.x - startPoint.x, currentPoint.y - startPoint.y)
      
      // 如果还没开始拖动且距离小于最小触发距离，则不处理
      if alpha == 1.0 && distance < minimumDragDistance {
        return
      }
      
      // 开始拖动时的视觉反馈
      if alpha == 1.0 {
        alpha = 0.5
        deleteButton.isHidden = true
      }
      
      let translation = gesture.translation(in: superview)
      center = CGPoint(
        x: center.x + translation.x,
        y: center.y + translation.y
      )
      gesture.setTranslation(.zero, in: superview)
    case .ended, .cancelled:
      dragStartPoint = nil
      alpha = 1.0
      updateDeleteButtonVisibility()
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
    onTapped?()
  }

  override func removeFromSuperview() {
    deleteButton.removeTarget(nil, action: nil, for: .allEvents)
    gestureRecognizers?.forEach { removeGestureRecognizer($0) }
    controlPoints.forEach {
      $0.gestureRecognizers?.forEach { $0.removeTarget(nil, action: nil) }
      $0.removeFromSuperview()
    }
    controlPoints.forEach { $0.removeFromSuperview() }
    controlPoints.removeAll()
    onSizeChanged = nil
    onPositionChanged = nil
    onTapped = nil
    onDelete = nil

    super.removeFromSuperview()
  }

  deinit {
    deleteButton.removeTarget(nil, action: nil, for: .allEvents)
    gestureRecognizers?.forEach { removeGestureRecognizer($0) }
    controlPoints.forEach {
      $0.gestureRecognizers?.forEach { $0.removeTarget(nil, action: nil) }
      $0.removeFromSuperview()
    }
    controlPoints.forEach { $0.removeFromSuperview() }
    controlPoints.removeAll()
    onSizeChanged = nil
    onPositionChanged = nil
    onTapped = nil
    onDelete = nil
  }
}

class ControlPointView: UIView {
  private let visualSize: CGFloat
  private let touchSize: CGFloat

  init(visualSize: CGFloat, touchSize: CGFloat) {
    self.visualSize = visualSize
    self.touchSize = touchSize
    super.init(frame: .zero)
    setupView()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    gestureRecognizers?.forEach { removeGestureRecognizer($0) }
  }

  private func setupView() {
    // 创建视觉点视图
    let visualPoint = UIView(frame: CGRect(
      x: (touchSize - visualSize) / 2,
      y: (touchSize - visualSize) / 2,
      width: visualSize,
      height: visualSize
    ))
    visualPoint.backgroundColor = .systemBlue
    visualPoint.layer.cornerRadius = visualSize / 2
    visualPoint.layer.borderWidth = 2
    visualPoint.layer.borderColor = UIColor.white.cgColor

    addSubview(visualPoint)
  }
}
