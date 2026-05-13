//
//  AppModel.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/27.
//

import Foundation
@preconcurrency import PencilKit
import SwiftUI
import UIKit

@MainActor
@Observable
class AppModel {
  let placeCanvasImmersiveViewModel = PlaceCanvasImmersiveViewModel()
  var subscriptionViewModel = SubscriptionViewModel()
  var drawings: [UUID: DrawingModel] = [:]
  private(set) var thumbnails: [UUID: UIImage] = [:]
  private(set) var ids = [UUID]()
  private(set) var deletedDrawings = [DrawingModel]()
  var drawingId: UUID?
  var imageEditingId: UUID?
  var hideInMini = false
  var showDrawing = true
  var showNotes = false
  var isLocked = false
  var isInPlaceCanvasImmersive = false
  var isClosingPlaceCanvasImmersive = false
  var isOpeningPlaceCanvasImmersive = false
  var isBeginingPlacement = true
  var isShareImageViewShowing = false
  var isFullScreenWebActive = false
  var fullScreenWebId: UUID?
  var exportImage: UIImage?
  var aboutNavigationPath = NavigationPath()
  var canvasZoomFactor: Double = 100

  /// The size to use for thumbnail images.
  static let thumbnailSize = CGSize(width: 512, height: 512)
  static let drawingIdKey = "drawingIdKey"
  /// Dispatch queues for the background operations done by this controller.
  private let thumbnailQueue = DispatchQueue(label: "ThumbnailQueue", qos: .utility)
  private let serializationQueue = DispatchQueue(label: "SerializationQueue", qos: .utility)

  private var thumbnailTraitCollection = UITraitCollection() {
    didSet {
      // If the user interface style changed, regenerate all thumbnails.
      if oldValue.userInterfaceStyle != thumbnailTraitCollection.userInterfaceStyle {
        generateAllThumbnails()
      }
    }
  }

  private var thumbnailWorkItem: DispatchWorkItem?
  private let thumbnailDebounceInterval: TimeInterval = 0.5
  private var imageCache: [UUID: UIImage] = [:]
  private var videoThumbnailCache: [UUID: UIImage] = [:]
  private var webSnapshotCache: [UUID: UIImage] = [:]
  private var currentThumbnailId: UUID?
  
  var currentDrawing: DrawingModel? {
    guard let drawingId else { return nil }
    return drawings[drawingId]
  }

  enum ImmersiveSpaceID: String, CustomStringConvertible {
    case drawingImmersiveSpace
    var description: String { rawValue }
  }
  
  enum AboutRoute: Hashable {
    case setting
    case subscription
    case gestureGuide
    case credit
  }

  init() {
    loadDrawings()
    loadUserDefaults()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleMemoryWarning),
      name: UIApplication.didReceiveMemoryWarningNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
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
        addDefulatDrawing()
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
    // 如果正在处理同一个ID的缩略图，取消之前的任务
    if currentThumbnailId == id {
      thumbnailWorkItem?.cancel()
    }

    currentThumbnailId = id

    // 创建新的任务
    let workItem = DispatchWorkItem { [weak self] in
      guard let self = self else { return }
      self._generateThumbnail(id, isFullScale: isFullScale)
    }

    // 保存引用以便后续取消
    thumbnailWorkItem = workItem

    // 延迟执行
    DispatchQueue.main.asyncAfter(deadline: .now() + thumbnailDebounceInterval, execute: workItem)
  }

  private func _generateThumbnail(_ id: UUID, isFullScale: Bool = false) {
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
    for videoElement in drawingModel.videos {
      let videoFrame = CGRect(origin: videoElement.position, size: videoElement.size)
      contentBounds = contentBounds.union(videoFrame)
    }
    // 将网页元素的区域纳入整体边界（缩略图不实际渲染网页，仅用于裁剪范围）
    for webElement in drawingModel.webs {
      let webFrame = CGRect(origin: webElement.position, size: webElement.size)
      contentBounds = contentBounds.union(webFrame)
    }

    if contentBounds.isNull || contentBounds.isEmpty {
      contentBounds = CGRect(x: 0, y: 0, width: thumbnailSize.width, height: thumbnailSize.height)
    }

    let minSize: CGFloat = 100
    if contentBounds.width < minSize || contentBounds.height < minSize {
      let center = CGPoint(x: contentBounds.midX, y: contentBounds.midY)
      contentBounds = CGRect(
        x: center.x - minSize / 2,
        y: center.y - minSize / 2,
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

    thumbnailQueue.async { [weak self] in
      guard let self = self else { return }

      let format = UIGraphicsImageRendererFormat()
      format.opaque = false

      let renderer = UIGraphicsImageRenderer(size: finalSize, format: format)

      autoreleasepool {
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
            if let image = DispatchQueue.main.sync(execute: { self.getOrCreateImage(from: imageElement.imageData, id: imageElement.id) }) {
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
          for videoElement in drawingModel.videos {
            if let thumbnail = DispatchQueue.main.sync(execute: { self.getOrCreateVideoThumbnail(for: videoElement) }) {
              context.cgContext.saveGState()

              let relativeX = (videoElement.position.x - contentBounds.minX) * scale
              let relativeY = (videoElement.position.y - contentBounds.minY) * scale
              let scaledPosition = CGPoint(
                x: drawingOrigin.x + relativeX,
                y: drawingOrigin.y + relativeY
              )
              let scaledSize = CGSize(
                width: videoElement.size.width * scale,
                height: videoElement.size.height * scale
              )

              context.cgContext.translateBy(
                x: scaledPosition.x + scaledSize.width / 2,
                y: scaledPosition.y + scaledSize.height / 2
              )
              context.cgContext.rotate(by: videoElement.rotation)

              let videoRect = CGRect(
                x: -scaledSize.width / 2,
                y: -scaledSize.height / 2,
                width: scaledSize.width,
                height: scaledSize.height
              )
              thumbnail.draw(in: videoRect)
              Self.drawVideoPlayBadge(context: context.cgContext, rect: videoRect)

              context.cgContext.restoreGState()
            }
          }
          for webElement in drawingModel.webs {
            context.cgContext.saveGState()
            let relativeX = (webElement.position.x - contentBounds.minX) * scale
            let relativeY = (webElement.position.y - contentBounds.minY) * scale
            let scaledPosition = CGPoint(
              x: drawingOrigin.x + relativeX,
              y: drawingOrigin.y + relativeY
            )
            let scaledSize = CGSize(
              width: webElement.size.width * scale,
              height: webElement.size.height * scale
            )
            context.cgContext.translateBy(
              x: scaledPosition.x + scaledSize.width / 2,
              y: scaledPosition.y + scaledSize.height / 2
            )
            context.cgContext.rotate(by: webElement.rotation)
            let webRect = CGRect(
              x: -scaledSize.width / 2,
              y: -scaledSize.height / 2,
              width: scaledSize.width,
              height: scaledSize.height
            )
            if let cachedImage = DispatchQueue.main.sync(execute: { self.webSnapshotCache[webElement.id] }) {
              cachedImage.draw(in: webRect)
            } else if webElement.cachedTitle != nil || webElement.cachedIconData != nil {
              let iconImage = webElement.cachedIconData.flatMap { UIImage(data: $0) }
              Self.drawWebCardFromCachedMetadata(
                context: context.cgContext,
                rect: webRect,
                title: webElement.cachedTitle ?? "Web",
                iconImage: iconImage,
                url: webElement.url,
                scale: scale
              )
            } else {
              Self.drawWebPlaceholderCard(
                context: context.cgContext,
                rect: webRect,
                url: webElement.url,
                scale: scale
              )
            }
            context.cgContext.restoreGState()
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
  }

  /// Helper method to replace a thumbnail at a given index.
  private func updateThumbnail(_ image: UIImage, at id: UUID) {
    thumbnails[id] = image
  }

  func updateExportImage(_ image: UIImage) {
    exportImage = image
  }

  func getOrCreateImage(from imageData: Data, id: UUID) -> UIImage? {
    if let cachedImage = imageCache[id] {
      return cachedImage
    }

    if let image = UIImage(data: imageData) {
      imageCache[id] = image
      return image
    }

    return nil
  }

  func getOrCreateVideoThumbnail(for videoElement: VideoElement) -> UIImage? {
    if let cachedImage = videoThumbnailCache[videoElement.assetId] {
      return cachedImage
    }

    if let image = DrawingFileManager.shared.loadVideoThumbnail(fileName: videoElement.thumbnailFileName) {
      videoThumbnailCache[videoElement.assetId] = image
      return image
    }

    return nil
  }

  private func cleanupImageCache() {
    imageCache.removeAll()
  }

  private func cleanupVideoThumbnailCache() {
    videoThumbnailCache.removeAll()
  }

  func updateWebSnapshot(webId: UUID, image: UIImage) {
    webSnapshotCache[webId] = image
  }

  /// Persists loaded card metadata (title, icon) into the current drawing's WebElement for thumbnails and offline display.
  func updateWebCachedMetadata(webId: UUID, title: String, iconData: Data?) {
    guard let drawingId, var drawing = drawings[drawingId],
          let index = drawing.webs.firstIndex(where: { $0.id == webId }) else { return }
    drawing.webs[index].cachedTitle = title
    drawing.webs[index].cachedIconData = iconData
    drawings[drawingId] = drawing
    saveDrawing(drawingId)
  }

  private func cleanupWebSnapshotCache() {
    webSnapshotCache.removeAll()
  }

  @objc private func handleMemoryWarning() {
    cleanupImageCache()
    cleanupVideoThumbnailCache()
    cleanupWebSnapshotCache()
    thumbnailWorkItem?.cancel()
    thumbnailWorkItem = nil
  }

  /// Draws a web card in thumbnails using persisted metadata (title, optional icon).
  private static func drawWebCardFromCachedMetadata(
    context: CGContext,
    rect: CGRect,
    title: String,
    iconImage: UIImage?,
    url: String,
    scale: CGFloat
  ) {
    let cornerRadius = min(rect.width, rect.height) * 0.1
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.addPath(path)
    context.setFillColor(UIColor.systemGray5.withAlphaComponent(0.9).cgColor)
    context.fillPath()
    context.addPath(path)
    context.clip()
    let iconSize = min(rect.width, rect.height) * 0.25
    if let icon = iconImage {
      let iconRect = CGRect(
        x: rect.midX - iconSize / 2,
        y: rect.midY - iconSize / 2 - rect.height * 0.08,
        width: iconSize,
        height: iconSize
      )
      icon.draw(in: iconRect)
    } else {
      let config = UIImage.SymbolConfiguration(pointSize: iconSize * 0.8, weight: .regular)
      guard let globeImage = UIImage(systemName: "globe", withConfiguration: config)?
        .withTintColor(.darkGray, renderingMode: .alwaysOriginal) else { return }
      let iconRect = CGRect(
        x: rect.midX - iconSize / 2,
        y: rect.midY - iconSize / 2 - rect.height * 0.08,
        width: iconSize,
        height: iconSize
      )
      globeImage.draw(in: iconRect)
    }
    let fontSize = max(8, min(rect.width, rect.height) * 0.12)
    let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
    let attrs: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: UIColor.darkGray
    ]
    let truncated = title.count > 20 ? String(title.prefix(17)) + "..." : title
    let textSize = (truncated as NSString).size(withAttributes: attrs)
    let textRect = CGRect(
      x: rect.midX - textSize.width / 2,
      y: rect.midY + rect.height * 0.05,
      width: min(rect.width - 4, textSize.width),
      height: textSize.height
    )
    (truncated as NSString).draw(in: textRect, withAttributes: attrs)
  }

  /// Draws a placeholder card for web elements in thumbnails (rounded rect, fill, globe icon, truncated URL).
  private static func drawWebPlaceholderCard(context: CGContext, rect: CGRect, url: String, scale: CGFloat) {
    let cornerRadius = min(rect.width, rect.height) * 0.1
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.addPath(path)
    context.setFillColor(UIColor.systemGray5.withAlphaComponent(0.9).cgColor)
    context.fillPath()
    context.addPath(path)
    context.clip()
    let config = UIImage.SymbolConfiguration(pointSize: min(rect.width, rect.height) * 0.25, weight: .regular)
    guard let globeImage = UIImage(systemName: "globe", withConfiguration: config)?
      .withTintColor(.darkGray, renderingMode: .alwaysOriginal) else { return }
    let iconW = globeImage.size.width
    let iconH = globeImage.size.height
    let iconRect = CGRect(
      x: rect.midX - iconW / 2,
      y: rect.midY - iconH / 2 - rect.height * 0.08,
      width: iconW,
      height: iconH
    )
    globeImage.draw(in: iconRect)
    let label = (URL(string: url)?.host).map { String($0) } ?? "Web"
    let fontSize = max(8, min(rect.width, rect.height) * 0.12)
    let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
    let attrs: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: UIColor.darkGray
    ]
    let truncated = label.count > 20 ? String(label.prefix(17)) + "..." : label
    let textSize = (truncated as NSString).size(withAttributes: attrs)
    let textRect = CGRect(
      x: rect.midX - textSize.width / 2,
      y: rect.midY + rect.height * 0.05,
      width: min(rect.width - 4, textSize.width),
      height: textSize.height
    )
    (truncated as NSString).draw(in: textRect, withAttributes: attrs)
  }

  private static func drawVideoPlayBadge(context: CGContext, rect: CGRect) {
    let diameter = min(rect.width, rect.height) * 0.22
    guard diameter > 8 else { return }

    let circleRect = CGRect(
      x: rect.midX - diameter / 2,
      y: rect.midY - diameter / 2,
      width: diameter,
      height: diameter
    )
    context.setFillColor(UIColor.black.withAlphaComponent(0.35).cgColor)
    context.fillEllipse(in: circleRect)

    let triangleWidth = diameter * 0.28
    let triangleHeight = diameter * 0.36
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.midX - triangleWidth * 0.35, y: rect.midY - triangleHeight / 2))
    path.addLine(to: CGPoint(x: rect.midX - triangleWidth * 0.35, y: rect.midY + triangleHeight / 2))
    path.addLine(to: CGPoint(x: rect.midX + triangleWidth * 0.55, y: rect.midY))
    path.closeSubpath()
    context.addPath(path)
    context.setFillColor(UIColor.white.withAlphaComponent(0.92).cgColor)
    context.fillPath()
  }
}

extension AppModel {
  func addNewDrawing() {
    print(#function, "addNewDrawing")
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
  
  func favoriteDrawing(id: UUID) {
    print(#function, "id \(id)")
    if let isStared = drawings[id]?.isFavorite {
      drawings[id]?.isFavorite = !isStared
      saveDrawing(id)
    }
  }
  
  func addDefulatDrawing() {
    guard let data = NSDataAsset(name: "Notes")?.data else { return }
    if let newDrawing = try? PKDrawing(data: data) {
      let drawing = DrawingModel(
        name: "Drawing \(drawings.count + 1)",
        drawing: newDrawing
      )
      drawings[drawing.id] = drawing
      thumbnails[drawing.id] = UIImage()
      selectDrawingId(drawing.id)
      saveDrawing(drawing.id)
    }
  }

  private func createDefaultStrokes() -> [PKStroke] {
    let edges = [
      [CGPoint(x: 0, y: 0)],
      [CGPoint(x: 200, y: 0)],
      [CGPoint(x: 200, y: 200)],
      [CGPoint(x: 0, y: 200)],
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
    imageEditingId = imageElement.id
  }

  func addVideo(from url: URL, at position: CGPoint) {
    guard let drawingId else { return }
    Task.detached(priority: .utility) { [weak self] in
      do {
        let videoElement = try await DrawingFileManager.shared.importVideo(from: url, at: position)

        await MainActor.run { [weak self] in
          guard let self = self, self.drawings[drawingId] != nil else {
            DrawingFileManager.shared.deleteVideoAsset(videoElement)
            return
          }
          self.drawings[drawingId]?.videos.append(videoElement)
          if let thumbnail = DrawingFileManager.shared.loadVideoThumbnail(fileName: videoElement.thumbnailFileName) {
            self.videoThumbnailCache[videoElement.assetId] = thumbnail
          }
          self.updateDrawing(drawingId)
          self.imageEditingId = videoElement.id
        }
      } catch {
        logger.info("\(#function) Could not import video: \(error.localizedDescription)")
      }
    }
  }

  func addWeb(_ url: String, at position: CGPoint, size: CGSize, rotation: Double = 0) {
    let webElement = WebElement(id: UUID(), url: url, position: position, size: size, rotation: rotation)
    guard let drawingId else { return }
    drawings[drawingId]?.webs.append(webElement)
    updateDrawing(drawingId)
    // 复用 imageEditingId 作为通用编辑目标 ID
    imageEditingId = webElement.id
  }

  func addText(_ text: String, at position: CGPoint, fontSize: CGFloat = 16, fontWeight: Font.Weight = .regular, color: Color = .black, rotation: Double = 0) {
    let textElement = TextElement(id: UUID(), text: text, position: position, fontSize: fontSize, fontWeight: fontWeight, color: color, rotation: rotation)
    guard let drawingId else { return }
    drawings[drawingId]?.texts.append(textElement)
    updateDrawing(drawingId)
  }

  func deleteImage(_ imageId: UUID) {
    guard let drawingId else { return }
    drawings[drawingId]?.images.removeAll { $0.id == imageId }
    // 清除编辑状态
    imageEditingId = nil
    // 保存更改
    updateDrawing(drawingId)
  }

  func deleteVideo(_ videoId: UUID) {
    guard let drawingId else { return }
    guard let video = drawings[drawingId]?.videos.first(where: { $0.id == videoId }) else { return }
    drawings[drawingId]?.videos.removeAll { $0.id == videoId }
    imageEditingId = nil
    updateDrawing(drawingId)
    deleteVideoAssetIfUnused(video)
  }

  func deleteWeb(_ webId: UUID) {
    guard let drawingId else { return }
    drawings[drawingId]?.webs.removeAll { $0.id == webId }
    imageEditingId = nil
    updateDrawing(drawingId)
  }

  private func deleteVideoAssetIfUnused(_ video: VideoElement) {
    let isStillReferenced = drawings.values.contains { drawing in
      drawing.videos.contains { $0.assetId == video.assetId }
    }
    guard !isStillReferenced else { return }
    videoThumbnailCache.removeValue(forKey: video.assetId)
    DrawingFileManager.shared.deleteVideoAsset(video)
  }

  func enterFullScreenWeb(webId: UUID) {
    guard let drawingId else { return }
    guard let drawing = drawings[drawingId] else { return }
    guard drawing.webs.contains(where: { $0.id == webId }) else { return }
    fullScreenWebId = webId
    isFullScreenWebActive = true
  }

  func exitFullScreenWeb() {
    isFullScreenWebActive = false
    fullScreenWebId = nil
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
