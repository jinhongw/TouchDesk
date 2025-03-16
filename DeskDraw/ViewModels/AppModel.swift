//
//  AppModel.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/27.
//

import Foundation
@preconcurrency import PencilKit
import SwiftUI

@MainActor
@Observable
class AppModel {
  let placeCanvasImmersiveViewModel = PlaceCanvasImmersiveViewModel()
  var subscriptionViewModel = SubscriptionViewModel()
  var drawings: [UUID : DrawingModel] = [:]
  var thumbnails: [UUID : UIImage] = [:]
  var ids = [UUID]()
  var deletedDrawings = [DrawingModel]()
  var drawingId: UUID? = nil
  var hideInMini = false
  var showDrawing = true
  var showNotes = false
  var color: Color = .white
  var isLocked = false
  var isInPlaceCanvasImmersive = false
  var isClosingPlaceCanvasImmersive = false
  var isOpeningPlaceCanvasImmersive = false
  var isBeginingPlacement = true
  var isShareImageViewShowing = false
  var exportImage: UIImage?

  /// The size to use for thumbnail images.
  static let thumbnailSize = CGSize(width: 512, height: 512)
  static let drawingIdKey = "drawingIdKey"
  /// Dispatch queues for the background operations done by this controller.
  private let thumbnailQueue = DispatchQueue(label: "ThumbnailQueue", qos: .background)
  private let serializationQueue = DispatchQueue(label: "SerializationQueue", qos: .background)

  enum ImmersiveSpaceID: String, CustomStringConvertible {
    case drawingImmersiveSpace
    var description: String { rawValue }
  }

  var thumbnailTraitCollection = UITraitCollection() {
    didSet {
      // If the user interface style changed, regenerate all thumbnails.
      if oldValue.userInterfaceStyle != thumbnailTraitCollection.userInterfaceStyle {
        generateAllThumbnails()
      }
    }
  }

  init() {
    loadDrawings()
    loadUserDefaults()
  }

  private func loadDrawings() {
    do {
      if !DrawingFileManager.shared.hasDrawings() {
        let oldDataURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/DeskDraw.data")
          ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("DeskDraw.data")
        
        if FileManager.default.fileExists(atPath: oldDataURL.path) {
          let decoder = PropertyListDecoder()
          let data = try Data(contentsOf: oldDataURL)
          let oldDataModel = try decoder.decode(LegacyDataModel.self, from: data)
          try DrawingFileManager.shared.migrateFromOldVersion(oldDataModel: oldDataModel)
        }
      }
      
      drawings = DrawingFileManager.shared.loadAllDrawings()
      ids = DrawingFileManager.shared.loadDrawingIndex()
      if drawings.isEmpty {
        addNewDrawing()
      }
      
      for id in drawings.keys {
        thumbnails[id] = UIImage()
      }
      generateAllThumbnails()
      
    } catch {
      logger.info("\(#function) Could not load drawings: \(error.localizedDescription)")
      addNewDrawing()
    }
  }

  private func loadUserDefaults() {
    if let lastDrawingIdString = UserDefaults.standard.value(forKey: AppModel.drawingIdKey) as? String,
       let lastDrawingId = UUID(uuidString: lastDrawingIdString)
    {
      drawingId = lastDrawingId
    } else {
      if let id = ids.first {
        print(#function, "id \(id)")
        selectDrawingId(id)
      } else {
        print(#function, "addNewDrawing")
        addNewDrawing()
      }
    }

    if let placementAssistance = UserDefaults.standard.value(forKey: "placementAssistance") as? Bool {
      isBeginingPlacement = placementAssistance
    }
  }

  func saveDrawing(_ id: UUID) {
    guard let drawing = drawings[id] else { return }
    if !ids.contains(id) {
      ids.insert(id, at: 0)
    }
    serializationQueue.async {
      do {
        try DrawingFileManager.shared.saveDrawing(drawing)
      } catch {
        logger.info("\(#function) Could not save drawing: \(error.localizedDescription)")
      }
    }
  }

  /// Helper method to cause regeneration of all thumbnails.
  private func generateAllThumbnails() {
    for id in drawings.keys {
      generateThumbnail(id)
    }
  }

  /// Helper method to cause regeneration of a specific thumbnail, using the current user interface style
  /// of the thumbnail view controller.
  func generateThumbnail(_ id: UUID, isFullScale: Bool = false) {
    guard let drawingModel = drawings[id] else { return }
    
    var drawing = PKDrawing()
    drawing.strokes = drawingModel.drawing.strokes.filter { stroke in
      stroke.ink.color.cgColor.alpha > 0
    }
    
    let thumbnailSize = AppModel.thumbnailSize
    
    var contentBounds = drawing.bounds
    for imageElement in drawingModel.images {
      let imageFrame = CGRect(origin: imageElement.position, size: imageElement.size)
      contentBounds = contentBounds.union(imageFrame)
    }
    
    if contentBounds.isNull || contentBounds.isEmpty {
      contentBounds = CGRect(x: 0, y: 0, width: thumbnailSize.width, height: thumbnailSize.height)
    }
    
    let minSize: CGFloat = 100
    if contentBounds.width < minSize || contentBounds.height < minSize {
      let center = CGPoint(x: contentBounds.midX, y: contentBounds.midY)
      contentBounds = CGRect(
        x: center.x - minSize/2,
        y: center.y - minSize/2,
        width: minSize,
        height: minSize
      )
    }
    
    let scale = isFullScale ? 2 : min(
      thumbnailSize.width / contentBounds.width,
      thumbnailSize.height / contentBounds.height
    )
    
    let finalSize = isFullScale ? 
      CGSize(width: contentBounds.width * scale, height: contentBounds.height * scale) :
      thumbnailSize
    
    thumbnailQueue.async {
      let format = UIGraphicsImageRendererFormat()
      format.opaque = false
      let renderer = UIGraphicsImageRenderer(size: finalSize, format: format)
      let finalImage = renderer.image { context in
        let drawingSize = CGSize(
          width: contentBounds.width * scale,
          height: contentBounds.height * scale
        )
        let drawingOrigin = isFullScale ?
          CGPoint.zero :
          CGPoint(
            x: (thumbnailSize.width - drawingSize.width) / 2,
            y: (thumbnailSize.height - drawingSize.height) / 2
          )
        
        for imageElement in drawingModel.images {
          if let image = UIImage(data: imageElement.imageData) {
            context.cgContext.saveGState()
            
            let relativeX = (imageElement.position.x - contentBounds.minX) * scale
            let relativeY = (imageElement.position.y - contentBounds.minY) * scale
            let scaledPosition = CGPoint(
              x: drawingOrigin.x + relativeX,
              y: drawingOrigin.y + relativeY
            )
            let scaledSize = CGSize(
              width: imageElement.size.width * scale,
              height: imageElement.size.height * scale
            )
            
            context.cgContext.translateBy(
              x: scaledPosition.x + scaledSize.width / 2,
              y: scaledPosition.y + scaledSize.height / 2
            )
            context.cgContext.rotate(by: imageElement.rotation)
            
            image.draw(in: CGRect(
              x: -scaledSize.width / 2,
              y: -scaledSize.height / 2,
              width: scaledSize.width,
              height: scaledSize.height
            ))
            
            context.cgContext.restoreGState()
          }
        }
        
        let drawingImage = drawing.thumbnail(
          rect: contentBounds,
          scale: scale,
          traitCollection: UITraitCollection(userInterfaceStyle: .light)
        )
        let drawingRect = CGRect(origin: drawingOrigin, size: drawingSize)
        drawingImage.draw(in: drawingRect)
      }
      
      DispatchQueue.main.async {
        if isFullScale {
          self.updateExportImage(finalImage)
        } else {
          self.updateThumbnail(finalImage, at: id)
        }
      }
    }
  }

  /// Helper method to replace a thumbnail at a given index.
  private func updateThumbnail(_ image: UIImage, at id: UUID) {
    thumbnails[id] = image
  }
  
  func updateExportImage(_ image: UIImage) {
    exportImage = image
  }

  var currentDrawing: DrawingModel? {
    guard let drawingId else { return nil }
    return drawings[drawingId]
  }
}

extension AppModel {
  func addNewDrawing() {
    var newDrawing = PKDrawing()
    let defaultStrokes = createDefaultStrokes()
    newDrawing.strokes = defaultStrokes
    
    let drawing = DrawingModel(
      name: "Drawing \(drawings.count + 1)",
      drawing: newDrawing
    )
    
    drawings[drawing.id] = drawing
    thumbnails[drawing.id] = UIImage()
    selectDrawingId(drawing.id)
    saveDrawing(drawing.id)
  }

  private func createDefaultStrokes() -> [PKStroke] {
    let edges = [
      [CGPoint(x: 0, y: 0)],
      [CGPoint(x: 200, y: 0)],
      [CGPoint(x: 200, y: 200)],
      [CGPoint(x: 0, y: 200)]
    ]
    
    return edges.map { edgePoints -> PKStroke in
      let controlPoints = edgePoints.map { point in
        PKStrokePoint(
          location: point,
          timeOffset: 0,
          size: CGSize(width: 5, height: 5),
          opacity: 1,
          force: 1,
          azimuth: 1,
          altitude: 1
        )
      }
      
      let path = PKStrokePath(controlPoints: controlPoints, creationDate: Date())
      let ink = PKInk(.pen, color: .clear)
      return PKStroke(ink: ink, path: path)
    }
  }

  /// Update a drawing at `id` and generate a new thumbnail.
  func updateDrawing(_ id: UUID?) {
    guard let id else { return }
    generateThumbnail(id)
    saveDrawing(id)
  }

  func deleteDrawing(_ id: UUID) {
    guard let drawing = drawings[id] else { return }
    deletedDrawings.append(drawing)
    
    do {
      try DrawingFileManager.shared.deleteDrawing(id: drawing.id)
      ids = DrawingFileManager.shared.loadDrawingIndex()
    } catch {
      logger.info("\(#function) Could not delete drawing file: \(error.localizedDescription)")
    }
    
    drawings.removeValue(forKey: id)
    thumbnails.removeValue(forKey: id)
    
    if drawings.isEmpty {
      addNewDrawing()
    }
  }

  func recoverNote() {
    if let recover = deletedDrawings.popLast() {
      drawings[recover.id] = recover
      thumbnails[recover.id] = UIImage()
      saveDrawing(recover.id)
    }
  }

  func selectDrawingId(_ id: UUID) {
    drawingId = id
    let idString = id.uuidString
    UserDefaults.standard.set(idString, forKey: AppModel.drawingIdKey)
  }
  
  func addImage(_ imageData: Data, at position: CGPoint, size: CGSize, rotation: Double = 0) {
    let imageElement = ImageElement(id: UUID(), imageData: imageData, position: position, size: size, rotation: rotation)
    guard let drawingId else { return }
    drawings[drawingId]?.images.append(imageElement)
    updateDrawing(drawingId)
  }
  
  func addText(_ text: String, at position: CGPoint, fontSize: CGFloat = 16, fontWeight: Font.Weight = .regular, color: Color = .black, rotation: Double = 0) {
    let textElement = TextElement(id: UUID(), text: text, position: position, fontSize: fontSize, fontWeight: fontWeight, color: color, rotation: rotation)
    guard let drawingId else { return }
    drawings[drawingId]?.texts.append(textElement)
    updateDrawing(drawingId)
  }
}

extension PKDrawing {
  func thumbnail(rect: CGRect, scale: CGFloat, traitCollection: UITraitCollection) -> UIImage {
    var image = UIImage()
    traitCollection.performAsCurrent {
      image = self.image(from: rect, scale: scale)
    }
    return image
  }
}

