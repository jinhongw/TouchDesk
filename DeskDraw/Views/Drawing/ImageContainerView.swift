import UIKit

class ImageContainerView: UIScrollView {
  private let contentView = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setupView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupView()
  }

  private func setupView() {
    backgroundColor = .clear
    isUserInteractionEnabled = true
    layer.anchorPoint = .zero
    layer.zPosition = -1
    
    // 禁用滚动，但启用缩放
    isScrollEnabled = false
    bounces = false
    bouncesZoom = false
    showsHorizontalScrollIndicator = false
    showsVerticalScrollIndicator = false
    
    // 设置缩放范围
    minimumZoomScale = 0.25
    maximumZoomScale = 2.0
    
    // 设置代理
    delegate = self
    
    // 添加内容视图
    contentView.isUserInteractionEnabled = true
    contentView.frame = bounds
    contentView.backgroundColor = .clear
    addSubview(contentView)
    
    layer.drawsAsynchronously = true
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // 确保内容视图大小与滚动视图一致
    contentView.frame = bounds
  }

  // 更新容器大小
  func updateFrame(size: CGSize, transform: CGAffineTransform = .identity) {
    print(#function, "size \(size)")
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    
    // 更新frame
    frame = CGRect(
      x: 0,
      y: 0,
      width: floor(size.width),
      height: floor(size.height)
    )
    
    // 更新内容视图大小
    self.frame = frame
    contentView.frame = frame
    
    // 更新缩放
    setZoomScale(transform.a, animated: false)
    
    CATransaction.commit()
  }

  // 添加图片视图到容器
  func addImageView(_ imageView: ResizableImageView) {
    contentView.addSubview(imageView)
  }

  // 移除图片视图
  func removeImageView(_ imageView: ResizableImageView) {
    imageView.removeFromSuperview()
  }

  // 清除所有图片视图
  func removeAllImageViews() {
    contentView.subviews.forEach { $0.removeFromSuperview() }
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    // 遍历所有子视图，看看触摸点是否在子视图内
    for subview in contentView.subviews.reversed() {
      let convertedPoint = subview.convert(point, from: self)
      if let hitView = subview.hitTest(convertedPoint, with: event), hitView.isUserInteractionEnabled {
          return hitView  // 只有启用交互的子视图才能接收事件
      }
    }
    return nil // 父视图不响应
  }
}

// MARK: - UIScrollViewDelegate
extension ImageContainerView: UIScrollViewDelegate {
  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return contentView
  }
  
  func scrollViewDidZoom(_ scrollView: UIScrollView) {
    // 确保内容始终居中
    setNeedsLayout()
    layoutIfNeeded()
  }
}
