//
//  DrawingUIView.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/27.
//

import ObjectiveC
import PencilKit
import SwiftUI

struct DrawingUIViewRepresentable: UIViewRepresentable {
  private let canvasOverscrollDistance: CGFloat = 600
  private let canvasOverscrollMiniDistance: CGFloat = 300
  let canvas: PKCanvasView
  @Binding var model: DrawingModel
  @Binding var toolStatus: DrawingView.CanvasToolStatus
  @Binding var pencilType: PKInkingTool.InkType
  @Binding var eraserType: DrawingView.EraserType
  @Binding var isSelectorActive: Bool
  @Binding var penWidth: Double
  @Binding var monolineWidth: Double
  @Binding var pencilWidth: Double
  @Binding var crayonWidth: Double
  @Binding var fountainPenWidth: Double
  @Binding var eraserWidth: Double
  @Binding var color: Color
  @Binding var isLocked: Bool
  @Binding var isShareImageViewShowing: Bool
  @Binding var imageEditingId: UUID?
  @Binding var contentOffset: CGPoint
  let canvasWidth: CGFloat
  let canvasHeight: CGFloat
  let saveDrawing: () -> Void
  let updateExportImage: () -> Void
  let deleteImage: (UUID) -> Void

  var ink: PKInkingTool {
    var tool = PKInkingTool(pencilType, color: UIColor(color))
    print(#function, "\(tool.inkType) \(tool.inkType.defaultWidth) \(tool.inkType.validWidthRange)")
    switch pencilType {
    case .pen:
      tool.width = penWidth
    case .pencil:
      tool.width = pencilWidth
    case .monoline:
      tool.width = monolineWidth
    case .fountainPen:
      tool.width = fountainPenWidth
    case .crayon:
      tool.width = crayonWidth
    default: break
    }
    return tool
  }

  var eraser: PKEraserTool {
    switch eraserType {
    case .bitmap:
      var eraserTool = PKEraserTool(.fixedWidthBitmap)
      print(#function, "\(eraserWidth)")
      print(#function, "validWidthRange \(eraserTool.eraserType.validWidthRange)")
      print(#function, "defaultWidth \(eraserTool.eraserType.defaultWidth)")
      eraserTool.width = eraserWidth
      return eraserTool
    case .vector:
      return PKEraserTool(.vector)
    }
  }

  var defaultSize: CGSize {
    CGSize(
      width: canvasWidth + 2 * canvasOverscrollDistance,
      height: canvasHeight + 2 * canvasOverscrollDistance
    )
  }

  func getTool() -> PKTool {
    switch toolStatus {
    case .ink:
      return ink
    case .eraser:
      return eraser
    }
  }

  func makeUIView(context: Context) -> PKCanvasView {
    print(#function, "make canvas \(model.id) width: \(canvasWidth) height \(canvasHeight)")
    canvas.drawing = model.drawing
    canvas.isDrawingEnabled = !isLocked
    canvas.tool = getTool()
    canvas.backgroundColor = .clear
    canvas.drawingPolicy = .anyInput
    canvas.alwaysBounceHorizontal = true
    canvas.alwaysBounceVertical = true
    canvas.contentSize = defaultSize
    canvas.becomeFirstResponder()
    context.coordinator.lastDrawingId = model.id
    context.coordinator.lastImages = model.images
    canvas.delegate = context.coordinator

    // 添加滚动视图代理
    canvas.delegate = context.coordinator

    // 监听滚动位置变化
    let observer = canvas.observe(\.contentOffset, options: [.new]) { _, change in
      if let newOffset = change.newValue {
        context.coordinator.parent.contentOffset = newOffset
      }
    }
    context.coordinator.contentOffsetObserver = observer

    DispatchQueue.main.async {
      updateContentSizeForDrawing()
    }

    Task {
      try await Task.sleep(for: .seconds(0.5))
      setPosition()
    }

    // 清理现有的图片视图
    canvas.subviews.forEach { view in
      if view is UIImageView {
        view.removeFromSuperview()
      }
    }

    // 使用新的图片视图管理逻辑
    updateImageViews(in: canvas, context: context)

    return canvas
  }

  func updateUIView(_ canvas: PKCanvasView, context: Context) {
    canvas.isDrawingEnabled = !isLocked
    canvas.tool = getTool()

    if context.coordinator.lastDrawingId != model.id {
      print(#function, "DEBUG Change drawing")
      context.coordinator.isUpdatingFromModel = true
      canvas.undoManager?.removeAllActions()

      // 清理图片视图缓存
      context.coordinator.cleanupImageViewCache(currentImageIds: Set(model.images.map { $0.id }))

      canvas.drawing = model.drawing
      DispatchQueue.main.async {
        updateContentSizeForDrawing()
        setPosition()
      }

      // 更新图片视图
      updateImageViews(in: canvas, context: context)

      context.coordinator.lastDrawingId = model.id
      context.coordinator.lastImages = model.images
      context.coordinator.isUpdatingFromModel = false
    } else if context.coordinator.lastImages != model.images {
      print(#function, "DEBUG Change images")

      // 更新图片视图
      updateImageViews(in: canvas, context: context)

      context.coordinator.lastImages = model.images
      DispatchQueue.main.async {
        updateContentSizeForDrawing()
      }
      saveDrawing()
      updateExportImage()
    } else if context.coordinator.lastSelectorActive != isSelectorActive || context.coordinator.lastImageEditingId != imageEditingId {
      print(#function, "DEBUG Change selector active state")
      context.coordinator.lastSelectorActive = isSelectorActive
      updateImageViews(in: canvas, context: context)
    } else if context.coordinator.lastImageEditingId != imageEditingId {
      print(#function, "DEBUG Change imageEditingId")
      context.coordinator.lastImageEditingId = imageEditingId
      updateImageViews(in: canvas, context: context)
    }
  }

  private func updateImageViews(in canvas: PKCanvasView, context: Context) {
    // 创建当前图片ID集合
    let currentImageIds = Set(model.images.map { $0.id })

    // 直接使用 imageViewCache
    let existingImageViews = context.coordinator.imageViewCache

    // 删除不再需要的图片视图
    for (imageId, imageView) in existingImageViews {
      if !currentImageIds.contains(imageId) {
        imageView.removeFromSuperview()
        context.coordinator.imageViewCache.removeValue(forKey: imageId)
      }
    }

    // 更新或添加图片视图
    for imageElement in model.images {
      guard let imageView = context.coordinator.getOrCreateImageView(for: imageElement, in: canvas) else { continue }

      // 设置编辑状态
      imageView.editingId = imageEditingId

      // 设置是否可以响应点击事件
      imageView.isUserInteractionEnabled = isSelectorActive || imageView.editingId == imageElement.id

      // 使用字典快速查找上一次的图片信息
      let lastElement = context.coordinator.lastImageElements[imageElement.id]
      let needsUpdate = existingImageViews[imageElement.id] == nil ||
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

        // 如果视图不在画布上，添加它
        if imageView.superview == nil {
          canvas.addSubview(imageView)
        }
      }

      // 更新回调
      imageView.onPositionChanged = { [weak coordinator = context.coordinator] newPosition in
        guard let coordinator = coordinator else { return }
        // 需要考虑控制点触控区域的偏移
        let inset = imageView.controlPointTouchSize / 2
        let actualPosition = CGPoint(
          x: newPosition.x + inset,
          y: newPosition.y + inset
        )
        coordinator.updateImagePosition(imageId: imageElement.id, position: actualPosition)
      }

      imageView.onSizeChanged = { [weak coordinator = context.coordinator] newSize in
        guard let coordinator = coordinator else { return }
        // 需要考虑控制点触控区域的大小
        let inset = imageView.controlPointTouchSize
        let actualSize = CGSize(
          width: newSize.width - inset,
          height: newSize.height - inset
        )
        coordinator.updateImageSize(imageId: imageElement.id, size: actualSize)
      }

      imageView.onTapped = {
        guard let imageId = imageView.imageId else { return }

        if imageId == imageEditingId {
          imageEditingId = nil
        } else {
          imageEditingId = imageId
        }

        imageView.editingId = imageEditingId
        imageView.isUserInteractionEnabled = isSelectorActive || imageEditingId == imageId
      }

      // 添加删除回调
      imageView.onDelete = { [weak coordinator = context.coordinator] in
        guard let coordinator = coordinator else { return }
        coordinator.parent.deleteImage(imageElement.id)
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func updateContentSizeForDrawing() {
    guard !canvas.drawing.strokes.isEmpty && !canvas.drawing.bounds.isNull && !canvas.contentSize.width.isNaN && !canvas.contentSize.height.isNaN else {
      print(#function, "canvasWidth set \(defaultSize) width: \(canvasWidth) height \(canvasHeight)")
      canvas.contentSize = defaultSize
      return
    }

    let drawing = canvas.drawing
    let newContentWidth: CGFloat
    let newContentHeight: CGFloat

    // 计算所有内容（包括绘画和图片）的边界
    var bounds = drawing.bounds
    for imageElement in model.images {
      let imageFrame = CGRect(origin: imageElement.position, size: imageElement.size)
      bounds = bounds.union(imageFrame)
    }

    let minX = bounds.minX
    let minY = bounds.minY
    let maxX = bounds.maxX
    let maxY = bounds.maxY

    let contentWidth = canvas.contentSize.width
    let contentHeight = canvas.contentSize.height

    let transformX = canvasOverscrollDistance - minX
    let transformY = canvasOverscrollDistance - minY
    let addWidth = canvasOverscrollDistance - (contentWidth - maxX)
    let addHeight = canvasOverscrollDistance - (contentHeight - maxY)

    if minX < canvasOverscrollMiniDistance || minY < canvasOverscrollMiniDistance {
      newContentWidth = contentWidth + transformX + addWidth
      newContentHeight = contentHeight + transformY + addHeight
      print(#function, "set 1 newContentWidth \(newContentWidth) newCcontentHeight \(newContentHeight) width: \(contentWidth) height \(canvasHeight)")
      canvas.contentSize = CGSize(width: newContentWidth, height: newContentHeight)

      guard transformX != 0 || transformY != 0 else { return }

      // 调整绘画内容位置
      let transform = CGAffineTransform(translationX: transformX, y: transformY)
      let transformedDrawing = canvas.drawing.transformed(using: transform)

      CATransaction.begin()
      CATransaction.setDisableActions(true)
      CATransaction.setAnimationDuration(0)
      canvas.drawing = transformedDrawing

      // 同步调整图片位置
      for i in 0 ..< model.images.count {
        var imageElement = model.images[i]
        imageElement.position = CGPoint(
          x: imageElement.position.x + transformX,
          y: imageElement.position.y + transformY
        )
        model.images[i] = imageElement
      }

      canvas.setContentOffset(CGPoint(x: canvas.contentOffset.x + transformX, y: canvas.contentOffset.y + transformY), animated: false)
      CATransaction.commit()
      canvas.undoManager?.removeAllActions()
    } else if maxX > contentWidth - canvasOverscrollMiniDistance || maxY > contentHeight - canvasOverscrollMiniDistance {
      newContentWidth = contentWidth + addWidth
      newContentHeight = contentHeight + addHeight
      print(#function, "set 2 newContentWidth \(newContentWidth) newCcontentHeight \(newContentHeight) width: \(canvasWidth) height \(canvasHeight)")
      canvas.contentSize = CGSize(width: newContentWidth, height: newContentHeight)
    }
  }

  func setPosition() {
    Task {
      guard !canvas.drawing.strokes.isEmpty && !canvas.drawing.bounds.isNull && !canvas.contentSize.width.isNaN && !canvas.contentSize.height.isNaN else {
        print(#function, "Set default position")
        canvas.setContentOffset(CGPoint(x: defaultSize.width / 2, y: defaultSize.height / 2), animated: true)
        return
      }
      var contentBounds = canvas.drawing.bounds
      for imageElement in model.images {
        let imageFrame = CGRect(origin: imageElement.position, size: imageElement.size)
        contentBounds = contentBounds.union(imageFrame)
      }

      print(#function, "contentBounds \(contentBounds) canvas.frame \(canvas.frame) width: \(canvasWidth) height \(canvasHeight)")
      let x = max(contentBounds.width > canvas.frame.width ? contentBounds.minX : contentBounds.midX - canvas.frame.width / 2, 0)
      let y = max(contentBounds.height > canvas.frame.height ? contentBounds.minY : contentBounds.midY - canvas.frame.height / 2, 0)
      print(#function, "x \(x) y \(y)")
      canvas.setContentOffset(CGPoint(x: x, y: y), animated: false)
    }
  }

  class Coordinator: NSObject, PKCanvasViewDelegate, UIScrollViewDelegate {
    var parent: DrawingUIViewRepresentable
    var lastDrawingId: UUID = .init()
    var lastImages: [ImageElement] = []
    var saveWorkItem: DispatchWorkItem?
    var isUpdatingFromModel = false
    var lastImageEditingId: UUID?
    var lastImageElements: [UUID: ImageElement] = [:]
    var lastSelectorActive: Bool = false
    var imageViewCache: [UUID: ResizableImageView] = [:] {
      didSet {
        print(#function, "imageViewCache \(oldValue.count)")
      }
    }

    var contentOffsetObserver: NSKeyValueObservation?

    init(_ parent: DrawingUIViewRepresentable) {
      self.parent = parent
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
      guard !isUpdatingFromModel else { return }

      saveWorkItem?.cancel()
      saveWorkItem = nil

      let workItem = DispatchWorkItem { [weak self] in
        guard let self = self else { return }
        if self.parent.model.drawing != canvasView.drawing {
          Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.parent.model.drawing = canvasView.drawing
            self.parent.updateContentSizeForDrawing()
            self.parent.saveDrawing()
            if self.parent.isShareImageViewShowing {
              self.parent.updateExportImage()
            }
          }
        }
      }

      saveWorkItem = workItem
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    func updateImagePosition(imageId: UUID, position: CGPoint) {
      guard let index = parent.model.images.firstIndex(where: { $0.id == imageId }) else { return }
      var updatedImage = parent.model.images[index]
      updatedImage.position = position
      parent.model.images[index] = updatedImage

      parent.saveDrawing()
      if parent.isShareImageViewShowing {
        parent.updateExportImage()
      }
    }

    func updateImageSize(imageId: UUID, size: CGSize) {
      guard let index = parent.model.images.firstIndex(where: { $0.id == imageId }) else { return }
      var updatedImage = parent.model.images[index]
      updatedImage.size = size
      parent.model.images[index] = updatedImage

      parent.saveDrawing()
      if parent.isShareImageViewShowing {
        parent.updateExportImage()
      }
    }

    func getOrCreateImageView(for imageElement: ImageElement, in canvas: PKCanvasView) -> ResizableImageView? {
      if let cachedView = imageViewCache[imageElement.id] {
        // 复用现有视图
        if let image = UIImage(data: imageElement.imageData) {
          cachedView.image = image
        }
        return cachedView
      }

      // 创建新视图
      if let image = UIImage(data: imageElement.imageData) {
        let imageView = ResizableImageView(image: image, size: image.size)
        imageView.contentMode = .scaleAspectFit
        imageView.imageId = imageElement.id
        imageViewCache[imageElement.id] = imageView
        return imageView
      }

      print(#function, "Failed to create image view")
      return nil
    }

    func cleanupImageViewCache(currentImageIds: Set<UUID>) {
      let unusedIds = Set(imageViewCache.keys).subtracting(currentImageIds)
      print("Cleaning up \(unusedIds.count) unused image views")

      unusedIds.forEach { id in
        imageViewCache[id]?.removeFromSuperview()
        imageViewCache[id] = nil
      }
    }

    deinit {
      saveWorkItem?.cancel()
      saveWorkItem = nil
      contentOffsetObserver?.invalidate()

      // 清理所有缓存的视图
      cleanupImageViewCache(currentImageIds: [])
    }
  }
}
