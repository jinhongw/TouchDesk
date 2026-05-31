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

  var body: some View {
    GeometryReader { proxy in
      if let _ = appModel.currentDrawing {
        ScrollableCanvasView(
          model: Binding(
            get: {
              return appModel.currentDrawing ?? DrawingModel(name: "", drawing: PKDrawing())
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

    if coordinator.lastVideos != model.videos {
      coordinator.updateVideos(with: model.videos)
      coordinator.lastVideos = model.videos
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
    var lastVideos: [VideoElement] = []
    var lastImageElements: [UUID: ImageElement] = [:]
    var lastVideoElements: [UUID: VideoElement] = [:]
    var imageViewCache: [UUID: ResizableImageView] = [:]
    var videoViewCache: [UUID: ResizableImageView] = [:]
    
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
      for videoElement in model.videos {
        let videoFrame = CGRect(origin: videoElement.position, size: videoElement.size)
        bounds = bounds.union(videoFrame)
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

    func updateVideos(with videos: [VideoElement]) {
      guard let imageContainer = imageContainer else { return }

      let currentVideoIds = Set(videos.map { $0.id })
      for (id, videoView) in videoViewCache {
        if !currentVideoIds.contains(id) {
          videoView.removeFromSuperview()
          videoViewCache.removeValue(forKey: id)
        }
      }

      for videoElement in videos {
        guard let videoView = getOrCreateVideoView(for: videoElement) else { continue }
        videoView.editingId = nil
        videoView.isLocked = true
        videoView.isUserInteractionEnabled = false

        let lastElement = lastVideoElements[videoElement.id]
        let needsUpdate = videoViewCache[videoElement.id] == nil ||
          lastElement?.assetId != videoElement.assetId ||
          lastElement?.thumbnailFileName != videoElement.thumbnailFileName ||
          lastElement?.position != videoElement.position ||
          lastElement?.size != videoElement.size ||
          lastElement?.rotation != videoElement.rotation

        if needsUpdate {
          let inset = videoView.controlPointTouchSize / 2
          let adjustedFrame = CGRect(
            x: videoElement.position.x - inset,
            y: videoElement.position.y - inset,
            width: videoElement.size.width + inset * 2,
            height: videoElement.size.height + inset * 2
          )
          videoView.frame = adjustedFrame
          videoView.transform = CGAffineTransform(rotationAngle: videoElement.rotation)

          if videoView.superview == nil {
            imageContainer.addImageView(videoView)
          }
        }
      }

      lastVideoElements = Dictionary(uniqueKeysWithValues: videos.map { ($0.id, $0) })
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

    func getOrCreateVideoView(for videoElement: VideoElement) -> ResizableImageView? {
      if let cachedView = videoViewCache[videoElement.id] {
        cachedView.image = DrawingFileManager.shared.loadVideoThumbnail(fileName: videoElement.thumbnailFileName)
        return cachedView
      }

      guard let thumbnail = DrawingFileManager.shared.loadVideoThumbnail(fileName: videoElement.thumbnailFileName) else {
        return nil
      }

      let videoView = ResizableImageView(image: thumbnail, size: videoElement.size)
      videoView.contentMode = .scaleAspectFit
      videoView.imageId = videoElement.id
      videoView.addVideoBadge()
      videoViewCache[videoElement.id] = videoView
      return videoView
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
    CanvasInspectView()
      .environment(AppModel())
  }
}
