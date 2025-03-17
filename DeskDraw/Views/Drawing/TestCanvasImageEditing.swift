//
//  TestCanvasImageEditing.swift
//  DeskDraw
//
//  Created by jinhong on 2025/3/16.
//

import PencilKit
import SwiftUI

struct TestCanvasImageEditing: View {
  @State private var canvas = PKCanvasView()
  @State private var imageView: UIImageView?

  var body: some View {
    VStack {
      TestCanvasView(canvas: canvas, imageView: $imageView)

      Button("添加图片") {
        addImageToCanvas()
      }
      .padding()
    }
  }

  private func addImageToCanvas() {
    let image = UIImage(named: "example") ?? UIImage(systemName: "photo")! // 使用系统默认图片
    let imageView = UIImageView(image: image)
    imageView.frame = CGRect(x: 100, y: 100, width: 200, height: 200)
    imageView.isUserInteractionEnabled = true

    let panGesture = UIPanGestureRecognizer(target: imageView, action: #selector(UIImageView.handleImageTranslationPanTest(_:)))
    imageView.addGestureRecognizer(panGesture)

    self.imageView = imageView
  }
}

struct TestCanvasView: UIViewRepresentable {
  let canvas: PKCanvasView
  @Binding var imageView: UIImageView?

  func makeUIView(context: Context) -> some UIView {
    canvas.drawingPolicy = .anyInput
    canvas.contentSize = .init(width: 2000, height: 2000)
    canvas.alwaysBounceVertical = true
    canvas.alwaysBounceHorizontal = true

    return canvas
  }

  func updateUIView(_ uiView: UIViewType, context: Context) {
    if let imageView = imageView {
      canvas.addSubview(imageView)
      imageView.center = canvas.center
      self.imageView = nil
    }
  }
}

// 扩展 UIImageView 添加拖拽功能
extension UIImageView {
  @objc func handleImageTranslationPanTest(_ gesture: UIPanGestureRecognizer) {
    print(#function, "\(gesture.translation(in: superview))")
    let translation = gesture.translation(in: superview)
    if let view = gesture.view {
      view.center = CGPoint(x: view.center.x + translation.x,
                            y: view.center.y + translation.y)
    }
    gesture.setTranslation(.zero, in: superview)
  }
}

 #Preview {
    TestCanvasImageEditing()
 }

struct TestMainView: View {
  @State var appModel: AppModel = AppModel()
  let canvas = PKCanvasView()
  
  @AppStorage("penWidth") private var penWidth: Double = 0.88
  @AppStorage("monolineWidth") private var monolineWidth: Double = 0.5
  @AppStorage("pencilWidth") private var pencilWidth: Double = 2.41
  @AppStorage("crayonWidth") private var crayonWidth: Double = 30
  @AppStorage("fountainPenWidth") private var fountainPenWidth: Double = 4.625
  @AppStorage("eraserWidth") private var eraserWidth: Double = 16.4
  @AppStorage("eraserType") private var eraserType: DrawingView.EraserType = .bitmap
  @AppStorage("toolStatus") private var toolStatus: DrawingView.CanvasToolStatus = .ink
  @AppStorage("pencilType") private var pencilType: PKInkingTool.InkType = .pen
  @AppStorage("isHorizontal") private var isHorizontal: Bool = true
  @AppStorage("placementAssistance") private var placementAssistance = true
  @AppStorage("showGestureGuide") private var showGestureGuide = true
  
  var body: some View {
    VStack {
      DrawingUIViewRepresentable(
        canvas: canvas,
        model: Binding(
          get: {
            if let drawing = appModel.currentDrawing {
              print(#function, "canvas show \(drawing.id)")
              return drawing
            } else if let firstDrawingId = appModel.ids.first, let firstDrawing = appModel.drawings[firstDrawingId] {
              appModel.selectDrawingId(firstDrawingId)
              print(#function, "canvas show first drawing \(firstDrawingId)")
              return firstDrawing
            } else {
              appModel.addNewDrawing()
              if let newDrawingId = appModel.drawingId, let newDrawing = appModel.drawings[newDrawingId] {
                print(#function, "canvas show new drawing \(newDrawingId)")
                return newDrawing
              }
              return DrawingModel(name: "", drawing: PKDrawing())
            }
          },
          set: { newValue in
            guard let drawingId = appModel.drawingId else { return }
            print(#function, "canvas set \(drawingId)")
            appModel.drawings[drawingId] = newValue
          }
        ),
        toolStatus: $toolStatus,
        pencilType: $pencilType,
        eraserType: $eraserType,
        penWidth: $penWidth,
        monolineWidth: $monolineWidth,
        pencilWidth: $pencilWidth,
        crayonWidth: $crayonWidth,
        fountainPenWidth: $fountainPenWidth,
        eraserWidth: $eraserWidth,
        color: $appModel.drawColor,
        isLocked: $appModel.isLocked,
        isShareImageViewShowing: $appModel.isShareImageViewShowing,
        imageEditingId: $appModel.imageEditingId,
        canvasWidth: 1024,
        canvasHeight: 1024,
        saveDrawing: {
          appModel.updateDrawing(appModel.drawingId)
        },
        updateExportImage: {
          guard let drawingId = appModel.drawingId else { return }
          appModel.generateThumbnail(drawingId, isFullScale: true)
        }
      )
      Button(action: {
        let image = UIImage(named: "Gmail") ?? UIImage(systemName: "photo")!
        let visibleCenter = CGPoint(
          x: canvas.contentOffset.x + 1024 / 2,
          y: canvas.contentOffset.y + 1024 / 2
        )
        appModel.addImage(image.pngData()!, at: visibleCenter, size: .init(width: 200, height: 200))
      }, label: {
        Text("Button")
      })
    }
  }
}

//#Preview {
//  TestMainView()
//}
