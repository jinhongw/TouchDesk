//
//  DrawingUIView.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/27.
//

import PencilKit
import SwiftUI

struct DrawingUIViewRepresentable: UIViewRepresentable {
  // Capture drawings for saving in the photos library
  @Binding var canvas: PKCanvasView
  @Binding var drawing: PKDrawing
  @Binding var isDrawing: Bool
  // Ability to switch a pencil
  @Binding var pencilType: PKInkingTool.InkType
  // Ability to change a pencil color
  @Binding var color: Color
  @Binding var toolPicker: PKToolPicker

  var saveDrawing: () -> Void

  // let ink = PKInkingTool(.pencil, color: .black)
  // Update ink type
  var ink: PKInkingTool {
    PKInkingTool(pencilType, color: UIColor(color))
  }

  let eraser = PKEraserTool(.bitmap)

  func makeUIView(context: Context) -> PKCanvasView {
    canvas.drawing = drawing
    // Allow finger and pencil drawing
    canvas.drawingPolicy = .default

    canvas.tool = isDrawing ? ink : eraser
//    canvas.transform = .init(rotationAngle: .pi / 2)
    canvas.isRulerActive = true
    canvas.backgroundColor = .init(red: 1, green: 1, blue: 1, alpha: 0)
    // Use buttons as tools
    // canvas.tool = PKInkingTool(.fountainPen, color: .brown, width: 4)

    // From Brian Advent: Show the default toolpicker
    canvas.alwaysBounceVertical = true
    canvas.alwaysBounceHorizontal = true
    canvas.contentSize = CGSize(width: 1000, height: 1000)
//    canvas.scrollIndicatorInsets = canvas.contentInset
    toolPicker.setVisible(true, forFirstResponder: canvas)
    toolPicker.colorUserInterfaceStyle = .dark
    toolPicker.prefersDismissControlVisible = false
    toolPicker.addObserver(canvas) // Notify when the picker configuration changes
    canvas.becomeFirstResponder()

    canvas.delegate = context.coordinator
    return canvas
  }

  func updateUIView(_ uiView: PKCanvasView, context: Context) {
    if uiView.drawing != drawing {
      uiView.drawing = drawing
    }
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
