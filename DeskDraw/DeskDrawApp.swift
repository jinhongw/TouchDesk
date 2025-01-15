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
  @State private var appModel = AppModel()

  var body: some Scene {
    WindowGroup {
      DrawingView()
        .volumeBaseplateVisibility(.hidden)
        .environment(appModel)
        .task {
          await appModel.subscriptionViewModel.updatePurchasedProducts()
        }
    }
    .windowStyle(.volumetric)
    .volumeWorldAlignment(.gravityAligned)
    .defaultSize(width: 0.6, height: 0, depth: 0.3, in: .meters)
    .windowResizability(.contentSize)
    .persistentSystemOverlays(appModel.hideInMini ? .hidden : .visible)
    
    WindowGroup(id: "colorPicker") {
      ColorPickerView()
        .environment(appModel)
    }
    .windowResizability(.contentSize)
    .defaultWindowPlacement { content, context in
      WindowPlacement(.utilityPanel)
    }
    
    WindowGroup(id: "about") {
      AboutView()
        .environment(appModel)
    }
    .windowResizability(.contentSize)
    .defaultWindowPlacement { content, context in
      return WindowPlacement(.utilityPanel, size: CGSize.init(width: 480, height: 740))
    }
    
    WindowGroup(id: "subscription") {
      SubscriptionView()
        .environment(appModel.subscriptionViewModel)
    }
    .windowResizability(.contentSize)
    .defaultWindowPlacement { content, context in
      return WindowPlacement(.utilityPanel, size: CGSize.init(width: 480, height: 740))
    }
  }
}
