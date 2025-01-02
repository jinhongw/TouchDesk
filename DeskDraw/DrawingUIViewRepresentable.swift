//
//  DrawingUIView.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/27.
//

import PencilKit
import SwiftUI

struct DrawingUIViewRepresentable: UIViewRepresentable {
  @Binding var canvas: PKCanvasView
  @Binding var drawing: PKDrawing
  @Binding var isDrawing: Bool
  @Binding var pencilType: PKInkingTool.InkType
  @Binding var color: Color
//  @Binding var toolPicker: PKToolPicker

  var saveDrawing: () -> Void

  var ink: PKInkingTool {
    PKInkingTool(pencilType, color: UIColor(color))
  }

  let eraser = PKEraserTool(.bitmap)

  func makeUIView(context: Context) -> PKCanvasView {
    canvas.drawing = drawing
    canvas.drawingPolicy = .anyInput

    canvas.tool = isDrawing ? ink : eraser
    canvas.isRulerActive = true
    canvas.backgroundColor = .init(red: 1, green: 1, blue: 1, alpha: 0)

    canvas.alwaysBounceVertical = true
    canvas.alwaysBounceHorizontal = true
    canvas.contentSize = CGSize(width: 10000, height: 10000)
//    canvas.scrollIndicatorInsets = canvas.contentInset
//    toolPicker.setVisible(true, forFirstResponder: canvas)
//    toolPicker.colorUserInterfaceStyle = .dark
//    toolPicker.prefersDismissControlVisible = false
//    toolPicker.addObserver(canvas)
    canvas.becomeFirstResponder()
    canvas.delegate = context.coordinator
    return canvas
  }

  func updateUIView(_ uiView: PKCanvasView, context: Context) {
    print(#function)
    if uiView.drawing != drawing {
      uiView.drawing = drawing
    }
    uiView.tool = isDrawing ? ink : eraser
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
        parent.drawing = canvasView.drawing
        parent.saveDrawing()
      }
    }
  }
}
