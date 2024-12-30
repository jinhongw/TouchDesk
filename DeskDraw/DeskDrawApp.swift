//
//  DeskDrawApp.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/26.
//

import SwiftUI

@main
struct DeskDrawApp: App {
  @State var appModel = AppModel()
  var body: some Scene {
    WindowGroup {
      DrawingView()
        .volumeBaseplateVisibility(.hidden)
        .environment(appModel)
    }
    .windowStyle(.volumetric)
    .volumeWorldAlignment(.gravityAligned)
    .defaultSize(width: 0.6, height: 0, depth: 0.25, in: .meters)
    .windowResizability(.contentSize)
    
    WindowGroup(id: "NotesView") {
      NotesView()
        .environment(appModel)
    }
    .defaultWindowPlacement { content, context in
      return WindowPlacement(.above(context.windows.last!))
    }
  }
}
