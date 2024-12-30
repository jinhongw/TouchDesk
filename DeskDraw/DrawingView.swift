//
//  ContentView.swift
//  PKDraw

import PencilKit
import RealityKit
import RealityKitContent
import SwiftUI

struct DrawingView: View {
  @Environment(AppModel.self) var appModel
  @Environment(\.openWindow) var openWindow
//  @State private var canvas = PKCanvasView()
  @State private var canvas = PKCanvasView()
  @State private var toolPicker = PKToolPicker()
  @State private var isDrawing = true
  @State private var color: Color = .black
  @State private var pencilType: PKInkingTool.InkType = .pencil
  @State private var colorPicker = false
  @State private var boradHeight: Float = 0

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
      } update: { content, attachments in
        content.entities.forEach { entity in
          entity.position = .init(x: 0, y: (entity.name == "drawingView" ? 0.001 : 0) + boradHeight, z: 0)
        }
      } attachments: {
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
        } update: { content, attachments in
          content.entities.forEach { entity in
            entity.position = .init(x: 0, y: boradHeight, z: 0)
          }
        } attachments: {
          Attachment(id: "toolbarView") {
            navigationBarTool
          }
        }
        .offset(y: proxy.size.height / 2 - 36)
        .offset(z: -proxy.size.depth + 60)
      }
    }
//    .toolbar {
//      ToolbarItem(placement: .bottomOrnament) {
//        Button(action: {
//          openWindow(id: "ToolWindow")
//        }, label: {
//          Text("Open Tool Window")
//        })
//      }
//    }
//    .onAppear {
//      openWindow(id: "NotesView")
//    }
  }

  @MainActor
  @ViewBuilder
  private var drawingView: some View {
//    @Bindable var appModel = appModel
    if appModel.dataModel.drawings.isEmpty {
      ProgressView()
    } else {
      DrawingUIView(canvas: $canvas, drawing: Binding(
        get: { appModel.dataModel.drawings[appModel.drawingIndex] },
        set: { newValue in
          appModel.dataModel.drawings[appModel.drawingIndex] = newValue
        }
      ), isDrawing: $isDrawing, pencilType: $pencilType, color: $color, toolPicker: $toolPicker)
    }
  }

  @MainActor
  @ViewBuilder
  private var navigationBarTool: some View {
    HStack {
      Button(action: {
        openWindow(id: "NotesView")
//        appModel.saveNewNote(drawing: canvas.drawing)
      }, label: {
        Label("Home", systemImage: "square.grid.2x2")
      })
//      Slider(value: $boradHeight, in: -0.5...0.5)
    }
    .padding(12)
    .buttonStyle(.plain)
    .controlSize(.small)
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
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

#Preview {
  DrawingView()
}
