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
      WindowPlacement(.above(context.windows.last!))
    }
    
    WindowGroup(id: "colorPicker") {
      ColorPickerView()
        .environment(appModel)
    }
    .windowResizability(.contentSize)
    .defaultWindowPlacement { content, context in
      WindowPlacement(.utilityPanel)
    }
  }
}

struct ColorPickerView: View {
  @Environment(AppModel.self) var appModel
  var body: some View {
    @Bindable var appModel = appModel
    ColorPicker("Pick color", selection: $appModel.color)
      .labelsHidden()
      .controlSize(.extraLarge)
  }
}
