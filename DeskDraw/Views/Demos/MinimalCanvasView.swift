//
//  MinimalCanvasView.swift
//  DeskDraw
//
//  Minimal reproducible code for testing Muse stylus device
//

import PencilKit
import RealityKit
import SwiftUI

struct MinimalCanvasView: View {
  @State private var canvas = PKCanvasView()

  var body: some View {
    GeometryReader3D { proxy in
      let width = proxy.size.width
      let height = proxy.size.height
      let depth = proxy.size.depth

      RealityView { content, attachments in
        if let canvasView = attachments.entity(for: "canvasView") {
          canvasView.name = "canvasView"
          canvasView.setOrientation(.init(angle: -.pi / 2, axis: .init(x: 1, y: 0, z: 0)), relativeTo: nil)
          content.add(canvasView)
        }
      } attachments: {
        Attachment(id: "canvasView") {
          CanvasViewWrapper(canvas: canvas)
            .frame(width: width, height: depth)
            .colorScheme(.light)
        }
      }
      .frame(width: width, height: depth)
      .frame(depth: height)
      .offset(y: proxy.size.height / 2)
    }
  }
}

struct CanvasViewWrapper: UIViewRepresentable {
  let canvas: PKCanvasView

  func makeUIView(context: Context) -> PKCanvasView {
    canvas.drawingPolicy = .anyInput
    canvas.tool = PKInkingTool(.pen, color: .black)
    return canvas
  }

  func updateUIView(_ uiView: PKCanvasView, context: Context) { }
}

