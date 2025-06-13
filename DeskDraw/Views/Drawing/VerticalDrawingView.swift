//
//  VerticalDrawingView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/6/13.
//

import AVFoundation
import PencilKit
import RealityKit
import RealityKitContent
import SwiftUI
import TipKit

struct VerticalDrawingView: View {
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
  @AppStorage("placementAssistance") private var placementAssistance = false
  @AppStorage("drawColor") private var drawColor: Color = .white
  @AppStorage("showMiniMap") private var showMiniMap = true
  @AppStorage("showZoomControlView") private var showZoomControlView = true
  @AppStorage("showQuickDrawingSwitch") private var showQuickDrawingSwitch = true
  @AppStorage("verticalWindowWidth") private var verticalWindowWidth: Double = 1280
  @AppStorage("verticalWindowHeight") private var verticalWindowHeight: Double = 720

  @State private var canvas = PKCanvasView()
  @State private var lastCanvasPosition: AffineTransform3D? = nil
  @State private var canvasPositionHasChangedCount = 0
  @State private var placeCanvasTimer: Timer?
  @State private var zRotation: Double = 0
  @State private var verticalZOffest: CGFloat = 0
  @State private var horizontalYOffest: CGFloat = 0
  @State private var contentOffset: CGPoint = .zero

  private let toolHeight: CGFloat = 72

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        NotesView(canvas: canvas)
          .environment(appModel)
          .frame(width: proxy.size.width, height: proxy.size.height)
          .scaleEffect(appModel.showNotes && !appModel.hideInMini ? 1 : 0.1, anchor: appModel.hideInMini ? .leadingBack : .center)
          .blur(radius: appModel.showNotes && !appModel.hideInMini ? 0 : 200)
          .opacity(appModel.showNotes && !appModel.hideInMini ? 1 : 0)
          .disabled(!appModel.showNotes || appModel.hideInMini)
        drawingView(width: proxy.size.width, height: proxy.size.height)
          .colorScheme(.light)
          .scaleEffect(appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 1 : 0.1, anchor: appModel.hideInMini ? .leadingBack : .center)
          .opacity(appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 1 : 0)
          .blur(radius: appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 0 : 200)
          .disabled(!appModel.showDrawing || appModel.showNotes || appModel.hideInMini)
          .clipShape(RoundedRectangle(cornerRadius: 60, style: .continuous))
          .overlay(alignment: .bottomTrailing) {
            if showMiniMap || showZoomControlView {
              MiniMapView(canvas: canvas, isHorizontal: false, contentOffset: $contentOffset)
                .padding(16)
                .opacity(appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 1 : 0)
                .offset(y: -toolHeight)
            }
          }
          .overlay(alignment: .bottomLeading) {
            if showQuickDrawingSwitch {
              QuickDrawingSwitch(isHorizontal: false)
                .environment(appModel)
                .padding(16)
                .opacity(appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 1 : 0)
                .offset(y: -toolHeight)
            }
          }
          .overlay(alignment: .bottomLeading) {
            DrawingToolsView(
              toolStatus: $toolStatus,
              pencilType: $pencilType,
              eraserType: $eraserType,
              isSelectorActive: $isSelectorActive,
              canvas: canvas,
              isHorizontal: false
            )
            .environment(appModel)
            .frame(width: proxy.size.width, height: 120)
            .scaleEffect(appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 1 : 0, anchor: .bottom)
            .offset(z: 80)
          }
          .offset(z: -60)
      }
      .onChange(of: proxy.size) { _, size in
        verticalWindowWidth = size.width
        verticalWindowHeight = size.height
      }
    }
    .animation(.spring, value: appModel.showDrawing)
    .animation(.spring, value: appModel.showNotes)
    .animation(.spring, value: appModel.hideInMini)
  }
  
  @MainActor
  @ViewBuilder
  private func drawingView(width: CGFloat, height: CGFloat) -> some View {
    @Bindable var appModel = appModel
    if appModel.drawings.isEmpty || appModel.drawingId == nil {
      ProgressView()
    } else {
      DrawingUIViewRepresentable(
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
              return DrawingModel(name: "", drawing: PKDrawing())
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
        zoomFactor: $appModel.canvasZoomFactor,
        canvas: canvas,
        canvasWidth: width,
        canvasHeight: height,
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
}

#Preview {
  VerticalDrawingView()
    .environment(AppModel())
}
