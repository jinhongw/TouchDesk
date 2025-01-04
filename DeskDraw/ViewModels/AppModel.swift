//
//  AppModel.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/27.
//

import Foundation
import PencilKit
import SwiftUI

/// `DataModel` contains the drawings that make up the data model, including multiple image drawings and a signature drawing.
struct DataModel: Codable {
  /// Names of the drawing assets to be used to initialize the data model the first time.
  static let defaultDrawingNames: [String] = ["Notes"]

  /// The width used for drawing canvases.
  static let canvasWidth: CGFloat = 768

  /// The drawings that make up the current data model.
  var drawings: [PKDrawing] = []
}

/// `DataModelControllerObserver` is the behavior of an observer of data model changes.
protocol DataModelControllerObserver {
  /// Invoked when the data model changes.
  func dataModelChanged()
}

struct DeletedDrawing {
  let drawing: PKDrawing
  let thumbnail: UIImage
}

@MainActor
@Observable
class AppModel {
  var dataModel = DataModel()
  var thumbnails = [UIImage]()
  var deletedDrawings = [DeletedDrawing]()
  var drawingIndex: Int = 0
  var hideInMini = false
  var showDrawing = true
  var showNotes = false
  var color: Color = .white
  var isLocked = false

  /// The size to use for thumbnail images.
  static let thumbnailSize = CGSize(width: 512, height: 512)
  static let drawingIndexKey = "drawingIndexKey"
  /// Dispatch queues for the background operations done by this controller.
  private let thumbnailQueue = DispatchQueue(label: "ThumbnailQueue", qos: .background)
  private let serializationQueue = DispatchQueue(label: "SerializationQueue", qos: .background)
  /// Observers add themselves to this array to start being informed of data model changes.
  var observers = [DataModelControllerObserver]()

  var thumbnailTraitCollection = UITraitCollection() {
    didSet {
      // If the user interface style changed, regenerate all thumbnails.
      if oldValue.userInterfaceStyle != thumbnailTraitCollection.userInterfaceStyle {
        generateAllThumbnails()
      }
    }
  }

  var drawings: [PKDrawing] {
    get { dataModel.drawings }
    set { dataModel.drawings = newValue }
  }

  /// The URL of the file in which the current data model is saved.
  private var saveURL: URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let documentsDirectory = paths.first!
    return documentsDirectory.appendingPathComponent("DeskDraw.data")
  }

  init() {
    loadDataModel()
    loadUserDefaults()
  }

  private func loadDataModel() {
    let url = saveURL
    serializationQueue.async {
      // Load the data model, or the initial test data.
      let dataModel: DataModel

      if FileManager.default.fileExists(atPath: url.path) {
        do {
          let decoder = PropertyListDecoder()
          let data = try Data(contentsOf: url)
          dataModel = try decoder.decode(DataModel.self, from: data)
          print(#function, "Load data model: \(dataModel)")
        } catch {
          print(#function, "Could not load data model: \(error.localizedDescription)")
          dataModel = self.loadDefaultDrawings()
        }
      } else {
        print(#function, "file not Exists")
        dataModel = self.loadDefaultDrawings()
      }

      DispatchQueue.main.async {
        self.setLoadedDataModel(dataModel)
      }
    }
  }

  private func loadUserDefaults() {
    if let lastDrawingIndex = UserDefaults.standard.value(forKey: AppModel.drawingIndexKey) as? Int {
      drawingIndex = lastDrawingIndex
    } else {
      drawingIndex = 0
    }
  }

  /// Save the data model to persistent storage.
  func saveDataModel() {
    let savingDataModel = dataModel
    let url = saveURL
    serializationQueue.async {
      do {
        let encoder = PropertyListEncoder()
        let data = try encoder.encode(savingDataModel)
        try data.write(to: url)
      } catch {
        print(#function, "Could not save data model: \(error.localizedDescription)")
      }
    }
  }

  /// Construct an initial data model when no data model already exists.
  nonisolated private func loadDefaultDrawings() -> DataModel {
    var testDataModel = DataModel()
    for sampleDataName in DataModel.defaultDrawingNames {
      guard let data = NSDataAsset(name: sampleDataName)?.data else { continue }
      if let drawing = try? PKDrawing(data: data) {
        testDataModel.drawings.append(drawing)
      }
    }
    return testDataModel
  }

  /// Helper method to set the current data model to a data model created on a background queue.
  private func setLoadedDataModel(_ dataModel: DataModel) {
    self.dataModel = dataModel
    thumbnails = Array(repeating: UIImage(), count: dataModel.drawings.count)
    print(#function, "thumbnails \(thumbnails)")
    generateAllThumbnails()
  }

  /// Helper method to cause regeneration of all thumbnails.
  private func generateAllThumbnails() {
    for index in drawings.indices {
      print(#function, "thumbnail index \(index) \(drawings[index])")
      generateThumbnail(index)
    }
  }

  /// Helper method to cause regeneration of a specific thumbnail, using the current user interface style
  /// of the thumbnail view controller.
  private func generateThumbnail(_ index: Int) {
    let drawing = drawings[index]
    let aspectRatio = AppModel.thumbnailSize.width / AppModel.thumbnailSize.height
    let maxBound = max(drawing.bounds.maxX - drawing.bounds.minX, drawing.bounds.maxY - drawing.bounds.minY)
    let thumbnailRect = CGRect(x: drawing.bounds.minX, y: drawing.bounds.minY, width: maxBound, height: maxBound / aspectRatio)
    let thumbnailScale = AppModel.thumbnailSize.width / maxBound
    let traitCollection = thumbnailTraitCollection

    thumbnailQueue.async {
      traitCollection.performAsCurrent {
        let image = drawing.thumbnail(rect: thumbnailRect, scale: thumbnailScale, traitCollection: UITraitCollection(userInterfaceStyle: .light))
        DispatchQueue.main.async {
          print(#function, "thumbnail index \(index) \(image)")
          self.updateThumbnail(image, at: index)
        }
      }
    }
  }

  /// Helper method to replace a thumbnail at a given index.
  private func updateThumbnail(_ image: UIImage, at index: Int) {
    if index <= thumbnails.count - 1 {
      thumbnails[index] = image
    } else {
      thumbnails.append(image)
    }
  }
}

extension AppModel {
  func addNewDrawing() {
    dataModel.drawings.append(PKDrawing())
    thumbnails.append(UIImage())
    selectDrawingIndex(dataModel.drawings.count - 1)
  }

  /// Update a drawing at `index` and generate a new thumbnail.
  func updateDrawing(_ index: Int) {
    print(#function, "updateDrawing \(index)")
    generateThumbnail(index)
    saveDataModel()
  }

  func deleteDrawing(_ index: Int) {
    print(#function, "deleteDrawing \(index)")
    deletedDrawings.append(DeletedDrawing(drawing: dataModel.drawings[index], thumbnail: thumbnails[index]))
    dataModel.drawings.remove(at: index)
    thumbnails.remove(at: index)
    if drawingIndex >= index {
      drawingIndex -= 1
    }
    if drawingIndex < 0 {
      drawingIndex = 0
    }
    if dataModel.drawings.isEmpty {
      addNewDrawing()
    }
    saveDataModel()
  }

  func recoverNote() {
    if let recover = deletedDrawings.popLast() {
      dataModel.drawings.append(recover.drawing)
      thumbnails.append(recover.thumbnail)
    }
  }

  func selectDrawingIndex(_ index: Int) {
    drawingIndex = index
    UserDefaults.standard.set(index, forKey: AppModel.drawingIndexKey)
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
