//
//  ContentView.swift
//  PKDraw

import AVFoundation
import PencilKit
import RealityKit
import RealityKitContent
import SwiftUI

struct DrawingView: View {
  @Environment(AppModel.self) private var appModel

  @AppStorage("penWidth") private var penWidth: Double = 0.88
  @AppStorage("monolineWidth") private var monolineWidth: Double = 0.5
  @AppStorage("pencilWidth") private var pencilWidth: Double = 2.41
  @AppStorage("crayonWidth") private var crayonWidth: Double = 30
  @AppStorage("fountainPenWidth") private var fountainPenWidth: Double = 4.625
  @AppStorage("eraserWidth") private var eraserWidth: Double = 16.4
  @AppStorage("eraserType") private var eraserType: EraserType = .bitmap
  @AppStorage("toolStatus") private var toolStatus: CanvasToolStatus = .ink
  @AppStorage("pencilType") private var pencilType: PKInkingTool.InkType = .pen
  @AppStorage("isHorizontal") private var isHorizontal: Bool = true

  @State private var canvas = PKCanvasView()

  let zOffset: CGFloat = 72

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
      let _ = print(#function, "proxy \(proxy.size)")
      VStack {
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
          .overlay {
            changeRatioView(proxy: proxy)
              .scaleEffect(appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 1 : 0, anchor: .bottom)
              .opacity(appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 1 : 0)
              .disabled(!appModel.showDrawing || appModel.showNotes || appModel.hideInMini)
          }
      }
      .rotation3DEffect(.init(radians: isHorizontal ? 0 : -.pi / 2), axis: (x: 1, y: 0, z: 0), anchor: .center)
      .offset(z: isHorizontal ? 0 : proxy.size.depth - zOffset * 1.5)
      .animation(.spring, value: appModel.showDrawing)
      .animation(.spring, value: appModel.showNotes)
      .animation(.spring, value: appModel.hideInMini)
      .animation(.spring, value: isHorizontal)
    }
  }

  @MainActor
  @ViewBuilder
  private func drawingRealityView(proxy: GeometryProxy3D) -> some View {
    RealityView { content, attachments in
      if let drawingView = attachments.entity(for: "drawingView") {
        drawingView.name = "drawingView"
        drawingView.setOrientation(.init(angle: -.pi / 2, axis: .init(x: 1, y: 0, z: 0)), relativeTo: nil)
        content.add(drawingView)
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
    .offset(z: isHorizontal ? -proxy.size.depth + zOffset : -proxy.size.depth)
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
    .offset(z: isHorizontal ? -proxy.size.depth + zOffset : -proxy.size.depth)
  }

  @MainActor
  @ViewBuilder
  private func miniView(proxy: GeometryProxy3D) -> some View {
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
    .offset(x: -proxy.size.width / 2 + zOffset / 2, y: proxy.size.height / 2)
    .offset(z: -proxy.size.depth / 2 + zOffset / 2.7)
    .opacity(isHorizontal ? 1 : 0)
    .scaleEffect(isHorizontal ? 1 : 0, anchor: .bottomLeadingBack)
    .gesture(
      TapGesture().targetedToAnyEntity().onEnded { _ in
        print(#function, "onTapGesture")
        AudioServicesPlaySystemSound(1104)
        appModel.hideInMini.toggle()
      }
    )
    .disabled(!isHorizontal)
  }

  @MainActor
  @ViewBuilder
  private func topToolbarView(proxy: GeometryProxy3D) -> some View {
    RealityView { content, attachments in
      if let toolbarView = attachments.entity(for: "toolbarView") {
        toolbarView.name = "toolbarView"
        toolbarView.position = .init(x: 0, y: 0, z: 0)
        content.add(toolbarView)
      }
    } attachments: {
      Attachment(id: "toolbarView") {
        DrawingToolsView(
          canvas: $canvas,
          toolStatus: $toolStatus,
          pencilType: $pencilType,
          eraserType: $eraserType
        )
        .environment(appModel)
        .frame(width: proxy.size.width, height: 44)
      }
    }
    .frame(width: proxy.size.width)
    .offset(y: proxy.size.height / 2 - zOffset)
    .offset(z: isHorizontal ? -proxy.size.depth + zOffset / 1.5 : -zOffset / 1.5)
  }

  @MainActor
  @ViewBuilder
  private func drawingView(proxy: GeometryProxy3D) -> some View {
    @Bindable var appModel = appModel
    if appModel.dataModel.drawings.isEmpty || appModel.dataModel.drawings.count - 1 < appModel.drawingIndex {
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

  @MainActor
  @ViewBuilder
  private func changeRatioView(proxy: GeometryProxy3D) -> some View {
    let shapeWidth: CGFloat = 16
    VStack {
      HStack {
        LShape()
          .fill(.clear)
          .glassBackgroundEffect(in: LShape())
          .frame(width: shapeWidth, height: shapeWidth)
          .rotationEffect(.degrees(-90))
          .offset(x: -36, y: 36)
          .padding(36)
          .hoverEffect { effect, isActive, geometry in
            effect.animation(.default) {
              $0.opacity(isActive ? 1 : 0.6)
            }
          }
        Spacer()
        LShape()
          .fill(.clear)
          .glassBackgroundEffect(in: LShape())
          .frame(width: shapeWidth, height: shapeWidth)
          .rotationEffect(.degrees(0))
          .offset(x: 36, y: 36)
          .padding(36)
          .hoverEffect { effect, isActive, geometry in
            effect.animation(.default) {
              $0.opacity(isActive ? 1 : 0.6)
            }
          }
      }
      .opacity(isHorizontal ? 0 : 1)
      .scaleEffect(isHorizontal ? 0 : 1)
      Spacer()
      HStack {
        LShape()
          .fill(.clear)
          .glassBackgroundEffect(in: LShape())
          .frame(width: shapeWidth, height: shapeWidth)
          .rotationEffect(.degrees(-180))
          .offset(x: -36, y: 36)
          .padding(36)
          .hoverEffect { effect, isActive, geometry in
            effect.animation(.default) {
              $0.opacity(isActive ? 1 : 0.6)
            }
          }
        Spacer()
        LShape()
          .fill(.clear)
          .glassBackgroundEffect(in: LShape())
          .frame(width: shapeWidth, height: shapeWidth)
          .rotationEffect(.degrees(90))
          .offset(x: 36, y: 36)
          .padding(36)
          .hoverEffect { effect, isActive, geometry in
            effect.animation(.default) {
              $0.opacity(isActive ? 1 : 0.6)
            }
          }
      }
    }
    .frame(width: proxy.size.width, height: proxy.size.depth)
    .rotation3DEffect(.degrees(90), axis: (1, 0, 0), anchor: .center)
    .offset(y: proxy.size.height / 2 - 2)
    .offset(z: isHorizontal ? -proxy.size.depth / 2 : -proxy.size.depth / 2 - zOffset)
  }

  struct LShape: InsettableShape {
    var insetAmount: CGFloat = 0
    let cornerRadius: CGFloat = 4
    let widthRatio: CGFloat = 3

    func path(in rect: CGRect) -> Path {
      let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
      let radius = min(cornerRadius, insetRect.width / 6, insetRect.height / 6)
      print(#function, radius)
      var path = Path()

      path.move(to: CGPoint(x: insetRect.minX + radius, y: insetRect.minY))
      path.addLine(to: CGPoint(x: insetRect.maxX - radius * 1.5, y: insetRect.minY))
      path.addArc(
        center: CGPoint(x: insetRect.maxX - radius * 1.5, y: insetRect.minY + radius * 1.5),
        radius: radius * 1.5,
        startAngle: Angle(degrees: -90),
        endAngle: Angle(degrees: 0),
        clockwise: false
      )
      path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.maxY - radius))
      path.addArc(
        center: CGPoint(x: insetRect.maxX - radius, y: insetRect.maxY - radius),
        radius: radius,
        startAngle: Angle(degrees: 0),
        endAngle: Angle(degrees: 90),
        clockwise: false
      )
      path.addLine(to: CGPoint(x: insetRect.maxX * (widthRatio - 1) / widthRatio + radius, y: insetRect.maxY))
      path.addArc(
        center: CGPoint(x: insetRect.maxX * (widthRatio - 1) / widthRatio + radius, y: insetRect.maxY - radius),
        radius: radius,
        startAngle: Angle(degrees: 90),
        endAngle: Angle(degrees: 180),
        clockwise: false
      )
      path.addLine(to: CGPoint(x: insetRect.maxX * (widthRatio - 1) / widthRatio, y: insetRect.maxY / widthRatio + radius))
      path.addArc(
        center: CGPoint(x: insetRect.maxX * (widthRatio - 1) / widthRatio - radius, y: insetRect.maxY / widthRatio + radius),
        radius: radius,
        startAngle: Angle(degrees: 0),
        endAngle: Angle(degrees: -90),
        clockwise: true
      )
      path.addLine(to: CGPoint(x: insetRect.minX + radius, y: insetRect.maxY / widthRatio))
      path.addArc(
        center: CGPoint(x: insetRect.minX + radius, y: insetRect.maxY / widthRatio - radius),
        radius: radius,
        startAngle: Angle(degrees: 90),
        endAngle: Angle(degrees: 180),
        clockwise: false
      )
      path.addLine(to: CGPoint(x: insetRect.minX, y: insetRect.minY + radius))
      path.addArc(
        center: CGPoint(x: insetRect.minX + radius, y: insetRect.minY + radius),
        radius: radius,
        startAngle: Angle(degrees: 180),
        endAngle: Angle(degrees: 270),
        clockwise: false
      )

      path.closeSubpath()
      return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
      var shape = self
      shape.insetAmount += amount
      return shape
    }
  }
}

#Preview {
  DrawingView()
    .environment(AppModel())
}
