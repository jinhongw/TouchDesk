//
//  DeskDrawApp.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/26.
//

import SwiftUI

@main
struct DeskDrawApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.openWindow) private var openWindow
  @State private var appModel = AppModel()
  @State private var drawingViewDisappeared = false

  var body: some Scene {
    WindowGroup(id: "drawingView") {
      DrawingView()
        .volumeBaseplateVisibility(.hidden)
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
    .defaultSize(width: 0.6, height: 0, depth: 0.3, in: .meters)
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
      return WindowPlacement(.utilityPanel, size: CGSize.init(width: 480, height: 760))
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
      return WindowPlacement(.utilityPanel, size: CGSize.init(width: 480, height: 760))
    }
  }
}
