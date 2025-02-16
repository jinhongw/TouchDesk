//
//  DrawingUIView.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/27.
//

import PencilKit
import SwiftUI

struct DrawingUIViewRepresentable: UIViewRepresentable {
  private let canvasOverscrollDistance: CGFloat = 3000
  private let canvasOverscrollMiniDistance: CGFloat = 600
  let canvas: PKCanvasView
  @Binding var drawing: PKDrawing
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
  var canvasWidth: CGFloat
  var canvasHeight: CGFloat
  var saveDrawing: () -> Void

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

  let lasso = PKLassoTool()
  
  var defaultSize: CGSize {
    CGSize(
      width: canvasWidth + 2 * canvasOverscrollDistance,
      height: canvasHeight + 2 * canvasOverscrollDistance
    )
  }

  func makeUIView(context: Context) -> PKCanvasView {
    canvas.drawing = drawing
    canvas.drawingPolicy = .anyInput
    canvas.isDrawingEnabled = !isLocked
    switch toolStatus {
    case .ink:
      canvas.tool = ink
    case .eraser:
      canvas.tool = eraser
    }
    canvas.backgroundColor = .clear
    canvas.alwaysBounceHorizontal = true
    canvas.alwaysBounceVertical = true
    canvas.contentSize = defaultSize
    canvas.becomeFirstResponder()
    canvas.delegate = context.coordinator

    updateContentSizeForDrawing()
    setPosition()
    return canvas
  }

  func setPosition() {
    Task {
      guard !canvas.drawing.strokes.isEmpty && !canvas.drawing.bounds.isNull && !canvas.contentSize.width.isNaN && !canvas.contentSize.height.isNaN else {
        print(#function, "Set default position")
        try await Task.sleep(for: .seconds(0.5))
        canvas.setContentOffset(CGPoint(x: defaultSize.width / 2, y: defaultSize.height / 2), animated: false)
        return
      }
      try await Task.sleep(for: .seconds(0.5))
      let bounds = canvas.drawing.bounds
      print(#function, "bounds \(bounds)")
      let x = max(bounds.width > canvas.frame.width ? bounds.minX : bounds.midX - canvas.frame.width / 2, 0)
      let y = max(bounds.height > canvas.frame.height ? bounds.minY : bounds.midY - canvas.frame.height / 2, 0)
      print(#function, "x \(x) y \(y)")
      canvas.setContentOffset(CGPoint(x: x, y: y), animated: false)
    }
  }

  func updateUIView(_ uiView: PKCanvasView, context: Context) {
    print(#function)
    if uiView.drawing != drawing {
      print(#function, "drawing change")
      uiView.drawing = drawing
      updateContentSizeForDrawing()
      uiView.undoManager?.removeAllActions()
    }
    switch toolStatus {
    case .ink:
      uiView.tool = ink
    case .eraser:
      uiView.tool = eraser
    }
    uiView.isDrawingEnabled = !isLocked
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
    let minX = drawing.bounds.minX
    let minY = drawing.bounds.minY
    let maxX = drawing.bounds.maxX
    let maxY = drawing.bounds.maxY

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
      let transform = CGAffineTransform(translationX: transformX, y: transformY)
      let transformedDrawing = canvas.drawing.transformed(using: transform)
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      CATransaction.setAnimationDuration(0)
      canvas.drawing = transformedDrawing
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

  class Coordinator: NSObject, PKCanvasViewDelegate {
    var parent: DrawingUIViewRepresentable

    init(_ parent: DrawingUIViewRepresentable) {
      self.parent = parent
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
      if parent.drawing != canvasView.drawing {
        print(#function, "drawing change")
        parent.drawing = canvasView.drawing
        parent.updateContentSizeForDrawing()
        parent.saveDrawing()
      }
    }
  }
}
