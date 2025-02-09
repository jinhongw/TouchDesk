//
//  ImmersiveDrawingView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/2/9.
//

import SwiftUI
import RealityKit
import ARKit

struct ImmersiveDrawingView: View {
  let viewModel: ImmersiveDrawingViewModel
  var body: some View {
    RealityView { content in
      content.add(viewModel.setUpContentEntity())
    }
    .task {
      do {
        try await viewModel.session.run([viewModel.planeDetection])
      } catch {
        print(#function, "Failed to start session: \(error)")
      }
    }
    .task {
      await viewModel.planeDetectionUpdates()
    }
  }
}
