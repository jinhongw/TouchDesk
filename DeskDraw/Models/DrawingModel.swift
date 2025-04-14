import Foundation
import PencilKit
import SwiftUI

struct DrawingModel: Codable {
  let id: UUID
  var name: String
  var drawing: PKDrawing
  var images: [ImageElement]
  var texts: [TextElement]
  var createdAt: Date
  var modifiedAt: Date
  var isFavorite: Bool

  var bounds: CGRect {
    drawing.bounds
  }

  init(id: UUID = UUID(), name: String, drawing: PKDrawing, isFavorite: Bool = false) {
    self.id = id
    self.name = name
    self.drawing = drawing
    self.isFavorite = isFavorite
    images = []
    texts = []
    createdAt = Date()
    modifiedAt = Date()
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    drawing = try container.decode(PKDrawing.self, forKey: .drawing)
    images = try container.decode([ImageElement].self, forKey: .images)
    texts = try container.decode([TextElement].self, forKey: .texts)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
    isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
  }

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case drawing
    case images
    case texts
    case createdAt
    case modifiedAt
    case isFavorite
  }
}

struct ImageElement: Codable, Equatable {
  let id: UUID
  let imageData: Data
  var position: CGPoint
  var size: CGSize
  var rotation: Double

  init(id: UUID, imageData: Data, position: CGPoint, size: CGSize, rotation: Double) {
    self.id = id
    self.imageData = imageData
    self.position = position
    self.size = size
    self.rotation = rotation
  }

  enum CodingKeys: String, CodingKey {
    case id
    case imageData
    case position
    case size
    case rotation
  }

  static func == (lhs: ImageElement, rhs: ImageElement) -> Bool {
    lhs.id == rhs.id &&
    lhs.imageData == rhs.imageData &&
    lhs.position == rhs.position &&
    lhs.size == rhs.size &&
    lhs.rotation == rhs.rotation
  }
}

struct TextElement: Codable {
  let id: UUID
  var text: String
  var position: CGPoint
  var fontSize: CGFloat
  var fontWeight: Font.Weight
  var color: Color
  var rotation: Double

  enum CodingKeys: String, CodingKey {
    case id
    case text
    case position
    case fontSize
    case fontWeight
    case color
    case rotation
  }

  init(id: UUID, text: String, position: CGPoint, fontSize: CGFloat, fontWeight: Font.Weight, color: Color, rotation: Double) {
    self.id = id
    self.text = text
    self.position = position
    self.fontSize = fontSize
    self.fontWeight = fontWeight
    self.color = color
    self.rotation = rotation
  }

  // Color 的编解码实现
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .text)
    text = try container.decode(String.self, forKey: .text)
    position = try container.decode(CGPoint.self, forKey: .position)
    fontSize = try container.decode(CGFloat.self, forKey: .fontSize)
    fontWeight = try container.decode(Font.Weight.self, forKey: .fontWeight)
    let colorData = try container.decode(Data.self, forKey: .color)
    color = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData)?.color ?? .black
    rotation = try container.decode(Double.self, forKey: .rotation)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(text, forKey: .text)
    try container.encode(position, forKey: .position)
    try container.encode(fontSize, forKey: .fontSize)
    try container.encode(fontWeight, forKey: .fontWeight)
    let colorData = try NSKeyedArchiver.archivedData(withRootObject: UIColor(color), requiringSecureCoding: true)
    try container.encode(colorData, forKey: .color)
    try container.encode(rotation, forKey: .rotation)
  }
}

extension UIColor {
  var color: Color {
    Color(self)
  }
}

extension Font.Weight: Codable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(weightValue)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(Double.self)
    self = Font.Weight(weightValue: value)
  }

  var weightValue: Double {
    switch self {
    case .ultraLight: return 100
    case .thin: return 200
    case .light: return 300
    case .regular: return 400
    case .medium: return 500
    case .semibold: return 600
    case .bold: return 700
    case .heavy: return 800
    case .black: return 900
    default: return 400
    }
  }

  init(weightValue: Double) {
    switch weightValue {
    case ...150: self = .ultraLight
    case ...250: self = .thin
    case ...350: self = .light
    case ...450: self = .regular
    case ...550: self = .medium
    case ...650: self = .semibold
    case ...750: self = .bold
    case ...850: self = .heavy
    default: self = .black
    }
  }
}
