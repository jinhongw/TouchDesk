//
//  ImmersiveCanvasViewModel.swift
//  DeskDraw
//
//  Created by jinhong on 2025/3/6.
//

import ARKit
import RealityKit
import SwiftUI

@MainActor
class ImmersiveCanvasViewModel {
  private let session = ARKitSession()
  private let worldTracking = WorldTrackingProvider()
  private let planeDetection = PlaneDetectionProvider(alignments: [.horizontal, .vertical])
  private var rootEntity: Entity
  var planeAnchorHandler: PlaneAnchorHandler
  
  var dataProvidersAreSupported: Bool {
    PlaneDetectionProvider.isSupported
  }

  @MainActor
  init() {
    let root = Entity()
    rootEntity = root
    planeAnchorHandler = PlaneAnchorHandler(rootEntity: root, isGenerateMesh: true, isCollision: true)
  }

  func setUpContentEntity() -> Entity {
    print(#function, "setUpContentEntity")
    return rootEntity
  }

  func planeDetectionUpdates() async {
    for await anchorUpdate in planeDetection.anchorUpdates {
      print(#function, "anchorUpdate \(anchorUpdate.description)")
      await planeAnchorHandler.process(anchorUpdate)
    }
  }
}
