//
//  HorizontalDrawingView.swift
//  DeskDraw

import AVFoundation
import PencilKit
import RealityKit
import RealityKitContent
import SwiftUI
import TipKit

struct HorizontalDrawingView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.openImmersiveSpace) private var openImmersiveSpace
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismissWindow) private var dismissWindow

  @AppStorage("penWidth") private var penWidth: Double = 0.88
  @AppStorage("monolineWidth") private var monolineWidth: Double = 0.5
  @AppStorage("pencilWidth") private var pencilWidth: Double = 2.41
  @AppStorage("crayonWidth") private var crayonWidth: Double = 30
  @AppStorage("fountainPenWidth") private var fountainPenWidth: Double = 4.625
  @AppStorage("eraserWidth") private var eraserWidth: Double = 16.4
  @AppStorage("eraserType") private var eraserType: EraserType = .bitmap
  @AppStorage("toolStatus") private var toolStatus: CanvasToolStatus = .ink
  @AppStorage("isSelectorActive") private var isSelectorActive: Bool = false
  @AppStorage("pencilType") private var pencilType: PKInkingTool.InkType = .pen
  @AppStorage("drawColor") private var drawColor: Color = .white
  @AppStorage("showMiniMap") private var showMiniMap = true
  @AppStorage("showZoomControlView") private var showZoomControlView = true
  @AppStorage("showQuickDrawingSwitch") private var showQuickDrawingSwitch = true
  @AppStorage("horizontalWindowWidth") private var horizontalWindowWidth: Double = 884
  @AppStorage("horizontalWindowHeight") private var horizontalWindowHeight: Double = 476
  @AppStorage("horizontalWindowDepth") private var horizontalWindowDepth: Double = 476

  @State private var canvas = PKCanvasView()
  @State private var lastCanvasPosition: AffineTransform3D? = nil
  @State private var canvasPositionHasChangedCount = 0
  @State private var placeCanvasTimer: Timer?
  @State private var zRotation: Double = 0
  @State private var verticalZOffest: CGFloat = 0
  @State private var horizontalYOffest: CGFloat = 0
  @State private var contentOffset: CGPoint = .zero

  private let toolDepth: CGFloat = 72
  let canvasId: UUID

  var body: some View {
    let displayState = appModel.canvasStates[canvasId]?.displayState ?? .drawing
    
    let _ = debugPrint(#function, "\(displayState)")
    GeometryReader3D { proxy in
      ZStack {
        miniView(width: proxy.size.width, height: proxy.size.height, depth: proxy.size.depth, displayState: displayState)
          .overlay {
            drawingRealityView(width: proxy.size.width, height: proxy.size.height, depth: proxy.size.depth, displayState: displayState)
              .scaleEffect(displayState == .drawing ? 1 : 0.1, anchor: displayState == .mini ? .leadingBack : .center)
              .opacity(displayState == .drawing ? 1 : 0)
              .blur(radius: displayState == .drawing ? 0 : 200)
              .disabled(displayState != .drawing)
              .offset(y: proxy.size.height / 2 + 1)
              .offset(z: -proxy.size.depth)
          }
          .overlay {
            notesView(width: proxy.size.width, height: proxy.size.height, depth: proxy.size.depth)
              .scaleEffect(displayState == .notes ? 1 : 0.1, anchor: displayState == .mini ? .leadingBack : .center)
              .blur(radius: displayState == .notes ? 0 : 200)
              .opacity(displayState == .notes ? 1 : 0)
              .disabled(displayState != .notes)
              .offset(y: proxy.size.height / 2 + 1)
              .offset(z: -proxy.size.depth)
          }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
      .frame(depth: proxy.size.depth)
      .animation(.spring, value: displayState)
      .onChange(of: proxy.size) { _, size in
        horizontalWindowWidth = size.width
        horizontalWindowHeight = size.height
        horizontalWindowDepth = size.depth
      }
    }
  }

  @MainActor
  @ViewBuilder
  private func miniView(width: CGFloat, height: CGFloat, depth: CGFloat, displayState: CanvasDisplayState) -> some View {
    RealityView { content in
      if let scene = try? await Entity(named: "logoScene", in: realityKitContentBundle), let logo = scene.findEntity(named: "logo") {
        content.add(logo)
      }
    }
    .hoverEffect(.highlight)
    .scaleEffect(displayState == .mini ? 1.2 : 0.8)
    .scaleEffect(displayState != .notes ? 1 : 0, anchor: .center)
    .blur(radius: displayState != .notes ? 0 : 200)
    .offset(x: -width / 2 + toolDepth / 2, y: height / 2)
    .offset(z: -depth / 2 + toolDepth / 2.7)
    .gesture(
      TapGesture().targetedToAnyEntity().onEnded { _ in
        AudioServicesPlaySystemSound(1104)
        appModel.canvasStates[canvasId]?.toggleMini()
      }
    )
    .animation(.spring.speed(2), value: displayState)
  }

  @MainActor
  @ViewBuilder
  private func drawingRealityView(width: CGFloat, height: CGFloat, depth: CGFloat, displayState: CanvasDisplayState) -> some View {
    RealityView { content, attachments in
      if let drawingView = attachments.entity(for: "drawingView") {
        drawingView.name = "drawingView"
        drawingView.setOrientation(.init(angle: -.pi / 2, axis: .init(x: 1, y: 0, z: 0)), relativeTo: nil)
        content.add(drawingView)
      }
    } attachments: {
      Attachment(id: "drawingView") {
        let _ = print(#function, "drawingRealityView width \(width) height \(depth - toolDepth)")
        drawingView(width: width, height: height, depth: depth)
          .cornerRadius(20)
          .frame(width: width, height: depth)
          .colorScheme(.light)
          .overlay(alignment: .bottomTrailing) {
            if showMiniMap || showZoomControlView {
              MiniMapView(canvas: canvas, isHorizontal: true, canvasId: canvasId, contentOffset: $contentOffset)
                .padding(16)
                .opacity(displayState == .drawing ? 1 : 0)
            }
          }
          .overlay(alignment: .bottomLeading) {
                    if showQuickDrawingSwitch {
          QuickDrawingSwitch(isHorizontal: true, canvasId: canvasId)
                .environment(appModel)
                .padding(16)
                .opacity(displayState == .drawing ? 1 : 0)
            }
          }
          .overlay(alignment: .topLeading) {
            topToolbarView(width: width, height: height, depth: depth, displayState: displayState)
              .offset(z: toolDepth * 1.3 )
              .offset(y: -20)
          }
      }
    }
    .frame(width: width, height: depth)
    .frame(depth: height)
  }

  @MainActor
  @ViewBuilder
  private func drawingView(width: CGFloat, height: CGFloat, depth: CGFloat) -> some View {
    @Bindable var appModel = appModel
    let canvasDrawingId = appModel.canvasStates[canvasId]?.drawingId
    if appModel.drawings.isEmpty || canvasDrawingId == nil {
      ProgressView()
    } else {
      DrawingUIViewRepresentable(
        model: Binding(
          get: {
            if let canvasDrawingId, let drawing = appModel.drawings[canvasDrawingId] {
              print(#function, "canvas show \(drawing.id)")
              return drawing
            } else if let firstDrawingId = appModel.ids.first, let firstDrawing = appModel.drawings[firstDrawingId] {
              appModel.canvasStates[canvasId]?.setDrawingId(firstDrawingId)
              print(#function, "canvas show first drawing \(firstDrawingId)")
              return firstDrawing
            } else {
              let newDrawingId = appModel.addNewDrawing()
              if let newDrawing = appModel.drawings[newDrawingId] {
                appModel.canvasStates[canvasId]?.setDrawingId(newDrawingId)
                print(#function, "canvas show new drawing \(newDrawingId)")
                return newDrawing
              }
              return DrawingModel(name: "", drawing: PKDrawing())
            }
          },
          set: { newValue in
            guard let canvasDrawingId else { return }
            print(#function, "canvas set \(canvasDrawingId)")
            appModel.drawings[canvasDrawingId] = newValue
          }
        ),
        toolStatus: $toolStatus,
        pencilType: $pencilType,
        eraserType: $eraserType,
        isSelectorActive: $isSelectorActive,
        penWidth: $penWidth,
        monolineWidth: $monolineWidth,
        pencilWidth: $pencilWidth,
        crayonWidth: $crayonWidth,
        fountainPenWidth: $fountainPenWidth,
        eraserWidth: $eraserWidth,
        color: $drawColor,
        isLocked: Binding(
          get: { appModel.canvasStates[canvasId]?.isLocked ?? false },
          set: { appModel.canvasStates[canvasId]?.setIsLocked($0) }
        ),
        isShareImageViewShowing: $appModel.isShareImageViewShowing,
        imageEditingId: Binding(
          get: { appModel.canvasStates[canvasId]?.imageEditingId ?? UUID() },
          set: { appModel.canvasStates[canvasId]?.setImageEditingId($0) }
        ),
        contentOffset: $contentOffset,
        zoomFactor: Binding(
          get: { appModel.canvasStates[canvasId]?.canvasZoomFactor ?? 100 },
          set: { appModel.canvasStates[canvasId]?.setCanvasZoomFactor($0) }
        ),
        canvas: canvas,
        canvasWidth: width,
        canvasHeight: depth - toolDepth,
        saveDrawing: {
          appModel.updateDrawing(canvasDrawingId)
        },
        updateExportImage: {
          guard let canvasDrawingId else { return }
          appModel.generateThumbnail(canvasDrawingId, isFullScale: true)
        },
        deleteImage: { imageId in
          appModel.deleteImage(imageId, from: canvasId)
        }
      )
    }
  }

  @MainActor
  @ViewBuilder
  private func notesView(width: CGFloat, height: CGFloat, depth: CGFloat) -> some View {
    RealityView { content, attachments in
      if let notesView = attachments.entity(for: "notesView") {
        notesView.position = .init(x: 0, y: 0, z: 0)
        notesView.setOrientation(.init(angle: -.pi / 2, axis: .init(x: 1, y: 0, z: 0)), relativeTo: nil)
        content.add(notesView)
      }
    } attachments: {
      Attachment(id: "notesView") {
        NotesView(canvas: canvas, canvasId: canvasId)
          .environment(appModel)
          .frame(width: width, height: depth)
      }
    }
    .frame(width: width)
    .frame(depth: depth)
  }

  @MainActor
  @ViewBuilder
  private func topToolbarView(width: CGFloat, height: CGFloat, depth: CGFloat, displayState: CanvasDisplayState) -> some View {
    DrawingToolsView(
      toolStatus: $toolStatus,
      pencilType: $pencilType,
      eraserType: $eraserType,
      isSelectorActive: $isSelectorActive,
      canvas: canvas,
      isHorizontal: true,
      canvasId: canvasId
    )
    .environment(appModel)
    .frame(width: width, height: 120)
    .scaleEffect(displayState == .drawing ? 1 : 0, anchor: .bottom)
  }
}

#Preview {
  HorizontalDrawingView(canvasId: UUID())
    .environment(AppModel())
}
