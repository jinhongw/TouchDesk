//
//  PlaceCanvasImmersiveViewModel.swift
//  DeskDraw
//
//  Created by jinhong on 2025/2/9.
//

import ARKit
import RealityKit
import SwiftUI

@MainActor
class PlaceCanvasImmersiveViewModel {
  let session = ARKitSession()
  let planeDetection = PlaneDetectionProvider(alignments: [.horizontal, .vertical])
  private var rootEntity: Entity
  private var planeAnchorHandler: PlaneAnchorHandler
  
  var dataProvidersAreSupported: Bool {
    PlaneDetectionProvider.isSupported
  }

  @MainActor
  init() {
    let root = Entity()
    rootEntity = root
    planeAnchorHandler = PlaneAnchorHandler(rootEntity: root)
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
