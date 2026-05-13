import Foundation
import AVFoundation
import UniformTypeIdentifiers
import UIKit

final class DrawingFileManager: @unchecked Sendable {
  static let shared = DrawingFileManager()

  private init() {}

  // 获取绘图文件存储目录
  private var drawingsDirectory: URL {
    let documentsDirectory = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/Drawings")
      ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Drawings")

    try? FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
    return documentsDirectory
  }

  // 获取索引文件路径
  private var indexFilePath: URL {
    drawingsDirectory.appendingPathComponent("index.json")
  }

  private var assetsDirectory: URL {
    let directory = drawingsDirectory.appendingPathComponent("assets", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private var videosDirectory: URL {
    let directory = assetsDirectory.appendingPathComponent("videos", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private var thumbnailsDirectory: URL {
    let directory = assetsDirectory.appendingPathComponent("thumbnails", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  // 保存绘图索引
  private func saveDrawingIndex(_ drawingIds: [UUID]) throws {
    let data = try JSONEncoder().encode(drawingIds)
    try data.write(to: indexFilePath)
  }

  // 读取绘图索引
  func loadDrawingIndex() -> [UUID] {
    guard let data = try? Data(contentsOf: indexFilePath),
          let ids = try? JSONDecoder().decode([UUID].self, from: data)
    else {
      return []
    }
    return ids
  }

  // 获取单个绘图文件的路径
  private func drawingFilePath(for id: UUID) -> URL {
    drawingsDirectory.appendingPathComponent("\(id.uuidString).drawing")
  }

  // 保存单个绘图
  func saveDrawing(_ drawing: DrawingModel) throws {
    let data = try PropertyListEncoder().encode(drawing)
    try data.write(to: drawingFilePath(for: drawing.id))

    var ids = loadDrawingIndex()
    if !ids.contains(drawing.id) {
      ids.insert(drawing.id, at: 0)
//      ids.append(drawing.id)
      try saveDrawingIndex(ids)
    }
  }

  // 读取单个绘图
  func loadDrawing(id: UUID) throws -> DrawingModel {
    let data = try Data(contentsOf: drawingFilePath(for: id))
    let decoder = PropertyListDecoder()
    return try decoder.decode(DrawingModel.self, from: data)
  }

  // 读取所有绘图
  func loadAllDrawings() -> [UUID: DrawingModel] {
    let ids = loadDrawingIndex()
    var drawings: [UUID : DrawingModel] = [:]
    for id in ids {
      if let drawing = try? loadDrawing(id: id) {
        drawings[id] = drawing
      }
    }
    print(#function, "drawings \(drawings)")
    return drawings
  }

  // 删除绘图
  func deleteDrawing(id: UUID) throws {
    try FileManager.default.removeItem(at: drawingFilePath(for: id))
    var ids = loadDrawingIndex()
    ids.removeAll { $0 == id }
    try saveDrawingIndex(ids)
  }

  func videoURL(fileName: String) -> URL {
    videosDirectory.appendingPathComponent(fileName)
  }

  func thumbnailURL(fileName: String) -> URL {
    thumbnailsDirectory.appendingPathComponent(fileName)
  }

  func importVideo(from sourceURL: URL, at position: CGPoint, maxDisplaySize: CGFloat = 320) async throws -> VideoElement {
    let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
    defer {
      if didStartAccessing {
        sourceURL.stopAccessingSecurityScopedResource()
      }
    }

    let asset = AVURLAsset(url: sourceURL)
    guard try await asset.load(.isPlayable) else {
      throw CocoaError(.fileReadUnsupportedScheme)
    }

    let assetId = UUID()
    let fileExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
    let fileName = "\(assetId.uuidString).\(fileExtension)"
    let thumbnailFileName = "\(assetId.uuidString).jpg"
    let destinationURL = videoURL(fileName: fileName)

    if FileManager.default.fileExists(atPath: destinationURL.path) {
      try FileManager.default.removeItem(at: destinationURL)
    }
    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

    let metadata: (duration: Double, naturalSize: CGSize, sizeBytes: Int64)
    do {
      metadata = try await videoMetadata(for: destinationURL)
      let thumbnail = try await generateVideoThumbnail(for: destinationURL)
      if let data = thumbnail.jpegData(compressionQuality: 0.82) {
        try data.write(to: thumbnailURL(fileName: thumbnailFileName), options: .atomic)
      }
    } catch {
      try? FileManager.default.removeItem(at: destinationURL)
      try? FileManager.default.removeItem(at: thumbnailURL(fileName: thumbnailFileName))
      throw error
    }

    let aspectRatio = metadata.naturalSize.width > 0 && metadata.naturalSize.height > 0
      ? metadata.naturalSize.width / metadata.naturalSize.height
      : 1
    let displaySize: CGSize
    if aspectRatio > 1 {
      displaySize = CGSize(width: maxDisplaySize, height: maxDisplaySize / aspectRatio)
    } else {
      displaySize = CGSize(width: maxDisplaySize * aspectRatio, height: maxDisplaySize)
    }

    return VideoElement(
      id: UUID(),
      assetId: assetId,
      fileName: fileName,
      thumbnailFileName: thumbnailFileName,
      mimeType: UTType(filenameExtension: fileExtension)?.preferredMIMEType ?? "video/quicktime",
      originalFileName: sourceURL.lastPathComponent,
      sizeBytes: metadata.sizeBytes,
      duration: metadata.duration,
      pixelWidth: metadata.naturalSize.width,
      pixelHeight: metadata.naturalSize.height,
      position: position,
      size: displaySize,
      rotation: 0
    )
  }

  func loadVideoThumbnail(fileName: String) -> UIImage? {
    UIImage(contentsOfFile: thumbnailURL(fileName: fileName).path)
  }

  func deleteVideoAsset(_ video: VideoElement) {
    try? FileManager.default.removeItem(at: videoURL(fileName: video.fileName))
    try? FileManager.default.removeItem(at: thumbnailURL(fileName: video.thumbnailFileName))
  }

  private func videoMetadata(for url: URL) async throws -> (duration: Double, naturalSize: CGSize, sizeBytes: Int64) {
    let asset = AVURLAsset(url: url)
    let track = try await firstVideoTrack(in: asset)
    let naturalSize: CGSize
    let preferredTransform: CGAffineTransform
    if let track {
      naturalSize = try await track.load(.naturalSize)
      preferredTransform = try await track.load(.preferredTransform)
    } else {
      naturalSize = .zero
      preferredTransform = .identity
    }
    let transformedSize = naturalSize.applying(preferredTransform)
    let orientedSize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))
    let values = try url.resourceValues(forKeys: [.fileSizeKey])
    let duration = try await asset.load(.duration)
    return (
      duration: duration.seconds.isFinite ? duration.seconds : 0,
      naturalSize: orientedSize,
      sizeBytes: Int64(values.fileSize ?? 0)
    )
  }

  private func generateVideoThumbnail(for url: URL) async throws -> UIImage {
    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 1024, height: 1024)
    let duration = try await asset.load(.duration)
    let durationSeconds = duration.seconds
    let thumbnailSecond = durationSeconds.isFinite ? min(max(durationSeconds * 0.1, 0), 1) : 0
    let time = CMTime(seconds: thumbnailSecond, preferredTimescale: 600)
    let cgImage = try await generator.image(at: time).image
    return UIImage(cgImage: cgImage)
  }

  private func firstVideoTrack(in asset: AVURLAsset) async throws -> AVAssetTrack? {
    let tracks = try await asset.load(.tracks)
    for track in tracks {
      let naturalSize = try await track.load(.naturalSize)
      if naturalSize.width > 0, naturalSize.height > 0 {
        return track
      }
    }
    return nil
  }

  // 数据迁移
  func migrateFromOldVersion(oldDataModel: LegacyDataModel) throws {
    // 清空现有索引
    try? FileManager.default.removeItem(at: indexFilePath)

    // 迁移每个绘图
    for (index, oldDrawing) in oldDataModel.drawings.enumerated() {
      let newDrawing = DrawingModel(
        name: "Drawing \(index + 1)",
        drawing: oldDrawing
      )
      try saveDrawing(newDrawing)
    }
  }

  // 检查是否存在绘图数据
  func hasDrawings() -> Bool {
    do {
      let drawingsURL = drawingsDirectory
      
      print(#function, "drawingsURL path: \(drawingsURL.path)")
      
      // 检查目录是否存在
      var isDirectory: ObjCBool = false
      let exists = FileManager.default.fileExists(atPath: drawingsURL.path, isDirectory: &isDirectory)
      print(#function, "exists: \(exists), isDirectory: \(isDirectory.boolValue), path: \(drawingsURL.path)")
      
      // 尝试直接列出目录内容
      do {
        let contents = try FileManager.default.contentsOfDirectory(atPath: drawingsURL.path)
        print(#function, "Directory contents: \(contents)")
      } catch {
        print(#function, "Error listing directory: \(error)")
      }
      
      if exists && isDirectory.boolValue {
        // 检查目录中是否有绘图文件
        let contents = try FileManager.default.contentsOfDirectory(
          at: drawingsURL,
          includingPropertiesForKeys: nil,
          options: [.skipsHiddenFiles]
        )
        print(#function, "Contents count: \(contents.count)")
        return !contents.isEmpty
      }
      
      return false
    } catch {
      print(#function, "Error: \(error)")
      return false
    }
  }
}
