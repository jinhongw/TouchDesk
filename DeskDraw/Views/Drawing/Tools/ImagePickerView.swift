//
//  ImagePickerView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/2/14.
//

import SwiftUI
import PhotosUI
import PencilKit

struct ImagePickerView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.dismiss) private var dismiss
  let point: CGPoint

  var body: some View {
    ImagePickerUIView(point: point)
      .environment(appModel)
      .ignoresSafeArea()
  }
}

struct ImagePickerUIView: UIViewControllerRepresentable {
  @Environment(AppModel.self) private var appModel
  @Environment(\.dismiss) private var dismiss
  
  let point: CGPoint

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.delegate = context.coordinator
    picker.sourceType = .photoLibrary
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let parent: ImagePickerUIView

    init(_ parent: ImagePickerUIView) {
      self.parent = parent
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
      if let image = info[.originalImage] as? UIImage,
         let imageData = image.jpegData(compressionQuality: 1) {
        
        // 计算合适的图片尺寸
        let maxSize: CGFloat = 320
        let aspectRatio = image.size.width / image.size.height
        let size: CGSize
        
        if aspectRatio > 1 {
          size = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
          size = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        // 添加图片到画布
        parent.appModel.addImage(imageData, at: parent.point, size: size)
      }
      parent.dismiss()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      parent.dismiss()
    }
  }
}
