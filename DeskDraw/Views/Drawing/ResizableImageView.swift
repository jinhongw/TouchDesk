import UIKit

class ResizableImageView: UIView {
  let controlPointTouchSize: CGFloat = 44 // 触控区域大小
  private let controlPointVisualSize: CGFloat = 10 // 视觉大小
  private let controlPointBorderWidth: CGFloat = 2
  private var controlPoints: [ControlPointView] = []
  private var imageContentView: UIImageView

  var imageId: UUID?
  var onSizeChanged: ((CGSize) -> Void)?
  var onSelected: ((UUID) -> Void)?
  var onPositionChanged: ((CGPoint) -> Void)?

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
    }
  }

  init(image: UIImage?, size: CGSize) {
    // 先初始化 imageContentView
    imageContentView = UIImageView(image: image)
    imageContentView.contentMode = .scaleAspectFit
    super.init(frame: .zero)
    backgroundColor = .clear // 确保背景透明
    isUserInteractionEnabled = true // 确保可以接收触摸事件

    imageContentView.frame = CGRect(
      x: controlPointTouchSize / 2,
      y: controlPointTouchSize / 2,
      width: size.width,
      height: size.height
    )
    // 添加 imageContentView 作为子视图
    addSubview(imageContentView)

    setupControlPoints()
    setupDragGesture()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupControlPoints() {
    // 移除现有的控制点
    controlPoints.forEach { $0.removeFromSuperview() }
    controlPoints.removeAll()
    let inset = controlPointTouchSize / 2
    // 创建四个角落的控制点
    let positions = [
      CGPoint(x: inset, y: inset), // 左上
      CGPoint(x: bounds.maxX - inset, y: inset), // 右上
      CGPoint(x: inset, y: bounds.maxY - inset), // 左下
      CGPoint(x: bounds.maxX - inset, y: bounds.maxY - inset), // 右下
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
      x: position.x,
      y: position.y,
      width: controlPointTouchSize,
      height: controlPointTouchSize
    )
    controlPoint.isUserInteractionEnabled = true

    return controlPoint
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    // 计算实际图片内容的区域（去掉控制点的触控区域）
    let inset = controlPointTouchSize / 2
    let imageFrame = bounds.inset(by: UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset))
    imageContentView.frame = imageFrame

    updateControlPointsPosition()
  }

  private func updateControlPointsPosition() {
    guard controlPoints.count == 4 else { return }

    let inset = controlPointTouchSize / 2
    // 创建四个角落的控制点
    let positions = [
      CGPoint(x: inset, y: inset), // 左上
      CGPoint(x: bounds.maxX - inset, y: inset), // 右上
      CGPoint(x: inset, y: bounds.maxY - inset), // 左下
      CGPoint(x: bounds.maxX - inset, y: bounds.maxY - inset), // 右下
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
    isUserInteractionEnabled = imageId == editingId
    layer.zPosition = imageId == editingId ? 1 : -1
  }

  @objc private func handleControlPointPan(_ gesture: UIPanGestureRecognizer) {
    guard let controlPoint = gesture.view else { return }
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
      // 只在手势结束时才触发回调更新数据
      if gesture.state == .ended || gesture.state == .cancelled {
        onSizeChanged?(newSize)
      }
    }

    gesture.setTranslation(.zero, in: self)
  }

  @objc private func handleImageTranslationPan(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: superview)

    center = CGPoint(
      x: center.x + translation.x,
      y: center.y + translation.y
    )

    if gesture.state == .ended || gesture.state == .cancelled {
      onPositionChanged?(frame.origin)
    }

    gesture.setTranslation(.zero, in: superview)
  }

  override func removeFromSuperview() {
    gestureRecognizers?.forEach { removeGestureRecognizer($0) }
    controlPoints.forEach {
        $0.gestureRecognizers?.forEach { $0.removeTarget(nil, action: nil) }
        $0.removeFromSuperview()
    }
    controlPoints.forEach { $0.removeFromSuperview() }
    controlPoints.removeAll()
    onSizeChanged = nil
    onSelected = nil
    onPositionChanged = nil

    super.removeFromSuperview()
  }

  deinit {
    // 确保所有资源都被清理
    gestureRecognizers?.forEach { removeGestureRecognizer($0) }
    controlPoints.forEach {
        $0.gestureRecognizers?.forEach { $0.removeTarget(nil, action: nil) }
        $0.removeFromSuperview()
    }
    controlPoints.forEach { $0.removeFromSuperview() }
    controlPoints.removeAll()
    onSizeChanged = nil
    onSelected = nil
    onPositionChanged = nil
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
