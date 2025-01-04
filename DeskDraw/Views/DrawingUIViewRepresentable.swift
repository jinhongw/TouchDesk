//
//  DrawingUIView.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/27.
//

import PencilKit
import SwiftUI

struct DrawingUIViewRepresentable: UIViewRepresentable {
  let canvasOverscrollDistance: CGFloat = 1000
  @Binding var canvas: PKCanvasView
  @Binding var drawing: PKDrawing
  @Binding var toolStatus: DrawingView.CanvasToolStatus
  @Binding var pencilType: PKInkingTool.InkType
  @Binding var color: Color
  @Binding var isLocked: Bool
  var canvasWidth: CGFloat
  var canvasHeight: CGFloat
  var saveDrawing: () -> Void

  var ink: PKInkingTool {
    PKInkingTool(pencilType, color: UIColor(color))
  }

  let eraser = PKEraserTool(.bitmap)
  let lasso = PKLassoTool()

  func makeUIView(context: Context) -> PKCanvasView {
    canvas.drawing = drawing
    canvas.drawingPolicy = .anyInput
    canvas.isDrawingEnabled = !isLocked
    switch toolStatus {
    case .ink:
      canvas.tool = ink
    case .eraser:
      canvas.tool = eraser
    case .lasso:
      canvas.tool = lasso
    }
    canvas.isRulerActive = true
    canvas.backgroundColor = .clear

    canvas.alwaysBounceVertical = true
    canvas.alwaysBounceHorizontal = true
    canvas.contentSize = CGSize(width: canvasWidth, height: canvasHeight)
    canvas.becomeFirstResponder()
    canvas.delegate = context.coordinator

    updateContentSizeForDrawing()
    return canvas
  }

  func updateUIView(_ uiView: PKCanvasView, context: Context) {
    print(#function)
    if uiView.drawing != drawing {
      print(#function, "drawing change")
      uiView.drawing = drawing
      uiView.undoManager?.removeAllActions()
    }
    switch toolStatus {
    case .ink:
      uiView.tool = ink
    case .eraser:
      uiView.tool = eraser
    case .lasso:
      uiView.tool = lasso
    }
    uiView.isDrawingEnabled = !isLocked
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
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
        parent.saveDrawing()
      }
      parent.updateContentSizeForDrawing()
    }
  }

  /// Helper method to set a suitable content size for the canvas view.
  func updateContentSizeForDrawing() {
    // Update the content size to match the drawing.
    let drawing = canvas.drawing
    let contentHeight: CGFloat
    let contentWidth: CGFloat

    // Adjust the content size to always be bigger than the drawing height.
    if !drawing.bounds.isNull {
      contentHeight = max(canvas.bounds.height, (drawing.bounds.maxY + canvasOverscrollDistance) * canvas.zoomScale)
      contentWidth = max(canvas.bounds.width, (drawing.bounds.maxX + canvasOverscrollDistance) * canvas.zoomScale)
    } else {
      contentHeight = canvas.bounds.height
      contentWidth = canvas.bounds.width
    }
    canvas.contentSize = CGSize(width: contentWidth, height: contentHeight)
  }
}
