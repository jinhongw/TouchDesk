//
//  VideoPickerView.swift
//  DeskDraw
//
//  Created by jinhong on 2026/5/13.
//

import SwiftUI
import UIKit
import AVFoundation
import UniformTypeIdentifiers

struct VideoPickerView: View {
  @Environment(AppModel.self) private var appModel
  let point: CGPoint

  var body: some View {
    VideoPickerUIView(point: point)
      .environment(appModel)
      .ignoresSafeArea()
  }
}

struct VideoPickerUIView: UIViewControllerRepresentable {
  @Environment(AppModel.self) private var appModel
  @Environment(\.dismiss) private var dismiss

  let point: CGPoint

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.delegate = context.coordinator
    picker.sourceType = .photoLibrary
    picker.mediaTypes = [UTType.movie.identifier]
    picker.videoExportPreset = AVAssetExportPresetPassthrough
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let parent: VideoPickerUIView

    init(_ parent: VideoPickerUIView) {
      self.parent = parent
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
      if let mediaURL = info[.mediaURL] as? URL {
        parent.appModel.addVideo(from: mediaURL, at: parent.point)
      }
      parent.dismiss()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      parent.dismiss()
    }
  }
}
