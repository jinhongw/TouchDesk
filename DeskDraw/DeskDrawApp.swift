//
//  DeskDrawApp.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/26.
//

import SwiftUI
import os

@main
struct DeskDrawApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.openWindow) private var openWindow
  @State private var appModel = AppModel()
  @State private var drawingViewDisappeared = false
  @State private var drawingImmersiveStyle: ImmersionStyle = .mixed
  
  @AppStorage("volumeBaseplateVisibility") private var volumeBaseplateVisibility = true
  @AppStorage("isHorizontal") private var isHorizontal: Bool = true

  var body: some Scene {
    WindowGroup(id: "drawingView") {
      DrawingView()
        .volumeBaseplateVisibility(volumeBaseplateVisibility ? (!appModel.showDrawing || appModel.showNotes || appModel.hideInMini || appModel.isInPlaceCanvasImmersive || appModel.isBeginingPlacement || !isHorizontal ? .hidden : .automatic) : .hidden)
        .environment(appModel)
        .task {
          await appModel.subscriptionViewModel.updatePurchasedProducts()
        }
        .onDisappear {
          drawingViewDisappeared = true
        }
    }
    .windowStyle(.volumetric)
    .volumeWorldAlignment(.gravityAligned)
    .upperLimbVisibility(.visible)
    .defaultSize(width: 0.65, height: 0.35, depth: 0.35, in: .meters)
    .windowResizability(.contentSize)
    .persistentSystemOverlays(appModel.hideInMini ? .hidden : .visible)
    .onChange(of: scenePhase) { oldValue, newValue in
      switch newValue {
      case .background:
        break
      case .inactive:
        break
      case .active:
        if drawingViewDisappeared {
          openWindow(id: "drawingView")
          drawingViewDisappeared = false
        }
      @unknown default: break
      }
    }

    WindowGroup(id: "about") {
      AboutView()
        .environment(appModel)
    }
    .windowResizability(.contentSize)
    .defaultWindowPlacement { content, context in
      WindowPlacement(.utilityPanel, size: CGSize(width: 480, height: 760))
    }
    
    WindowGroup(id: "gestureGuide") {
      NavigationStack {
        GestureGuideView()
      }
    }
    .windowResizability(.contentSize)
    .defaultWindowPlacement { content, context in
      return WindowPlacement(.utilityPanel, size: CGSize.init(width: 620, height: 1024))
    }
    
    WindowGroup(id: "colorPicker") {
      ColorPickerView()
    }
    .windowResizability(.contentSize)
    .defaultWindowPlacement { content, context in
      WindowPlacement(.utilityPanel)
    }

    WindowGroup(id: "subscription") {
      SubscriptionView(topPadding: 48)
        .environment(appModel.subscriptionViewModel)
    }
    .windowResizability(.contentSize)
    .defaultWindowPlacement { content, context in
      WindowPlacement(.utilityPanel, size: CGSize(width: 480, height: 760))
    }

    WindowGroup(id: "shareView") {
      ShareImageView(image: appModel.exportImage, bounds: appModel.currentDrawing?.bounds.size ?? .init(width: 320, height: 320))
        .onAppear {
          print(#function, "appModel.isShareImageViewShowing = true")
          appModel.isShareImageViewShowing = true
          guard let drawingId = appModel.drawingId else { return }
          appModel.generateThumbnail(drawingId, isFullScale: true)
        }
        .onDisappear {
          print(#function, "appModel.isShareImageViewShowing = false")
          appModel.isShareImageViewShowing = false
          appModel.exportImage = nil
        }
    }
    .windowResizability(.contentSize)
    .defaultWindowPlacement { content, context in
      guard let drawing = appModel.currentDrawing else {
        return WindowPlacement(.utilityPanel, size: CGSize(width: 480, height: 480))
      }
      return WindowPlacement(.utilityPanel, size: CGSize(width: 480, height: 460 + 480 * drawing.bounds.height / drawing.bounds.width))
    }
    
    WindowGroup(id: "imagePicker", for: CGPoint.self) { point in
      ImagePickerView(point: point.wrappedValue ?? .zero)
        .environment(appModel)
    }
    .windowResizability(.contentSize)
    .defaultWindowPlacement { content, context in
      WindowPlacement(.utilityPanel)
    }
    
    WindowGroup(id: "canvasInspectView") {
      CanvasInspectView()
        .environment(appModel)
    }
    .defaultWindowPlacement { content, context in
      guard let drawing = appModel.currentDrawing else {
        return WindowPlacement(.utilityPanel, size: CGSize(width: 1024, height: 1024))
      }
      return WindowPlacement(.utilityPanel, size: CGSize(width: max(1024, drawing.bounds.width + 120), height: max(1024, drawing.bounds.height + 120)))
    }

    ImmersiveSpace(id: AppModel.ImmersiveSpaceID.drawingImmersiveSpace.description) {
      PlaceCanvasImmersiveView(viewModel: appModel.placeCanvasImmersiveViewModel)
    }
    .immersionStyle(selection: $drawingImmersiveStyle, in: .mixed)
  }
}

let logger = Logger(subsystem: "jinhonn.com.DeskDraw", category: "general")
