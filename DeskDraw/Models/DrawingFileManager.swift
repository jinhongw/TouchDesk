import Foundation

class DrawingFileManager {
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
