//
//  ContentView.swift
//  PKDraw

import PencilKit
import RealityKit
import RealityKitContent
import SwiftUI

struct FreeFormDrawingView: View {
  @State private var canvas = PKCanvasView()
  @State private var isDrawing = true
  @State private var color: Color = .black
  @State private var pencilType: PKInkingTool.InkType = .pencil
  @State private var colorPicker = false

  @State private var isMessaging = false
  @State private var isVideoCalling = false
  @State private var isScreenSharing = false
  @State private var isRecording = false
  @Environment(\.dismiss) private var dismiss

  @State private var xAngle: Float = 0

  @Environment(\.undoManager) private var undoManager

  var body: some View {
    GeometryReader3D { proxy in
      let _ = print(#function, "proxy \(proxy.size)")
      RealityView { content, attachments in
        if let drawingView = attachments.entity(for: "drawingView") {
          drawingView.name = "drawingView"
          drawingView.setOrientation(.init(angle: -.pi / 2, axis: .init(x: 1, y: 0, z: 0)), relativeTo: nil)
          drawingView.position = .init(x: 0, y: 0.001, z: 0)
          content.add(drawingView)
        }
        if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle), let board = scene.findEntity(named: "Board") {
          print(#function, "board \(board)")
          content.add(board)
        }
      }
        attachments: {
        Attachment(id: "drawingView") {
          drawingView
            .cornerRadius(20)
            .frame(width: proxy.size.width, height: proxy.size.depth - 60)
        }
      }
      .offset(y: proxy.size.height / 2)
      .offset(z: 30)
      .overlay {
        RealityView { content, attachments in
          if let toolbarView = attachments.entity(for: "toolbarView") {
            toolbarView.position = .init(x: 0, y: 0, z: 0)
            toolbarView.components.set(BillboardComponent())
            content.add(toolbarView)
          }
        }
          attachments: {
          Attachment(id: "toolbarView") {
            toolbarView
          }
        }
        .offset(y: proxy.size.height / 2 - 36)
        .offset(z: -proxy.size.depth + 60)
      }
    }
  }

  @MainActor
  @ViewBuilder
  private var drawingView: some View {
    DrawingView(canvas: $canvas, isDrawing: $isDrawing, pencilType: $pencilType, color: $color)
  }

  @MainActor
  @ViewBuilder
  private var toolbarView: some View {
    HStack {
      Button {
        isDrawing = true
        pencilType = .pencil
      } label: {
        VStack(spacing: 8) {
          Image(systemName: "pencil.and.scribble")
          Text("Pencil")
            .foregroundStyle(.white)
        }
      }

      Button {
        isDrawing = true
        pencilType = .pen
      } label: {
        VStack(spacing: 8) {
          Image(systemName: "applepencil.tip")
          Text("Pen")
            .foregroundStyle(.white)
        }
      }

      Button {
        isDrawing = false
      } label: {
        VStack(spacing: 8) {
          Image(systemName: "eraser.line.dashed")
          Text("Eraser")
            .foregroundStyle(.white)
        }
      }
    }
    .padding(12)
    .buttonStyle(.plain)
    .controlSize(.small)
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
  }

  func saveDrawing() {
    // Get the drawing image from the canvas
    let drawingImage = canvas.drawing.image(from: canvas.drawing.bounds, scale: 1.0)

    // Save drawings to the Photos Album
    UIImageWriteToSavedPhotosAlbum(drawingImage, nil, nil, nil)
  }
}

struct DrawingView: UIViewRepresentable {
  // Capture drawings for saving in the photos library
  @Binding var canvas: PKCanvasView
  @Binding var isDrawing: Bool
  // Ability to switch a pencil
  @Binding var pencilType: PKInkingTool.InkType
  // Ability to change a pencil color
  @Binding var color: Color

  // let ink = PKInkingTool(.pencil, color: .black)
  // Update ink type
  var ink: PKInkingTool {
    PKInkingTool(pencilType, color: UIColor(color))
  }

  let eraser = PKEraserTool(.bitmap)

  func makeUIView(context: Context) -> PKCanvasView {
    // Allow finger and pencil drawing
    canvas.drawingPolicy = .anyInput

    canvas.tool = isDrawing ? ink : eraser
//    canvas.transform = .init(rotationAngle: .pi / 2)
    canvas.isRulerActive = true
    canvas.backgroundColor = .init(red: 0, green: 0, blue: 0, alpha: 1)
    // Use buttons as tools
    // canvas.tool = PKInkingTool(.fountainPen, color: .brown, width: 4)

    // From Brian Advent: Show the default toolpicker
//    canvas.alwaysBounceVertical = true

    let toolPicker = PKToolPicker()
    toolPicker.setVisible(true, forFirstResponder: canvas)
    toolPicker.addObserver(canvas) // Notify when the picker configuration changes
    canvas.becomeFirstResponder()

    return canvas
  }

  func updateUIView(_ uiView: PKCanvasView, context: Context) {
    // Update tool whenever the main view updates
    uiView.tool = isDrawing ? ink : eraser
  }
}

#Preview {
  FreeFormDrawingView()
}
