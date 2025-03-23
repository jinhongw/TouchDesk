//
//  ContentView.swift
//  PKDraw

import AVFoundation
import PencilKit
import RealityKit
import RealityKitContent
import SwiftUI
import TipKit

struct DrawingView: View {
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
  @AppStorage("isHorizontal") private var isHorizontal: Bool = true
  @AppStorage("placementAssistance") private var placementAssistance = true
  @AppStorage("showGestureGuide") private var showGestureGuide = true
  @AppStorage("drawColor") private var drawColor: Color = .white

  @State private var canvas = PKCanvasView()
  @State private var lastCanvasPosition: AffineTransform3D? = nil
  @State private var canvasPositionHasChangedCount = 0
  @State private var placeCanvasTimer: Timer?
  @State private var zRotation: Double = 0
  @State private var verticalZOffest: CGFloat = 0
  @State private var horizontalYOffest: CGFloat = 0
  @State private var contentOffset: CGPoint = .zero

  let zOffset: CGFloat = 72
  let placeZOffset: CGFloat = 4

  enum CanvasToolStatus: Int, Hashable {
    case ink = 0
    case eraser = 1
  }

  enum EraserType: Int, Hashable {
    case bitmap = 0
    case vector = 1
  }

  var body: some View {
    GeometryReader3D { proxy in
      ZStack {
        miniView(width: proxy.size.width, height: proxy.size.height, depth: proxy.size.depth)
          .overlay {
            drawingRealityView(width: proxy.size.width, height: proxy.size.height, depth: proxy.size.depth)
              .scaleEffect(appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 1 : 0, anchor: .bottom)
              .opacity(appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini && !appModel.isInPlaceCanvasImmersive && !appModel.isBeginingPlacement ? 1 : 0)
              .disabled(!appModel.showDrawing || appModel.showNotes || appModel.hideInMini || appModel.isInPlaceCanvasImmersive || appModel.isBeginingPlacement)
          }
          .overlay {
            topToolbarView(width: proxy.size.width, height: proxy.size.height, depth: proxy.size.depth)
              .opacity(appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini && !appModel.isInPlaceCanvasImmersive && !appModel.isBeginingPlacement ? 1 : 0)
              .disabled(!appModel.showDrawing || appModel.showNotes || appModel.hideInMini || appModel.isInPlaceCanvasImmersive || appModel.isBeginingPlacement)
          }
          .overlay {
            if !appModel.isInPlaceCanvasImmersive && !appModel.isBeginingPlacement && !appModel.isOpeningPlaceCanvasImmersive {
              notesView(width: proxy.size.width, height: proxy.size.height, depth: proxy.size.depth)
                .scaleEffect(appModel.showNotes && !appModel.hideInMini ? 1 : 0, anchor: .bottom)
                .opacity(appModel.showNotes && !appModel.hideInMini ? 1 : 0)
                .disabled(!appModel.showNotes || appModel.hideInMini)
            }
          }
          .overlay {
            if (appModel.isInPlaceCanvasImmersive && !appModel.isClosingPlaceCanvasImmersive) || appModel.isBeginingPlacement {
              PlaceAssistView(width: proxy.size.width, height: proxy.size.height, depth: proxy.size.depth, placeZOffset: placeZOffset, zRotation: $zRotation, verticalZOffest: $verticalZOffest, horizontalYOffest: $horizontalYOffest)
                .environment(appModel)
                .onAppear {
                  onPlaceAssistViewAppear(proxy: proxy)
                }
                .onDisappear {
                  placeCanvasTimer?.invalidate()
                }
            }
          }
      }
      .frame(depth: proxy.size.depth)
      .rotation3DEffect(.init(degrees: isHorizontal ? 0 : zRotation), axis: (x: 0, y: 0, z: 1), anchor: .center)
      .rotation3DEffect(.init(radians: isHorizontal ? 0 : -.pi / 2), axis: (x: 1, y: 0, z: 0), anchor: .center)
      .offset(z: isHorizontal ? 0 : proxy.size.depth - zOffset * 1.5 + verticalZOffest)
      .offset(y: isHorizontal ? -horizontalYOffest : 0)
      .animation(.spring, value: appModel.showDrawing)
      .animation(.spring, value: appModel.showNotes)
      .animation(.spring, value: appModel.hideInMini)
      .animation(.spring, value: isHorizontal)
    }
  }

  @MainActor
  @ViewBuilder
  private func miniView(width: CGFloat, height: CGFloat, depth: CGFloat) -> some View {
    RealityView { content in
      if let scene = try? await Entity(named: "logoScene", in: realityKitContentBundle), let logo = scene.findEntity(named: "logo") {
        content.add(logo)
      }
    }
    .hoverEffect { effect, isActive, geometry in
      effect.animation(.spring) {
        $0.scaleEffect(isActive ? 1.2 : 1.0)
      }
    }
    .scaleEffect(appModel.hideInMini ? 1.1 : 0.8)
    .offset(x: -width / 2 + zOffset / 2, y: height / 2)
    .offset(z: -depth / 2 + zOffset / 2.7)
    .opacity(isHorizontal && !appModel.isInPlaceCanvasImmersive && !appModel.isBeginingPlacement ? 1 : 0)
    .gesture(
      TapGesture().targetedToAnyEntity().onEnded { _ in
        print(#function, "onTapGesture")
        AudioServicesPlaySystemSound(1104)
        appModel.hideInMini.toggle()
      }
    )
    .disabled(!isHorizontal || appModel.isInPlaceCanvasImmersive || appModel.isBeginingPlacement)
  }

  @MainActor
  @ViewBuilder
  private func drawingRealityView(width: CGFloat, height: CGFloat, depth: CGFloat) -> some View {
    RealityView { content, attachments in
      if let drawingView = attachments.entity(for: "drawingView") {
        drawingView.name = "drawingView"
        drawingView.setOrientation(.init(angle: -.pi / 2, axis: .init(x: 1, y: 0, z: 0)), relativeTo: nil)
        content.add(drawingView)
      }
    } attachments: {
      Attachment(id: "drawingView") {
        let _ = print(#function, "drawingRealityView width \(width) height \(depth - zOffset)")
        drawingView(width: width, height: height, depth: depth)
          .cornerRadius(20)
          .frame(width: width, height: depth)
          .colorScheme(.light)
          .overlay(alignment: .bottomTrailing) {
            MiniMapView(canvas: canvas, contentOffset: $contentOffset)
              .padding(20)
              .opacity(appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 1 : 0)
          }
      }
    }
    .frame(width: width)
    .frame(depth: depth)
    .offset(y: height / 2 - placeZOffset)
    .offset(z: -depth)
  }

  @MainActor
  @ViewBuilder
  private func drawingView(width: CGFloat, height: CGFloat, depth: CGFloat) -> some View {
    @Bindable var appModel = appModel
    if appModel.drawings.isEmpty || appModel.drawingId == nil {
      ProgressView()
    } else {
      DrawingUIViewRepresentable(
        canvas: canvas,
        model: Binding(
          get: {
            if let drawing = appModel.currentDrawing {
              print(#function, "canvas show \(drawing.id)")
              return drawing
            } else if let firstDrawingId = appModel.ids.first, let firstDrawing = appModel.drawings[firstDrawingId] {
              appModel.selectDrawingId(firstDrawingId)
              print(#function, "canvas show first drawing \(firstDrawingId)")
              return firstDrawing
            } else {
              appModel.addNewDrawing()
              if let newDrawingId = appModel.drawingId, let newDrawing = appModel.drawings[newDrawingId] {
                print(#function, "canvas show new drawing \(newDrawingId)")
                return newDrawing
              }
              return DrawingModel.init(name: "", drawing: PKDrawing())
            }
          },
          set: { newValue in
            guard let drawingId = appModel.drawingId else { return }
            print(#function, "canvas set \(drawingId)")
            appModel.drawings[drawingId] = newValue
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
        isLocked: $appModel.isLocked,
        isShareImageViewShowing: $appModel.isShareImageViewShowing,
        imageEditingId: $appModel.imageEditingId,
        contentOffset: $contentOffset,
        canvasWidth: width,
        canvasHeight: depth - zOffset,
        saveDrawing: {
          appModel.updateDrawing(appModel.drawingId)
        },
        updateExportImage: {
          guard let drawingId = appModel.drawingId else { return }
          appModel.generateThumbnail(drawingId, isFullScale: true)
        },
        deleteImage: { imageId in
          appModel.deleteImage(imageId)
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
        NotesView(canvas: canvas)
          .environment(appModel)
          .frame(width: width, height: depth - (isHorizontal ? zOffset : 0))
      }
    }
    .frame(width: width)
    .frame(depth: depth - (isHorizontal ? zOffset : 0))
    .offset(y: height / 2)
    .offset(z: isHorizontal ? -depth + zOffset : -depth)
  }

  @MainActor
  @ViewBuilder
  private func topToolbarView(width: CGFloat, height: CGFloat, depth: CGFloat) -> some View {
    DrawingToolsView(
      toolStatus: $toolStatus,
      pencilType: $pencilType,
      eraserType: $eraserType,
      isSelectorActive: $isSelectorActive,
      canvas: canvas
    )
    .environment(appModel)
    .frame(width: width, height: 44)
    .scaleEffect(appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 1 : 0, anchor: .bottom)
    .offset(y: appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 0 : zOffset)
    .offset(y: height / 2 - zOffset)
    .offset(z: isHorizontal ? -depth + zOffset / 1.5 : -zOffset / 1.5)
  }

  private func onPlaceAssistViewAppear(proxy: GeometryProxy3D) {
    guard appModel.isBeginingPlacement else { return }
    Task {
      appModel.isOpeningPlaceCanvasImmersive = true
      switch await openImmersiveSpace(id: AppModel.ImmersiveSpaceID.drawingImmersiveSpace.description) {
      case .opened:
        try await Task.sleep(for: .seconds(0.01))
        appModel.isInPlaceCanvasImmersive = true
        appModel.isBeginingPlacement = false
        appModel.isOpeningPlaceCanvasImmersive = false
      case .userCancelled, .error:
        fallthrough
      @unknown default: break
      }
    }

    lastCanvasPosition = proxy.transform(in: .immersiveSpace)
    placeCanvasTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
      print("Position check: \(String(describing: proxy.transform(in: .immersiveSpace)))")
      guard canvasPositionHasChangedCount <= 5 else {
        placeCanvasTimer?.invalidate()
        return
      }
      let position = proxy.transform(in: .immersiveSpace)
      if let last = lastCanvasPosition, last != position {
        print("Position changed: \(String(describing: position))")
        canvasPositionHasChangedCount += 1
        if canvasPositionHasChangedCount == 5 {
          Task {
            await appModel.placeCanvasImmersiveViewModel.planeAnchorHandler.moveCanvas()
          }
          placeCanvasTimer?.invalidate()
        }
      }
      lastCanvasPosition = position
    }
  }
}

#Preview {
  DrawingView()
    .environment(AppModel())
}
