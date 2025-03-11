import Foundation
import PencilKit

/// 旧版本数据模型 (v1.1.7 及之前)
struct LegacyDataModel: Codable {
    /// Names of the drawing assets to be used to initialize the data model the first time.
    static let defaultDrawingNames: [String] = ["Notes"]

    /// The width used for drawing canvases.
    static let canvasWidth: CGFloat = 768

    /// The drawings that make up the current data model.
    var drawings: [PKDrawing] = []
} 