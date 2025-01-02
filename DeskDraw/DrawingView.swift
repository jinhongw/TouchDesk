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
//  @State private var toolPicker = PKToolPicker()
  @State private var isDrawing = true
  @State private var pencilType: PKInkingTool.InkType = .pen
  @State private var boradHeight: Float = 0

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
        drawingView
          .cornerRadius(20)
          .frame(width: proxy.size.width, height: proxy.size.depth - 36)
      }
    }
    .frame(width: proxy.size.width)
    .frame(depth: proxy.size.depth - 36)
    .offset(y: proxy.size.height / 2)
    .offset(z:  -proxy.size.depth + 36)
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
          .frame(width: proxy.size.width, height: proxy.size.depth - 36)
      }
    }
    .frame(width: proxy.size.width)
    .frame(depth: proxy.size.depth - 36)
    .offset(y: proxy.size.height / 2)
    .offset(z:  -proxy.size.depth + 36)
  }

  @MainActor
  @ViewBuilder
  private func miniView(proxy: GeometryProxy3D) ->  some View {
    RealityView { content in
      if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle), let pen = scene.findEntity(named: "fountain_pen") {
        print(#function, "fountain_pen \(pen)")
        content.add(pen)
      }
    }
    .offset(x: -proxy.size.width / 2 + 36, y: proxy.size.height / 2)
    .offset(z: -proxy.size.depth / 2 + 36)
    .gesture(
      TapGesture().targetedToAnyEntity().onEnded({ _ in
        print(#function, "onTapGesture")
        appModel.hideInMini.toggle()
      })
    )
  }

  @MainActor
  @ViewBuilder
  private func topToolbarView(proxy: GeometryProxy3D) -> some View {
    RealityView { content, attachments in
      if let toolbarView = attachments.entity(for: "toolbarView") {
        toolbarView.position = .init(x: 0, y: 0, z: 0)
        toolbarView.orientation = .init(angle: -45, axis: .init(x: 1, y: 0, z: 0))
//        toolbarView.components.set(BillboardComponent())
        content.add(toolbarView)
      }
    } update: { content, attachments in
      content.entities.forEach { entity in
        entity.position = .init(x: 0, y: boradHeight, z: 0)
      }
    } attachments: {
      Attachment(id: "toolbarView") {
        navigationBarTool
          .frame(width: proxy.size.width)
      }
    }
    .frame(width: proxy.size.width)
    .offset(y: proxy.size.height / 2 - 36)
    .offset(z: -proxy.size.depth + 36)
  }

  @MainActor
  @ViewBuilder
  private var drawingView: some View {
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
        isDrawing: $isDrawing,
        pencilType: $pencilType,
        color: $appModel.color,
//        toolPicker: $toolPicker,
        saveDrawing: {
          appModel.updateDrawing(appModel.drawingIndex)
        }
      )
    }
  }

  @MainActor
  @ViewBuilder
  private var navigationBarTool: some View {
    @Bindable var appModel = appModel
    HStack(spacing: 8) {
      HStack {
        Button(action: {
          appModel.showNotes = true
        }, label: {
          Image(systemName: "square.grid.2x2")
            .frame(width: 20)
        })
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      
      HStack {
        Button(action: {
          appModel.hideDrawing()
        }, label: {
          Image(systemName: "arrow.down.right.and.arrow.up.left")
            .frame(width: 20)
        })
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))

      Spacer(minLength: 20)
      
      HStack {
        Button(action: {
          isDrawing = true
          pencilType = .pen
        }, label: {
          Image(systemName: "pencil.tip")
            .frame(width: 20)
        })
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .background(pencilType == .pen && isDrawing == true ? .white.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))

      HStack {
        Button(action: {
          isDrawing = true
          pencilType = .marker
        }, label: {
          Image(systemName: "paintbrush.pointed")
            .frame(width: 20)
        })
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .background(pencilType == .marker && isDrawing == true ? .white.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      
      HStack {
        Button(action: {
          isDrawing = false
        }, label: {
          Image(systemName: "eraser")
            .frame(width: 20)
        })
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .background(isDrawing == false ? .white.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      
      HStack {
        ColorPicker("", selection: $appModel.color)
          .disabled(true)
          .labelsHidden()
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .background(isDrawing == false ? .white.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      .onTapGesture {
        openWindow(id: "colorPicker")
      }
    }
    .padding(.leading, 60)
    .padding(.trailing, 20)
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
}

#Preview {
  DrawingView()
}
