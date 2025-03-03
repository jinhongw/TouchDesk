//
//  PlaneAnchorHandler.swift
//  DeskDraw
//
//  Created by jinhong on 2025/2/9.
//

import ARKit
import Foundation
import RealityKit

class PlaneAnchorHandler {
  var rootEntity: Entity

  // A map of plane anchor UUIDs to their entities.
  private var planeEntities: [UUID: Entity] = [:]

  // A dictionary of all current plane anchors based on the anchor updates received from ARKit.
  private var planeAnchorsByID: [UUID: PlaneAnchor] = [:]

  init(rootEntity: Entity) {
    self.rootEntity = rootEntity
  }

  var planeAnchors: [PlaneAnchor] {
    Array(planeAnchorsByID.values)
  }

  @MainActor
  func process(_ anchorUpdate: AnchorUpdate<PlaneAnchor>) async {
    let anchor = anchorUpdate.anchor

    if anchorUpdate.event == .removed {
      planeAnchorsByID.removeValue(forKey: anchor.id)
      if let entity = planeEntities.removeValue(forKey: anchor.id) {
        entity.removeFromParent()
      }
      return
    }

    planeAnchorsByID[anchor.id] = anchor

    let entity = Entity()
    entity.name = "Plane \(anchor.id)"
    entity.setTransformMatrix(anchor.originFromAnchorTransform, relativeTo: nil)

    var meshResource: MeshResource?
    do {
      let contents = MeshResource.Contents(planeGeometry: anchor.geometry)
      meshResource = try MeshResource.generate(from: contents)
    } catch {
      print("Failed to create a mesh resource for a plane anchor: \(error).")
      return
    }

    if let meshResource {
      // Make this plane occlude virtual objects behind it.
      entity.components.set(ModelComponent(mesh: meshResource, materials: [OcclusionMaterial()]))
//      entity.components.set(ModelComponent(mesh: meshResource, materials: [SimpleMaterial(color: .white, roughness: 1, isMetallic: false), OcclusionMaterial()]))
//      entity.components.set(OpacityComponent(opacity: 0.3))
    }

    let existingEntity = planeEntities[anchor.id]
    planeEntities[anchor.id] = entity

    rootEntity.addChild(entity)
    existingEntity?.removeFromParent()
  }
}

