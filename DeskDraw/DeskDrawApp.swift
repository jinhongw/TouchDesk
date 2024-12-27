//
//  DeskDrawApp.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/26.
//

import SwiftUI

@main
struct DeskDrawApp: App {
  var body: some Scene {
    WindowGroup {
      FreeFormDrawingView()
        .volumeBaseplateVisibility(.hidden)
    }
    .windowStyle(.volumetric)
    .volumeWorldAlignment(.gravityAligned)
    .defaultSize(width: 0.8, height: 0.5, depth: 0.5, in: .meters)
    .windowResizability(.contentSize)
  }
}
