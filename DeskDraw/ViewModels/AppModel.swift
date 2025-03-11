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
      // 检查新版本数据目录是否存在数据
      if !DrawingFileManager.shared.hasDrawings() {
        // 如果新版本目录没有数据，尝试从旧版本迁移
        let oldDataURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/DeskDraw.data")
          ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("DeskDraw.data")
        
        if FileManager.default.fileExists(atPath: oldDataURL.path) {
          // 迁移旧版本数据
          let decoder = PropertyListDecoder()
          let data = try Data(contentsOf: oldDataURL)
          let oldDataModel = try decoder.decode(LegacyDataModel.self, from: data)
          try DrawingFileManager.shared.migrateFromOldVersion(oldDataModel: oldDataModel)
          // 不删除旧文件，保留作为备份
        }
      }
      
      // 加载所有绘图
      drawings = DrawingFileManager.shared.loadAllDrawings()
      ids = DrawingFileManager.shared.loadDrawingIndex()
      if drawings.isEmpty {
        addNewDrawing() // 如果没有绘图，创建一个新的
      }
      
      // 初始化缩略图数组
      for id in drawings.keys {
        thumbnails[id] = UIImage()
      }
      generateAllThumbnails()
      
    } catch {
      logger.info("\(#function) Could not load drawings: \(error.localizedDescription)")
      // 如果加载失败，创建一个新的绘图
      addNewDrawing()
    }
  }

  private func loadUserDefaults() {
    if let lastDrawingIdString = UserDefaults.standard.value(forKey: AppModel.drawingIdKey) as? String,
       let lastDrawingId = UUID(uuidString: lastDrawingIdString)
    {
      drawingId = lastDrawingId
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
  private func generateThumbnail(_ id: UUID) {
    guard let drawingModel = drawings[id] else { return }
    let drawing = drawingModel.drawing
    
    // 在主线程获取缩略图尺寸
    let thumbnailSize = AppModel.thumbnailSize
    
    // 计算整个内容的边界（包括绘画和图片）
    var contentBounds = drawing.bounds
    for imageElement in drawingModel.images {
      let imageFrame = CGRect(origin: imageElement.position, size: imageElement.size)
      contentBounds = contentBounds.union(imageFrame)
    }
    
    // 如果没有内容，使用默认大小
    if contentBounds.isNull || contentBounds.isEmpty {
      contentBounds = CGRect(x: 0, y: 0, width: thumbnailSize.width, height: thumbnailSize.height)
    }
    
    // 确保边界至少有最小尺寸
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
    
    // 计算缩略图尺寸，保持宽高比
    let scale = min(
      thumbnailSize.width / contentBounds.width,
      thumbnailSize.height / contentBounds.height
    )
    
    thumbnailQueue.async {
      // 创建一个和最终缩略图同样大小的上下文，支持透明度
      let format = UIGraphicsImageRendererFormat()
      format.opaque = false
      let renderer = UIGraphicsImageRenderer(size: thumbnailSize, format: format)
      let finalImage = renderer.image { context in
        // 不需要设置背景色，保持透明
        
        // 计算绘制区域，使内容居中
        let drawingSize = CGSize(
          width: contentBounds.width * scale,
          height: contentBounds.height * scale
        )
        let drawingOrigin = CGPoint(
          x: (thumbnailSize.width - drawingSize.width) / 2,
          y: (thumbnailSize.height - drawingSize.height) / 2
        )
        let drawingRect = CGRect(origin: drawingOrigin, size: drawingSize)
        
        // 首先绘制图片
        for imageElement in drawingModel.images {
          if let image = UIImage(data: imageElement.imageData) {
            // 保存当前的图形状态
            context.cgContext.saveGState()
            
            // 计算图片在缩略图中的位置和大小
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
            
            // 设置旋转变换
            context.cgContext.translateBy(
              x: scaledPosition.x + scaledSize.width / 2,
              y: scaledPosition.y + scaledSize.height / 2
            )
            context.cgContext.rotate(by: imageElement.rotation)
            
            // 绘制图片
            image.draw(in: CGRect(
              x: -scaledSize.width / 2,
              y: -scaledSize.height / 2,
              width: scaledSize.width,
              height: scaledSize.height
            ))
            
            // 恢复图形状态
            context.cgContext.restoreGState()
          }
        }
        
        // 然后绘制绘画内容
        let drawingImage = drawing.thumbnail(
          rect: contentBounds,
          scale: scale,
          traitCollection: UITraitCollection(userInterfaceStyle: .light)
        )
        drawingImage.draw(in: drawingRect)
      }
      
      DispatchQueue.main.async {
        self.updateThumbnail(finalImage, at: id)
      }
    }
  }

  /// Helper method to replace a thumbnail at a given index.
  private func updateThumbnail(_ image: UIImage, at id: UUID) {
    thumbnails[id] = image
  }

  var exportImage: UIImage {
    guard let drawing = currentDrawing?.drawing else {
      return UIImage()
    }
    guard !drawing.bounds.isNull && !drawing.strokes.isEmpty && !drawing.bounds.width.isNaN && !drawing.bounds.height.isNaN else {
      return UIImage()
    }
    let minSize: CGFloat = 1024
    let scale = max(2.0, minSize / max(drawing.bounds.width, drawing.bounds.height))
    let image = drawing.thumbnail(rect: drawing.bounds, scale: scale, traitCollection: UITraitCollection(userInterfaceStyle: .light))
    return image
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
//    drawings[id]?.modifiedAt = Date()
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
  
  // 添加图片到当前绘图
  func addImage(_ imageData: Data, at position: CGPoint, size: CGSize, rotation: Double = 0) {
    let imageElement = ImageElement(id: UUID(), imageData: imageData, position: position, size: size, rotation: rotation)
    guard let drawingId else { return }
    drawings[drawingId]?.images.append(imageElement)
    updateDrawing(drawingId)
  }
  
  // 添加文字到当前绘图
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

