//
//  PlaceCanvasImmersiveView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/2/9.
//

import SwiftUI
import RealityKit
import ARKit

struct PlaceCanvasImmersiveView: View {
  let viewModel: PlaceCanvasImmersiveViewModel
  var body: some View {
    RealityView { content in
      content.add(viewModel.setUpContentEntity())
    }
    .task {
      do {
        print(#function, "viewModel.dataProvidersAreSupported \(viewModel.dataProvidersAreSupported)")
        if viewModel.dataProvidersAreSupported {
          try await viewModel.session.run([viewModel.planeDetection])
        }
      } catch {
        print(#function, "Failed to start session: \(error)")
      }
    }
    .task {
      await viewModel.planeDetectionUpdates()
    }
  }
}
