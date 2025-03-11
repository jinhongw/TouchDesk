//
//  DrawingUIView.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/27.
//

import PencilKit
import SwiftUI
import ObjectiveC

private var imageIdKey: UInt8 = 0

extension UIImageView {
    var imageId: UUID? {
        get {
            return objc_getAssociatedObject(self, &imageIdKey) as? UUID
        }
        set {
            objc_setAssociatedObject(self, &imageIdKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

struct DrawingUIViewRepresentable: UIViewRepresentable {
  private let canvasOverscrollDistance: CGFloat = 3000
  private let canvasOverscrollMiniDistance: CGFloat = 600
  let canvas: PKCanvasView
  @Binding var model: DrawingModel
  @Binding var toolStatus: DrawingView.CanvasToolStatus
  @Binding var pencilType: PKInkingTool.InkType
  @Binding var eraserType: DrawingView.EraserType
  @Binding var penWidth: Double
  @Binding var monolineWidth: Double
  @Binding var pencilWidth: Double
  @Binding var crayonWidth: Double
  @Binding var fountainPenWidth: Double
  @Binding var eraserWidth: Double
  @Binding var color: Color
  @Binding var isLocked: Bool
  let canvasWidth: CGFloat
  let canvasHeight: CGFloat
  let saveDrawing: () -> Void

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

//  let lasso = PKLassoTool()

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
    print(#function, "make canvas \(model.id)")
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

    updateContentSizeForDrawing()
    setPosition()
    // 清除现有的图片视图
    canvas.subviews.forEach { view in
      if view is UIImageView {
        view.removeFromSuperview()
      }
    }

    // 添加图片
    for imageElement in model.images {
      if let image = UIImage(data: imageElement.imageData) {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(origin: imageElement.position, size: imageElement.size)
        imageView.transform = CGAffineTransform(rotationAngle: imageElement.rotation)
        canvas.insertSubview(imageView, at: 0)
      }
    }

    return canvas
  }

  func updateUIView(_ canvas: PKCanvasView, context: Context) {
    canvas.isDrawingEnabled = !isLocked
    canvas.tool = getTool()

    if context.coordinator.lastDrawingId != model.id {
      print(#function, "DEBUG Change drawing")
      context.coordinator.isUpdatingFromModel = true // 设置标志位
      canvas.undoManager?.removeAllActions()
      // 清除现有的图片视图
      canvas.subviews.forEach { view in
        if view is UIImageView {
          view.removeFromSuperview()
        }
      }

      canvas.drawing = model.drawing
      updateContentSizeForDrawing()
      setPosition()

      // 添加图片
      for imageElement in model.images {
        if let image = UIImage(data: imageElement.imageData) {
          let imageView = UIImageView(image: image)
          imageView.contentMode = .scaleAspectFit
          imageView.frame = CGRect(origin: imageElement.position, size: imageElement.size)
          imageView.transform = CGAffineTransform(rotationAngle: imageElement.rotation)
          imageView.imageId = imageElement.id
          canvas.insertSubview(imageView, at: 0)
        }
      }

      context.coordinator.lastDrawingId = model.id
      context.coordinator.lastImages = model.images
      context.coordinator.isUpdatingFromModel = false // 重置标志位
    }

    if context.coordinator.lastImages != model.images {
      print(#function, "DEBUG Change images")
      
      // 创建字典以快速查找现有的图片视图
      var existingImageViews: [UUID: UIImageView] = [:]
      canvas.subviews.forEach { view in
        if let imageView = view as? UIImageView,
           let imageId = imageView.imageId {
          existingImageViews[imageId] = imageView
        }
      }
      
      // 创建新的图片元素字典以快速查找
      let newImageElements = Dictionary(uniqueKeysWithValues: model.images.map { ($0.id, $0) })
      
      // 删除不再存在的图片视图
      for (imageId, imageView) in existingImageViews {
        if newImageElements[imageId] == nil {
          imageView.removeFromSuperview()
        }
      }
      
      // 更新或添加图片
      for imageElement in model.images {
        if let existingImageView = existingImageViews[imageElement.id] {
          // 更新现有图片视图
          if let image = UIImage(data: imageElement.imageData) {
            existingImageView.image = image
            existingImageView.frame = CGRect(origin: imageElement.position, size: imageElement.size)
            existingImageView.transform = CGAffineTransform(rotationAngle: imageElement.rotation)
          }
        } else {
          // 添加新图片视图
          if let image = UIImage(data: imageElement.imageData) {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            imageView.frame = CGRect(origin: imageElement.position, size: imageElement.size)
            imageView.transform = CGAffineTransform(rotationAngle: imageElement.rotation)
            imageView.imageId = imageElement.id
            canvas.insertSubview(imageView, at: 0)
          }
        }
      }

      context.coordinator.lastImages = model.images
      updateContentSizeForDrawing()
      setPosition()
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func updateContentSizeForDrawing() {
    guard !canvas.drawing.strokes.isEmpty && !canvas.drawing.bounds.isNull && !canvas.contentSize.width.isNaN && !canvas.contentSize.height.isNaN else {
      print(#function, "canvasWidth \(canvasWidth) canvasHeight \(canvasHeight)")
      canvas.contentSize = defaultSize
      return
    }

    let drawing = canvas.drawing
    let contentHeight: CGFloat
    let contentWidth: CGFloat

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

    let canvasWidth = canvas.contentSize.width
    let canvasHeight = canvas.contentSize.height

    let transformX = canvasOverscrollDistance - minX
    let transformY = canvasOverscrollDistance - minY
    let addWidth = canvasOverscrollDistance - (canvasWidth - maxX)
    let addHeight = canvasOverscrollDistance - (canvasHeight - maxY)

    if minX < canvasOverscrollMiniDistance || minY < canvasOverscrollMiniDistance {
      contentWidth = canvasWidth + transformX + addWidth
      contentHeight = canvasHeight + transformY + addHeight
      print(#function, "canvasWidth \(contentWidth) canvasHeight \(contentHeight)")
      canvas.contentSize = CGSize(width: contentWidth, height: contentHeight)

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
    } else {
      contentWidth = canvasWidth + addWidth
      contentHeight = canvasHeight + addHeight
      print(#function, "canvasWidth \(contentWidth) canvasHeight \(contentHeight)")
      canvas.contentSize = CGSize(width: contentWidth, height: contentHeight)
    }
  }
  
  func setPosition() {
    Task {
      guard !canvas.drawing.strokes.isEmpty && !canvas.drawing.bounds.isNull && !canvas.contentSize.width.isNaN && !canvas.contentSize.height.isNaN else {
        print(#function, "Set default position")
        canvas.setContentOffset(CGPoint(x: defaultSize.width / 2, y: defaultSize.height / 2), animated: true)
        return
      }
//      try await Task.sleep(for: .seconds(0.5))
      
      // 计算所有内容的边界
      var contentBounds = canvas.drawing.bounds
      // 添加图片边界
      for imageElement in model.images {
        let imageFrame = CGRect(origin: imageElement.position, size: imageElement.size)
        contentBounds = contentBounds.union(imageFrame)
      }
      
      print(#function, "contentBounds \(contentBounds)")
      let x = max(contentBounds.width > canvas.frame.width ? contentBounds.minX : contentBounds.midX - canvas.frame.width / 2, 0)
      let y = max(contentBounds.height > canvas.frame.height ? contentBounds.minY : contentBounds.midY - canvas.frame.height / 2, 0)
      print(#function, "x \(x) y \(y)")
      canvas.setContentOffset(CGPoint(x: x, y: y), animated: false)
    }
  }

  class Coordinator: NSObject, PKCanvasViewDelegate {
    var parent: DrawingUIViewRepresentable
    var lastDrawingId: UUID = .init()
    var lastImages: [ImageElement] = []
    var saveWorkItem: DispatchWorkItem?
    var isUpdatingFromModel = false // 添加标志位

    init(_ parent: DrawingUIViewRepresentable) {
      self.parent = parent
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
      // 如果是来自模型的更新，不触发保存
      guard !isUpdatingFromModel else { return }

      // 取消之前的保存任务
      saveWorkItem?.cancel()

      // 创建新的保存任务
      let workItem = DispatchWorkItem { [weak self] in
        guard let self = self else { return }
        if self.parent.model.drawing != canvasView.drawing {
          Task { @MainActor in
            print(#function, "canvas set model \(self.parent.model.id)")
            // 更新绘画内容
            self.parent.model.drawing = canvasView.drawing
            // 更新画布大小
            self.parent.updateContentSizeForDrawing()
            // 保存绘画
            self.parent.saveDrawing()
          }
        }
      }

      // 延迟执行保存任务
      saveWorkItem = workItem
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
  }
}
