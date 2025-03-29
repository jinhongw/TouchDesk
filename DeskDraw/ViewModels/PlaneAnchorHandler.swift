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
  var isHorizontal: Bool = true
  var isGenerateMesh: Bool = false
  var isCollision: Bool = false

  private var planeEntities: [UUID: Entity] = [:]
  private var planeAnchorsByID: [UUID: PlaneAnchor] = [:]

  init(rootEntity: Entity, isGenerateMesh: Bool = false, isCollision: Bool = false) {
    self.rootEntity = rootEntity
    self.isGenerateMesh = isGenerateMesh
    self.isCollision = isCollision
  }

  var planeAnchors: [PlaneAnchor] {
    Array(planeAnchorsByID.values)
  }

  @MainActor
  func process(_ anchorUpdate: AnchorUpdate<PlaneAnchor>) async {
    let anchor = anchorUpdate.anchor
    guard anchor.alignment == (isHorizontal ? .horizontal : .vertical) else { return }

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

    if isGenerateMesh {
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
      }
    }

//    if isCollision {
//      // Generate a collision shape for the plane (for object placement and physics).
//      var shape: ShapeResource?
//      do {
//        let vertices = anchor.geometry.meshVertices.asSIMD3(ofType: Float.self)
//        shape = try await ShapeResource.generateStaticMesh(positions: vertices,
//                                                           faceIndices: anchor.geometry.meshFaces.asUInt16Array())
//      } catch {
//        print("Failed to create a static mesh for a plane anchor: \(error).")
//        return
//      }
//
//      if let shape {
//        var collisionGroup = PlaneAnchor.verticalCollisionGroup
//        if anchor.alignment == .horizontal {
//          collisionGroup = PlaneAnchor.horizontalCollisionGroup
//        }
//
//        entity.components.set(CollisionComponent(shapes: [shape], isStatic: true,
//                                                 filter: CollisionFilter(group: collisionGroup, mask: .all)))
//        // The plane needs to be a static physics body so that objects come to rest on the plane.
//        let physicsMaterial = PhysicsMaterialResource.generate()
//        let physics = PhysicsBodyComponent(shapes: [shape], mass: 0.0, material: physicsMaterial, mode: .static)
//        entity.components.set(physics)
//      }
//    }

    let existingEntity = planeEntities[anchor.id]
    planeEntities[anchor.id] = entity

    rootEntity.addChild(entity)
    existingEntity?.removeFromParent()
  }

  @MainActor
  func moveCanvas() {
    print(#function, "moveCanvas")
    guard !isGenerateMesh else { return }
    isGenerateMesh = true
    for id in planeEntities.keys {
      guard let anchor = planeAnchorsByID[id], let entity = planeEntities[id] else { break }
      var meshResource: MeshResource?
      do {
        let contents = MeshResource.Contents(planeGeometry: anchor.geometry)
        meshResource = try MeshResource.generate(from: contents)
      } catch {
        print("Failed to create a mesh resource for a plane anchor: \(error).")
        return
      }
      if let meshResource {
        entity.components.set(ModelComponent(mesh: meshResource, materials: [OcclusionMaterial()]))
      }
    }
  }
  
  @MainActor
  func clearPlanes(isHorizontal: Bool) {
    self.isHorizontal = isHorizontal
    for id in planeEntities.keys {
      guard let anchor = planeAnchorsByID[id], let entity = planeEntities[id]  else { break }
      entity.removeFromParent()
    }
    planeEntities = [:]
    planeAnchorsByID = [:]
  }
}
