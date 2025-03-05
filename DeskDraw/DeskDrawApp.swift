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

  var body: some Scene {
    WindowGroup(id: "drawingView") {
      DrawingView()
        .volumeBaseplateVisibility(volumeBaseplateVisibility ? (!appModel.showDrawing || appModel.showNotes || appModel.hideInMini || appModel.isInPlaceCanvasImmersive || appModel.isBeginingPlacement ? .hidden : .automatic) : .hidden)
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
      return WindowPlacement(.above(context.windows.first!), size: CGSize.init(width: 620, height: 480))
    }
    
    WindowGroup(id: "colorPicker") {
      ColorPickerView()
        .environment(appModel)
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
      ShareImageView(image: appModel.exportImage)
    }
    .windowResizability(.contentSize)
    .defaultWindowPlacement { content, context in
      WindowPlacement(.utilityPanel, size: CGSize(width: 480, height: 420 + 480 * appModel.drawings[appModel.drawingIndex].bounds.height / appModel.drawings[appModel.drawingIndex].bounds.width))
    }

    ImmersiveSpace(id: AppModel.ImmersiveSpaceID.drawingImmersiveSpace.description) {
      PlaceCanvasImmersiveView(viewModel: appModel.placeCanvasImmersiveViewModel)
    }
    .immersionStyle(selection: $drawingImmersiveStyle, in: .mixed)
  }
}

let logger = Logger(subsystem: "jinhonn.com.DeskDraw", category: "general")
