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
  @Environment(\.dismissWindow) var dismissWindow
  @State var canvas = PKCanvasView()
  @State var boradHeight: Float = 0
  
  @State var toolStatus: CanvasToolStatus = .ink
  @State var pencilType: PKInkingTool.InkType = .pen
  @State var eraserType: EraserType = .bitmap
  
  @State var penWidth: CGFloat = 0.88
  @State var monolineWidth: CGFloat = 0.5
  @State var pencilWidth: CGFloat = 2.41
  @State var crayonWidth: CGFloat = 30
  @State var fountainPenWidth: CGFloat = 4.625
  @State var eraserWidth: CGFloat = 16.4
  
  @State var isSettingPen = false
  @State var isSettingMonoline = false
  @State var isSettingPencil = false
  @State var isSettingCrayon = false
  @State var isSettingFountainPen = false
  @State var isSettingEraser = false
  
  let zOffset: CGFloat = 72
  
  enum CanvasToolStatus {
    case ink
    case eraser
    case lasso
  }
  
  enum EraserType: Hashable {
    case bitmap
    case vector
  }

  var body: some View {
    GeometryReader3D { proxy in
      let _ = print(#function, "proxy \(proxy.size)")
      miniView(proxy: proxy)
        .overlay {
          drawingRealityView(proxy: proxy)
            .scaleEffect(appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 1 : 0, anchor: .bottom)
            .opacity(appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 1 : 0)
            .disabled(!appModel.showDrawing || appModel.showNotes || appModel.hideInMini)
        }
        .overlay {
          topToolbarView(proxy: proxy)
            .scaleEffect(appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 1 : 0, anchor: .bottom)
            .opacity(appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 1 : 0)
            .disabled(!appModel.showDrawing || appModel.showNotes || appModel.hideInMini)
        }
        .overlay {
          notesView(proxy: proxy)
            .scaleEffect(appModel.showNotes && !appModel.hideInMini ? 1 : 0, anchor: .bottom)
            .opacity(appModel.showNotes && !appModel.hideInMini ? 1 : 0)
            .disabled(!appModel.showNotes || appModel.hideInMini)
        }
        .animation(.spring, value: appModel.showDrawing)
        .animation(.spring, value: appModel.showNotes)
        .animation(.spring, value: appModel.hideInMini)
    }
  }

  @MainActor
  @ViewBuilder
  private func drawingRealityView(proxy: GeometryProxy3D) -> some View {
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
        drawingView(proxy: proxy)
          .cornerRadius(20)
          .frame(width: proxy.size.width, height: proxy.size.depth - zOffset)
          .colorScheme(.light)
      }
    }
    .frame(width: proxy.size.width)
    .frame(depth: proxy.size.depth - zOffset)
    .offset(y: proxy.size.height / 2)
    .offset(z: -proxy.size.depth + zOffset)
  }

  @MainActor
  @ViewBuilder
  private func notesView(proxy: GeometryProxy3D) -> some View {
    RealityView { content, attachments in
      if let notesView = attachments.entity(for: "notesView") {
        notesView.position = .init(x: 0, y: 0, z: 0)
        notesView.setOrientation(.init(angle: -.pi / 2, axis: .init(x: 1, y: 0, z: 0)), relativeTo: nil)
        content.add(notesView)
      }
    } update: { content, attachments in
      content.entities.forEach { entity in
        entity.position = .init(x: 0, y: boradHeight, z: 0)
      }
    } attachments: {
      Attachment(id: "notesView") {
        NotesView()
          .environment(appModel)
          .frame(width: proxy.size.width, height: proxy.size.depth - zOffset)
      }
    }
    .frame(width: proxy.size.width)
    .frame(depth: proxy.size.depth - zOffset)
    .offset(y: proxy.size.height / 2)
    .offset(z: -proxy.size.depth + zOffset)
  }

  @MainActor
  @ViewBuilder
  private func miniView(proxy: GeometryProxy3D) -> some View {
    RealityView { content in
      if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle), let pen = scene.findEntity(named: "fountain_pen") {
        print(#function, "fountain_pen \(pen)")
        content.add(pen)
      }
    }
    .offset(x: -proxy.size.width / 2 + zOffset / 2, y: proxy.size.height / 2)
    .offset(z: -proxy.size.depth / 2 + zOffset)
    .gesture(
      TapGesture().targetedToAnyEntity().onEnded { _ in
        print(#function, "onTapGesture")
        appModel.hideInMini.toggle()
      }
    )
  }

  @MainActor
  @ViewBuilder
  private func topToolbarView(proxy: GeometryProxy3D) -> some View {
    RealityView { content, attachments in
      if let toolbarView = attachments.entity(for: "toolbarView") {
        toolbarView.position = .init(x: 0, y: 0, z: 0)
        toolbarView.orientation = .init(angle: -45, axis: .init(x: 1, y: 0, z: 0))
        content.add(toolbarView)
      }
    } update: { content, attachments in
      content.entities.forEach { entity in
        entity.position = .init(x: 0, y: boradHeight, z: 0)
      }
    } attachments: {
      Attachment(id: "toolbarView") {
        tools
          .frame(width: proxy.size.width)
      }
    }
    .frame(width: proxy.size.width)
    .offset(y: proxy.size.height / 2 - zOffset)
    .offset(z: -proxy.size.depth + zOffset)
  }

  @MainActor
  @ViewBuilder
  private func drawingView(proxy: GeometryProxy3D) -> some View {
    @Bindable var appModel = appModel
    if appModel.dataModel.drawings.isEmpty {
      ProgressView()
    } else {
      DrawingUIViewRepresentable(
        canvas: $canvas,
        drawing: Binding(
          get: { appModel.dataModel.drawings[appModel.drawingIndex] },
          set: { newValue in
            appModel.dataModel.drawings[appModel.drawingIndex] = newValue
          }
        ),
        toolStatus: $toolStatus,
        pencilType: $pencilType,
        eraserType: $eraserType,
        penWidth: $penWidth,
        monolineWidth: $monolineWidth,
        pencilWidth: $pencilWidth,
        crayonWidth: $crayonWidth,
        fountainPenWidth: $fountainPenWidth,
        eraserWidth: $eraserWidth,
        color: $appModel.color,
        isLocked: $appModel.isLocked,
        canvasWidth: proxy.size.width,
        canvasHeight: proxy.size.height,
        saveDrawing: {
          appModel.updateDrawing(appModel.drawingIndex)
        }
      )
    }
  }
}

#Preview {
  DrawingView()
    .environment(AppModel())
}
