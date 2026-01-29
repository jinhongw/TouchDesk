//
//  DrawingUIView.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/27.
//

import ObjectiveC
import PencilKit
import SwiftUI

struct DrawingUIView: UIViewRepresentable {
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
  @Binding var zoomFactor: Double
  let canvasWidth: CGFloat
  let canvasHeight: CGFloat
  let saveDrawing: () -> Void
  let updateExportImage: () -> Void
  let deleteImage: (UUID) -> Void
  let deleteWeb: (UUID) -> Void
  let enterFullScreenWeb: (UUID) -> Void
  let updateWebSnapshot: (UUID, UIImage) -> Void
  let updateWebCachedMetadata: (UUID, String, Data?) -> Void
  let refreshThumbnailAfterWebSnapshot: () -> Void

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
      width: canvasWidth,
      height: canvasHeight
    )
  }

  var zoomFactorValue: CGFloat {
    CGFloat(zoomFactor / 100)
  }

  var realConentSize: CGSize {
    .init(width: canvas.contentSize.width / zoomFactorValue,
          height: canvas.contentSize.height / zoomFactorValue)
  }

  func getTool() -> PKTool {
    switch toolStatus {
    case .ink:
      return ink
    case .eraser:
      return eraser
    }
  }

  private func saveScrollPosition(_ position: CGPoint, for drawingId: UUID) {
    let key = "scrollPosition_\(drawingId.uuidString)"
    let positionData = try? JSONEncoder().encode(position)
    UserDefaults.standard.set(positionData, forKey: key)
    print(#function, "save position \(position) for \(drawingId)")
  }

  private func getScrollPosition(for drawingId: UUID) -> CGPoint? {
    let key = "scrollPosition_\(drawingId.uuidString)"
    guard let positionData = UserDefaults.standard.data(forKey: key),
          let position = try? JSONDecoder().decode(CGPoint.self, from: positionData)
    else {
      return nil
    }
    print(#function, "position \(position) for \(drawingId)")
    return position
  }

  private func saveZoomFactor(_ zoom: Double, for drawingId: UUID) {
    let key = "zoomFactor_\(drawingId.uuidString)"
    UserDefaults.standard.set(zoom, forKey: key)
    print(#function, "save zoom \(zoom) for \(drawingId)")
  }

  private func getZoomFactor(for drawingId: UUID) -> Double? {
    let key = "zoomFactor_\(drawingId.uuidString)"
    let zoom = UserDefaults.standard.double(forKey: key)
    return zoom != 0 ? zoom : nil
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
    canvas.contentSize = defaultSize * zoomFactorValue
    canvas.minimumZoomScale = 0.25
    canvas.maximumZoomScale = 4.0
    canvas.zoomScale = zoomFactorValue
    canvas.isOpaque = false
    canvas.becomeFirstResponder()
    context.coordinator.lastDrawingId = model.id
    context.coordinator.lastImages = model.images
    canvas.delegate = context.coordinator

    // 创建并设置图片容器
    let imageContainer = ImageContainerView(frame: CGRect(origin: .zero, size: defaultSize))
    context.coordinator.imageContainer = imageContainer
    canvas.addSubview(imageContainer)

    // 添加一个初始化标志
    context.coordinator.isInitializing = true

    let observer = canvas.observe(\.contentOffset, options: [.new]) { _, change in
      if let newOffset = change.newValue {
        DispatchQueue.main.async {
          context.coordinator.parent.contentOffset = newOffset
        }
        // 只有当满足以下条件时才保存位置：
        // 1. 不在初始化阶段
        // 2. 不是程序性设置位置
        // 3. 偏移不是(0.0, 0.0)
        if !context.coordinator.isInitializing &&
          !context.coordinator.isSettingPosition &&
          (newOffset.x != 0 || newOffset.y != 0)
        {
          // 取消之前的任务
          context.coordinator.saveScrollWorkItem?.cancel()

          // 创建新的防抖任务
          let workItem = DispatchWorkItem {
            context.coordinator.parent.saveScrollPosition(newOffset, for: context.coordinator.parent.model.id)
          }

          // 保存任务引用并延迟执行
          context.coordinator.saveScrollWorkItem = workItem
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }
      }
    }
    context.coordinator.contentOffsetObserver = observer
    updateContentSizeForDrawing(coordinator: context.coordinator)

    Task {
      try await Task.sleep(for: .seconds(0.5))
      // 恢复缩放比例
      if let savedZoom = getZoomFactor(for: model.id) {
        canvas.setZoomScale(CGFloat(savedZoom / 100), animated: false)
        context.coordinator.imageContainer?.setZoomScale(CGFloat(savedZoom / 100), animated: false)
      } else {
        canvas.setZoomScale(1, animated: false)
        context.coordinator.imageContainer?.setZoomScale(1, animated: false)
      }
      setPosition()
      // 初始化完成，可以开始正常保存滚动位置
      context.coordinator.isInitializing = false
    }

    // 清理现有的图片视图
    canvas.subviews.forEach { view in
      if view is UIImageView {
        view.removeFromSuperview()
      }
    }

    // 使用新的图片视图管理逻辑
    updateImageViews(in: canvas, context: context)
    updateWebViews(in: canvas, context: context)

    return canvas
  }

  func updateUIView(_ canvas: PKCanvasView, context: Context) {
    canvas.isDrawingEnabled = !isLocked
    canvas.tool = getTool()

    // 更新缩放比例
    if canvas.zoomScale != zoomFactorValue {
      canvas.setZoomScale(zoomFactorValue, animated: true)
      context.coordinator.imageContainer?.setZoomScale(zoomFactorValue, animated: true)
      // 保存缩放比例
      if !context.coordinator.isInitializing {
        saveZoomFactor(zoomFactor, for: model.id)
      }
    }

    if context.coordinator.lastDrawingId != model.id {
      print(#function, "DEBUG Change drawing")
      context.coordinator.isUpdatingFromModel = true
      canvas.undoManager?.removeAllActions()

      // 切换drawing时，设置初始化标志为true
      context.coordinator.isInitializing = true

      // 清理图片视图缓存
      context.coordinator.cleanupImageViewCache(currentImageIds: Set(model.images.map { $0.id }))
      context.coordinator.cleanupWebViewCache(currentWebIds: Set(model.webs.map { $0.id }))

      // 先重置 contentSize 到默认大小
      canvas.contentSize = defaultSize * zoomFactorValue
      canvas.drawing = model.drawing

      updateContentSizeForDrawing(coordinator: context.coordinator)

      // 恢复缩放比例
      if let savedZoom = getZoomFactor(for: model.id) {
        zoomFactor = savedZoom
        canvas.setZoomScale(CGFloat(savedZoom / 100), animated: false)
        context.coordinator.imageContainer?.setZoomScale(CGFloat(savedZoom / 100), animated: false)
      } else {
        zoomFactor = 100
        canvas.setZoomScale(1, animated: false)
        context.coordinator.imageContainer?.setZoomScale(1, animated: false)
      }

      // 设置位置
      setPosition()

      // 延迟将初始化标志设为false
      Task {
        try await Task.sleep(for: .seconds(0.5))
        context.coordinator.isInitializing = false
      }

      // 更新图片视图
      updateImageViews(in: canvas, context: context)
      updateWebViews(in: canvas, context: context)

      context.coordinator.lastDrawingId = model.id
      context.coordinator.lastImages = model.images
      context.coordinator.isUpdatingFromModel = false
    } else if context.coordinator.lastImages != model.images {
      print(#function, "DEBUG Change images")

      // 更新图片视图
      updateImageViews(in: canvas, context: context)

      context.coordinator.lastImages = model.images
      updateContentSizeForDrawing(coordinator: context.coordinator)
      saveDrawing()
      updateExportImage()
    } else if context.coordinator.lastWebs != model.webs {
      print(#function, "DEBUG Change webs")
      updateWebViews(in: canvas, context: context)
      context.coordinator.lastWebs = model.webs
      updateContentSizeForDrawing(coordinator: context.coordinator)
      saveDrawing()
      updateExportImage()
    } else if context.coordinator.lastSelectorActive != isSelectorActive || context.coordinator.lastImageEditingId != imageEditingId {
      print(#function, "DEBUG Change selector active state")
      context.coordinator.lastSelectorActive = isSelectorActive
      updateImageViews(in: canvas, context: context)
      updateWebViews(in: canvas, context: context)
    } else if context.coordinator.lastImageEditingId != imageEditingId {
      print(#function, "DEBUG Change imageEditingId")
      context.coordinator.lastImageEditingId = imageEditingId
      updateImageViews(in: canvas, context: context)
      updateWebViews(in: canvas, context: context)
    } else if context.coordinator.lastLocked != isLocked {
      print(#function, "DEBUG Change locked state")
      context.coordinator.lastLocked = isLocked
      updateImageViews(in: canvas, context: context)
      updateWebViews(in: canvas, context: context)
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func updateContentSizeForDrawing(coordinator: Coordinator) {
    // 如果正在缩放，不执行内容大小更新
    guard coordinator.parent.canvas.isZooming == false else { return }

    // 检查是否有任何内容（绘画或图片）
    let hasDrawing = !canvas.drawing.strokes.isEmpty && !canvas.drawing.bounds.isNull
    let hasImages = !model.images.isEmpty
    let hasWebs = !model.webs.isEmpty

    guard hasDrawing || hasImages || hasWebs else {
      print(#function, "canvasWidth set \(defaultSize) width: \(canvasWidth) height \(canvasHeight)")
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      canvas.contentSize = defaultSize * zoomFactorValue
      coordinator.imageContainer?.updateFrame(size: defaultSize, transform: .identity)
      coordinator.imageContainer?.setZoomScale(canvas.zoomScale, animated: false)
      CATransaction.commit()
      return
    }

    let drawing = canvas.drawing
    let newContentWidth: CGFloat
    let newContentHeight: CGFloat

    // 计算所有内容（包括绘画和图片）的边界
    var bounds = hasDrawing ? drawing.bounds : .zero
    for imageElement in model.images {
      let imageFrame = CGRect(origin: imageElement.position, size: imageElement.size)
      print(#function, "bounds \(bounds) imageFrame \(imageFrame)")
      bounds = bounds == .zero ? imageFrame : bounds.union(imageFrame)
    }
    for webElement in model.webs {
      let webFrame = CGRect(origin: webElement.position, size: webElement.size)
      bounds = bounds == .zero ? webFrame : bounds.union(webFrame)
    }

    let minX = bounds.minX
    let minY = bounds.minY
    let maxX = bounds.maxX
    let maxY = bounds.maxY

    let contentWidth = realConentSize.width
    let contentHeight = realConentSize.height

    print(#function, "zoomFactor \(zoomFactorValue) contentWidth \(contentWidth) contentHeight \(contentHeight)")

    let transformX = canvasOverscrollDistance - minX
    let transformY = canvasOverscrollDistance - minY
    let addWidth = canvasOverscrollDistance - (contentWidth - maxX)
    let addHeight = canvasOverscrollDistance - (contentHeight - maxY)

    print(#function, "minX \(minX) minY \(minY) maxX \(maxX) maxY \(maxY) contentWidth \(contentWidth) contentHeight \(contentHeight)")
    if minX < canvasOverscrollMiniDistance || minY < canvasOverscrollMiniDistance {
      newContentWidth = contentWidth + transformX + addWidth
      newContentHeight = contentHeight + transformY + addHeight
      print(#function, "set 1 newContentWidth \(newContentWidth) newCcontentHeight \(newContentHeight) width: \(contentWidth) height \(canvasHeight)")
      let newSize = CGSize(width: newContentWidth, height: newContentHeight)
      canvas.contentSize = newSize * zoomFactorValue
      coordinator.imageContainer?.updateFrame(size: newSize, transform: .identity)
      coordinator.imageContainer?.setZoomScale(canvas.zoomScale, animated: false)

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
      for i in 0 ..< model.webs.count {
        var webElement = model.webs[i]
        webElement.position = CGPoint(
          x: webElement.position.x + transformX,
          y: webElement.position.y + transformY
        )
        model.webs[i] = webElement
      }

      canvas.setContentOffset(CGPoint(x: canvas.contentOffset.x + transformX, y: canvas.contentOffset.y + transformY), animated: false)
      CATransaction.commit()
      canvas.undoManager?.removeAllActions()
    } else if maxX > contentWidth - canvasOverscrollMiniDistance || maxY > contentHeight - canvasOverscrollMiniDistance {
      newContentWidth = contentWidth + addWidth
      newContentHeight = contentHeight + addHeight
      print(#function, "set 2 newContentWidth \(newContentWidth) newCcontentHeight \(newContentHeight) width: \(canvasWidth) height \(canvasHeight)")
      let newSize = CGSize(width: newContentWidth, height: newContentHeight)
      canvas.contentSize = newSize * zoomFactorValue
      coordinator.imageContainer?.updateFrame(size: newSize, transform: .identity)
      coordinator.imageContainer?.setZoomScale(canvas.zoomScale, animated: false)
    }
  }

  func setPosition() {
    Task {
      // 设置标志，表示当前正在程序性设置滚动位置
      let coordinator = canvas.delegate as? Coordinator
      coordinator?.isSettingPosition = true

      // 首先检查是否有保存的滚动位置
      if let savedPosition = getScrollPosition(for: model.id) {
        canvas.setContentOffset(savedPosition, animated: false)
        // 延迟重置标志
        Task {
          try await Task.sleep(for: .milliseconds(100))
          coordinator?.isSettingPosition = false
        }
        return
      }

      // 如果没有保存的位置，使用原有逻辑
      let hasDrawing = !canvas.drawing.strokes.isEmpty && !canvas.drawing.bounds.isNull
      let hasImages = !model.images.isEmpty
      let hasWebs = !model.webs.isEmpty

      guard hasDrawing || hasImages || hasWebs else {
        print(#function, "Set default position")
        canvas.setContentOffset(CGPoint(x: defaultSize.width / 2, y: defaultSize.height / 2), animated: true)
        // 延迟重置标志
        Task {
          try await Task.sleep(for: .milliseconds(100))
          coordinator?.isSettingPosition = false
        }
        return
      }

      var contentBounds = hasDrawing ? canvas.drawing.bounds : .zero
      for imageElement in model.images {
        let imageFrame = CGRect(origin: imageElement.position, size: imageElement.size)
        contentBounds = contentBounds == .zero ? imageFrame : contentBounds.union(imageFrame)
      }
      for webElement in model.webs {
        let webFrame = CGRect(origin: webElement.position, size: webElement.size)
        contentBounds = contentBounds == .zero ? webFrame : contentBounds.union(webFrame)
      }

      print(#function, "contentBounds \(contentBounds) canvas.frame \(canvas.frame) width: \(canvasWidth) height \(canvasHeight)")
      let x = max(contentBounds.width > canvas.frame.width ? contentBounds.minX : contentBounds.midX - canvas.frame.width / 2, 0)
      let y = max(contentBounds.height > canvas.frame.height ? contentBounds.minY : contentBounds.midY - canvas.frame.height / 2, 0)
      print(#function, "x \(x) y \(y)")
      canvas.setContentOffset(CGPoint(x: x, y: y), animated: false)

      // 延迟重置标志
      Task {
        try await Task.sleep(for: .milliseconds(100))
        coordinator?.isSettingPosition = false
      }
    }
  }
}
