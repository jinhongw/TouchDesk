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
  @AppStorage("pencilType") private var pencilType: PKInkingTool.InkType = .pen
  @AppStorage("isHorizontal") private var isHorizontal: Bool = true
  @AppStorage("placementAssistance") private var placementAssistance = true
  @AppStorage("showGestureGuide") private var showGestureGuide = true

  @State private var canvas = PKCanvasView()

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
              placeAssistView(width: proxy.size.width, height: proxy.size.height, depth: proxy.size.depth)
            }
          }
      }
      .frame(depth: proxy.size.depth)
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
        drawingView(width: width, height: height, depth: depth)
          .cornerRadius(20)
          .frame(width: width, height: depth - zOffset)
          .colorScheme(.light)
      }
    }
    .frame(width: width)
    .frame(depth: depth - zOffset)
    .offset(y: height / 2 - placeZOffset)
    .offset(z: isHorizontal ? -depth + zOffset : -depth)
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
          .frame(width: width, height: depth - zOffset)
      }
    }
    .frame(width: width)
    .frame(depth: depth - zOffset)
    .offset(y: height / 2)
    .offset(z: isHorizontal ? -depth + zOffset : -depth)
  }

  @MainActor
  @ViewBuilder
  private func topToolbarView(width: CGFloat, height: CGFloat, depth: CGFloat) -> some View {
    DrawingToolsView(
      canvas: canvas,
      toolStatus: $toolStatus,
      pencilType: $pencilType,
      eraserType: $eraserType
    )
    .environment(appModel)
    .frame(width: width, height: 44)
    .scaleEffect(appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 1 : 0, anchor: .bottom)
    .offset(y: appModel.showDrawing && !appModel.showNotes && !appModel.hideInMini ? 0 : zOffset)
    .offset(y: height / 2 - zOffset)
    .offset(z: isHorizontal ? -depth + zOffset / 1.5 : -zOffset / 1.5)
  }

  @MainActor
  @ViewBuilder
  private func drawingView(width: CGFloat, height: CGFloat, depth: CGFloat) -> some View {
    @Bindable var appModel = appModel
    if appModel.dataModel.drawings.isEmpty || appModel.dataModel.drawings.count - 1 < appModel.drawingIndex {
      ProgressView()
    } else {
      DrawingUIViewRepresentable(
        canvas: canvas,
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
        canvasWidth: width,
        canvasHeight: height,
        saveDrawing: {
          appModel.updateDrawing(appModel.drawingIndex)
        }
      )
    }
  }

  @MainActor
  @ViewBuilder
  private func placeAssistView(width: CGFloat, height: CGFloat, depth: CGFloat) -> some View {
    var text: AttributedString {
      var string = AttributedString(appModel.isBeginingPlacement ? NSLocalizedString("Click the button to start placing board", comment: "") : NSLocalizedString("Drag the board to any surface, \n it turns green when aligned.", comment: ""))
      if let range = string.range(of: "turns green") {
        string[range].foregroundColor = Color(red: 0.0, green: 0.8, blue: 0.0)
      } else if let range = string.range(of: "底色变绿") {
        string[range].foregroundColor = Color(red: 0.0, green: 0.8, blue: 0.0)
      } else if let range = string.range(of: "底色變綠") {
        string[range].foregroundColor = Color(red: 0.0, green: 0.8, blue: 0.0)
      } else if let range = string.range(of: "devient vert") {
        string[range].foregroundColor = Color(red: 0.0, green: 0.8, blue: 0.0)
      } else if let range = string.range(of: "wird grün") {
        string[range].foregroundColor = Color(red: 0.0, green: 0.8, blue: 0.0)
      } else if let range = string.range(of: "緑色に変わります") {
        string[range].foregroundColor = Color(red: 0.0, green: 0.8, blue: 0.0)
      } else if let range = string.range(of: "녹색으로 변합니다") {
        string[range].foregroundColor = Color(red: 0.0, green: 0.8, blue: 0.0)
      }
      return string
    }

    ZStack {
      PlaceAssistView(width: width, height: height, style: appModel.isBeginingPlacement ? .any : .blue)
        .animation(.spring, value: appModel.isBeginingPlacement)
      PlaceAssistView(width: width, height: height, style: .green)
        .offset(z: placeZOffset * 2)
        .opacity(appModel.isBeginingPlacement ? 0 : 0.3)
        .animation(.spring, value: appModel.isBeginingPlacement)
      VStack {
        Spacer(minLength: 0)
        HStack {
          Spacer(minLength: 0)
          Text(text)
            .font(.largeTitle)
            .fontDesign(.rounded)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
          Spacer(minLength: 0)
        }
        Spacer(minLength: 0)
      }
      .offset(z: placeZOffset * 2)
      VStack {
        Spacer(minLength: 0)
        Image("Arrow_11")
          .resizable()
          .scaledToFit()
          .frame(width: 80, height: 80)
        Spacer(minLength: 0)
      }
      .scaleEffect(appModel.isBeginingPlacement ? 0 : 1)
      .offset(y: (depth - zOffset) / 2 - 65)
      .offset(z: placeZOffset * 2)
      .animation(.spring, value: appModel.isBeginingPlacement)
      if appModel.isBeginingPlacement {
        HStack {
          Button(action: {
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
          }, label: {
            Text("Start align with surface")
          })
          .padding(6)
          .frame(height: 44)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
        .rotation3DEffect(.degrees(-75), axis: (1, 0, 0), anchor: .center)
        .offset(z: 200)
        .offset(y: -50)
      } else {
        HStack(spacing: 12) {
          HStack {
            Button(action: {
              Task {
                appModel.isClosingPlaceCanvasImmersive = true
                await dismissImmersiveSpace()
                print(#function, "dismissImmersiveSpace")
                try await Task.sleep(for: .seconds(0.01))
                appModel.isInPlaceCanvasImmersive = false
                appModel.isClosingPlaceCanvasImmersive = false
                print(#function, "isInImmersive false")
                if showGestureGuide {
                  dismissWindow(id: "gestureGuide")
                  openWindow(id: "gestureGuide")
                  showGestureGuide = false
                }
              }
            }, label: {
              Text("Aligned with surface")
            })
            .padding(6)
            .frame(height: 44)
          }
          .buttonStyle(.borderless)
          .controlSize(.small)
          .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
        }
        .rotation3DEffect(.degrees(-75), axis: (1, 0, 0), anchor: .center)
        .offset(z: 200)
        .offset(y: -50)
      }
    }
    .clipped()
    .padding(12)
    .frame(width: width, height: depth - zOffset)
    .clipped()
    .rotation3DEffect(.degrees(90), axis: (1, 0, 0), anchor: .center)
    .offset(y: height / 2)
    .offset(z: isHorizontal ? -depth / 2 + zOffset / 2 : -depth / 2 - zOffset / 2)
  }
}

#Preview {
  DrawingView()
    .environment(AppModel())
}
