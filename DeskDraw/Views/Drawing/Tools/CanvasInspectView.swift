//
//  CanvasInspectView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/4/12.
//

import PencilKit
import SwiftUI

struct CanvasInspectView: View {
  @Environment(AppModel.self) private var appModel
  @AppStorage("canvasInspectViewBgColor") private var bgColor: Color = .clear
  let canvasId: UUID?

  var body: some View {
    EmptyView()
    GeometryReader { proxy in
      if let canvasId, let currentDrawing = appModel.getCurrentDrawing(for: canvasId) {
        ScrollableCanvasView(
          model: Binding(
            get: {
              return currentDrawing
            },
            set: { _ in }
          ),
          bgColor: $bgColor
        )
        .colorScheme(.light)
        .overlay(alignment: .bottomTrailing) {
          ColorPicker("Color", selection: $bgColor)
            .labelsHidden()
            .frame(width: 20, height: 20)
            .padding(32)
        }
      } else {
        ProgressView()
      }
    }
  }
}

struct ScrollableCanvasView: UIViewRepresentable {
  @Binding var model: DrawingModel
  @Binding var bgColor: Color
  private let canvasOverscrollDistance: CGFloat = 600
  
  func makeCoordinator() -> Coordinator {
    Coordinator()
  }
  
  func makeUIView(context: Context) -> UIScrollView {
    let scrollView = UIScrollView()
    scrollView.delegate = context.coordinator
    scrollView.minimumZoomScale = 0.25
    scrollView.maximumZoomScale = 4.0
    scrollView.bouncesZoom = true
    scrollView.showsHorizontalScrollIndicator = true
    scrollView.showsVerticalScrollIndicator = true
    scrollView.backgroundColor = UIColor(bgColor)
    
    // 创建并配置 PKCanvasView
    let canvas = PKCanvasView()
    canvas.drawing = model.drawing
    canvas.isUserInteractionEnabled = false
    canvas.isDrawingEnabled = false
    canvas.backgroundColor = .clear
    canvas.drawingPolicy = .anyInput
    canvas.isOpaque = false
    canvas.isUserInteractionEnabled = false
    context.coordinator.canvas = canvas
    
    // 创建图片容器视图
    let containerView = ImageContainerView(frame: .zero)
    containerView.isUserInteractionEnabled = false
    context.coordinator.imageContainer = containerView
    
    // 创建一个容器视图来持有 canvas 和图片容器
    let contentView = UIView()
    contentView.addSubview(containerView)
    contentView.addSubview(canvas)
    context.coordinator.contentView = contentView
    
    scrollView.addSubview(contentView)
    
    // 更新内容大小和布局
    context.coordinator.updateContentSize(with: model)
    
    // 恢复保存的滚动位置
    if let savedPosition = context.coordinator.getSavedScrollPosition(modelId: model.id) {
      scrollView.contentOffset = savedPosition
    }
    
    return scrollView
  }
  
  func updateUIView(_ scrollView: UIScrollView, context: Context) {
    let coordinator = context.coordinator
    scrollView.backgroundColor = UIColor(bgColor)
    // 更新绘图内容
    if coordinator.lastDrawingId != model.id {
      scrollView.setZoomScale(1, animated: false)
      coordinator.canvas?.drawing = model.drawing
      coordinator.lastDrawingId = model.id
      coordinator.updateContentSize(with: model)
      
      // 在切换 drawing 时恢复保存的位置和缩放
      if let savedPosition = coordinator.getSavedScrollPosition(modelId: model.id) {
        scrollView.contentOffset = savedPosition
      }
    } else if coordinator.canvas?.drawing != model.drawing {
      coordinator.canvas?.drawing = model.drawing
      coordinator.updateContentSize(with: model)
    }
    
    // 更新图片
    if coordinator.lastImages != model.images {
      coordinator.updateImages(with: model.images)
      coordinator.lastImages = model.images
      coordinator.updateContentSize(with: model)
    }
  }
  
  class Coordinator: NSObject, UIScrollViewDelegate {
    private let canvasOverscrollDistance: CGFloat = 600
    var canvas: PKCanvasView?
    var imageContainer: ImageContainerView?
    var contentView: UIView?
    var lastDrawingId: UUID = .init()
    var lastImages: [ImageElement] = []
    var lastImageElements: [UUID: ImageElement] = [:]
    var imageViewCache: [UUID: ResizableImageView] = [:]
    
    override init() {
      super.init()
    }
    
    func updateContentSize(with model: DrawingModel) {
      guard let contentView = contentView,
            let canvas = canvas,
            let imageContainer = imageContainer,
            let scrollView = canvas.superview?.superview as? UIScrollView else { return }
      print(#function, "CanvasInspect DEBUG model.id \(model.id) \(model.drawing.strokes.count)")
      let scale = scrollView.zoomScale
      // 计算内容大小
      var bounds = model.drawing.bounds
      if bounds.isNull {
        bounds = CGRect(origin: .zero, size: CGSize(width: 1024, height: 1024))
      }
      
      // 考虑图片的边界
      for imageElement in model.images {
        let imageFrame = CGRect(origin: imageElement.position, size: imageElement.size)
        bounds = bounds.union(imageFrame)
      }
      // 添加过度滚动距离
      let contentSize = CGSize(
        width: bounds.minX + bounds.width + canvasOverscrollDistance,
        height: bounds.minY + bounds.height + canvasOverscrollDistance
      )
      // 更新视图大小
      contentView.frame = CGRect(origin: .zero, size: contentSize * scale)
      canvas.frame = CGRect(origin: .zero, size: contentSize)
      imageContainer.frame = CGRect(origin: .zero, size: contentSize)
      scrollView.contentSize = contentSize * scale
    }
    
    func updateImages(with images: [ImageElement]) {
      guard let imageContainer = imageContainer else { return }
      
      // 清理不再需要的图片视图
      let currentImageIds = Set(images.map { $0.id })
      for (id, imageView) in imageViewCache {
        if !currentImageIds.contains(id) {
          imageView.removeFromSuperview()
          imageViewCache.removeValue(forKey: id)
        }
      }
      
      // 更新或添加图片视图
      for imageElement in images {
        guard let imageView = getOrCreateImageView(for: imageElement) else { continue }
        imageView.editingId = nil
        imageView.isLocked = true
        imageView.isUserInteractionEnabled = false

        // 使用字典快速查找上一次的图片信息
        let lastElement = lastImageElements[imageElement.id]
        let needsUpdate = imageViewCache[imageElement.id] == nil ||
          lastElement?.imageData != imageElement.imageData ||
          lastElement?.position != imageElement.position ||
          lastElement?.size != imageElement.size ||
          lastElement?.rotation != imageElement.rotation

        if needsUpdate {
          // 考虑控制点触控区域，调整 frame
          let inset = imageView.controlPointTouchSize / 2
          let adjustedFrame = CGRect(
            x: imageElement.position.x - inset,
            y: imageElement.position.y - inset,
            width: imageElement.size.width + inset * 2,
            height: imageElement.size.height + inset * 2
          )
          imageView.frame = adjustedFrame
          imageView.transform = CGAffineTransform(rotationAngle: imageElement.rotation)

          // 如果视图不在容器中，添加它
          if imageView.superview == nil {
            imageContainer.addImageView(imageView)
          }
        }
      }
    }
    
    func getOrCreateImageView(for imageElement: ImageElement) -> ResizableImageView? {
      if let cachedView = imageViewCache[imageElement.id] {
        if let image = UIImage(data: imageElement.imageData) {
          cachedView.image = image
        }
        return cachedView
      }
      
      if let image = UIImage(data: imageElement.imageData) {
        let imageView = ResizableImageView(image: image, size: image.size)
        imageView.contentMode = .scaleAspectFit
        imageView.imageId = imageElement.id
        imageViewCache[imageElement.id] = imageView
        return imageView
      }
      
      return nil
    }
    
    // MARK: - Scroll Position Management
    
    func getSavedScrollPosition(modelId: UUID) -> CGPoint? {
      let key = "scrollPosition_\(modelId.uuidString)"
      guard let positionData = UserDefaults.standard.data(forKey: key),
            let position = try? JSONDecoder().decode(CGPoint.self, from: positionData)
      else {
        return nil
      }
      let zoom = getSavedZoomScale(modelId: modelId)
      return .init(x: position.x * (zoom ?? 1), y: position.y * (zoom ?? 1))
    }
    
    func getSavedZoomScale(modelId: UUID) -> CGFloat? {
      let key = "zoomScale_\(modelId.uuidString)"
      return UserDefaults.standard.object(forKey: key) as? CGFloat
    }
    
    // MARK: - UIScrollViewDelegate
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
      return contentView
    }
  }
}

#Preview {
  NavigationStack {
    CanvasInspectView(canvasId: UUID())
      .environment(AppModel())
  }
}
