//
//  DrawingUIView+Coordinator.swift
//  DeskDraw
//
//  Created by jinhong on 10/30/25.
//

import PencilKit
import SwiftUI

extension DrawingUIView {
  class Coordinator: NSObject, PKCanvasViewDelegate, UIScrollViewDelegate {
    var parent: DrawingUIView
    var lastDrawingId: UUID = .init()
    var lastImages: [ImageElement] = []
    var lastVideos: [VideoElement] = []
    var saveWorkItem: DispatchWorkItem?
    var saveScrollWorkItem: DispatchWorkItem?
    var isUpdatingFromModel = false
    var lastImageEditingId: UUID?
    var lastImageElements: [UUID: ImageElement] = [:]
    var lastSelectorActive: Bool = false
    var lastLocked: Bool = false
    var isInitializing: Bool = false
    var isSettingPosition: Bool = false
    var imageViewCache: [UUID: ResizableImageView] = [:]
    var videoViewCache: [UUID: ResizableImageView] = [:]
    var webViewCache: [UUID: ResizableWebView] = [:]
    var imageContainer: ImageContainerView?
    var contentOffsetObserver: NSKeyValueObservation?
    var lastWebs: [WebElement] = []
    var lastWebElements: [UUID: WebElement] = [:]
    var lastVideoElements: [UUID: VideoElement] = [:]
    weak var elementDoubleTapGesture: UITapGestureRecognizer?

    init(_ parent: DrawingUIView) {
      self.parent = parent
      self.lastLocked = parent.isLocked
      super.init()
    }

    func installElementSelectionGestures(on canvas: PKCanvasView) {
      guard elementDoubleTapGesture == nil else { return }

      let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleElementDoubleTap(_:)))
      doubleTapGesture.numberOfTapsRequired = 2
      doubleTapGesture.cancelsTouchesInView = false
      doubleTapGesture.delaysTouchesBegan = false
      doubleTapGesture.delaysTouchesEnded = false
      doubleTapGesture.delegate = self
      canvas.addGestureRecognizer(doubleTapGesture)
      elementDoubleTapGesture = doubleTapGesture
    }

    @objc private func handleElementDoubleTap(_ gesture: UITapGestureRecognizer) {
      guard gesture.state == .ended,
            !parent.isLocked,
            !parent.isSelectorActive,
            let imageContainer
      else { return }

      let point = gesture.location(in: imageContainer)
      guard let target = imageContainer.topSelectableView(at: point) else { return }

      if let imageView = target as? ResizableImageView,
         let imageId = imageView.imageId {
        parent.isSelectorActive = false
        if parent.imageEditingId == imageId {
          parent.imageEditingId = nil
        } else {
          parent.imageEditingId = imageId
        }
      } else if let webView = target as? ResizableWebView,
                let webId = webView.webId {
        parent.isSelectorActive = false
        if parent.imageEditingId == webId {
          parent.imageEditingId = nil
        } else {
          parent.imageEditingId = webId
        }
      }
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
      guard !isUpdatingFromModel else { return }

      saveWorkItem?.cancel()
      saveWorkItem = nil

      let workItem = DispatchWorkItem { [weak self] in
        guard let self = self else { return }
        if self.parent.model.drawing != canvasView.drawing {
          Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.parent.model.drawing = canvasView.drawing
            self.parent.updateContentSizeForDrawing(coordinator: self)
            self.parent.saveDrawing()
            if self.parent.isShareImageViewShowing {
              self.parent.updateExportImage()
            }
          }
        }
      }

      saveWorkItem = workItem
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    func updateImagePosition(imageId: UUID, position: CGPoint) {
      guard let index = parent.model.images.firstIndex(where: { $0.id == imageId }) else { return }
      var updatedImage = parent.model.images[index]
      updatedImage.position = position
      parent.model.images[index] = updatedImage

      parent.saveDrawing()
      if parent.isShareImageViewShowing {
        parent.updateExportImage()
      }
    }

    func updateImageSize(imageId: UUID, size: CGSize) {
      guard let index = parent.model.images.firstIndex(where: { $0.id == imageId }) else { return }
      var updatedImage = parent.model.images[index]
      updatedImage.size = size
      parent.model.images[index] = updatedImage

      parent.saveDrawing()
      if parent.isShareImageViewShowing {
        parent.updateExportImage()
      }
    }

    func updateVideoPosition(videoId: UUID, position: CGPoint) {
      guard let index = parent.model.videos.firstIndex(where: { $0.id == videoId }) else { return }
      var updatedVideo = parent.model.videos[index]
      updatedVideo.position = position
      parent.model.videos[index] = updatedVideo

      parent.saveDrawing()
      if parent.isShareImageViewShowing {
        parent.updateExportImage()
      }
    }

    func updateVideoSize(videoId: UUID, size: CGSize) {
      guard let index = parent.model.videos.firstIndex(where: { $0.id == videoId }) else { return }
      var updatedVideo = parent.model.videos[index]
      updatedVideo.size = size
      parent.model.videos[index] = updatedVideo

      parent.saveDrawing()
      if parent.isShareImageViewShowing {
        parent.updateExportImage()
      }
    }

    func updateWebPosition(webId: UUID, position: CGPoint) {
      guard let index = parent.model.webs.firstIndex(where: { $0.id == webId }) else { return }
      var updated = parent.model.webs[index]
      updated.position = position
      parent.model.webs[index] = updated
      parent.saveDrawing()
      if parent.isShareImageViewShowing { parent.updateExportImage() }
    }

    func updateWebSize(webId: UUID, size: CGSize) {
      guard let index = parent.model.webs.firstIndex(where: { $0.id == webId }) else { return }
      var updated = parent.model.webs[index]
      updated.size = size
      parent.model.webs[index] = updated
      parent.saveDrawing()
      if parent.isShareImageViewShowing { parent.updateExportImage() }
    }

    func getOrCreateImageView(for imageElement: ImageElement, in canvas: PKCanvasView) -> ResizableImageView? {
      if let cachedView = imageViewCache[imageElement.id] {
        // 复用现有视图
        if let image = UIImage(data: imageElement.imageData) {
          cachedView.image = image
        }
        return cachedView
      }

      // 创建新视图
      if let image = UIImage(data: imageElement.imageData) {
        let imageView = ResizableImageView(image: image, size: image.size)
        imageView.contentMode = .scaleAspectFit
        imageView.imageId = imageElement.id
        imageViewCache[imageElement.id] = imageView
        return imageView
      }

      print(#function, "Failed to create image view")
      return nil
    }

    func getOrCreateVideoView(for videoElement: VideoElement) -> ResizableImageView? {
      if let cachedView = videoViewCache[videoElement.id] {
        cachedView.image = parent.getVideoThumbnail(videoElement)
        cachedView.configureVideoPlayback(url: DrawingFileManager.shared.videoURL(fileName: videoElement.fileName))
        return cachedView
      }

      guard let thumbnail = parent.getVideoThumbnail(videoElement) else {
        print(#function, "Failed to create video thumbnail view")
        return nil
      }

      let videoView = ResizableImageView(image: thumbnail, size: videoElement.size)
      videoView.contentMode = .scaleAspectFit
      videoView.imageId = videoElement.id
      videoView.configureVideoPlayback(url: DrawingFileManager.shared.videoURL(fileName: videoElement.fileName))
      videoViewCache[videoElement.id] = videoView
      return videoView
    }

    func getOrCreateWebView(for webElement: WebElement) -> ResizableWebView? {
      if let cached = webViewCache[webElement.id] {
        return cached
      }
      let webView = ResizableWebView(
        url: webElement.url,
        size: webElement.size,
        cachedTitle: webElement.cachedTitle,
        cachedIconData: webElement.cachedIconData
      )
      webView.webId = webElement.id
      webViewCache[webElement.id] = webView
      return webView
    }

    func cleanupImageViewCache(currentImageIds: Set<UUID>) {
      let unusedIds = Set(imageViewCache.keys).subtracting(currentImageIds)
      print("Cleaning up \(unusedIds.count) unused image views")

      unusedIds.forEach { id in
        imageViewCache[id]?.removeFromSuperview()
        imageViewCache[id] = nil
      }
    }

    func cleanupVideoViewCache(currentVideoIds: Set<UUID>) {
      let unusedIds = Set(videoViewCache.keys).subtracting(currentVideoIds)
      print("Cleaning up \(unusedIds.count) unused video views")

      unusedIds.forEach { id in
        videoViewCache[id]?.removeFromSuperview()
        videoViewCache[id] = nil
      }
    }

    func cleanupWebViewCache(currentWebIds: Set<UUID>) {
      let unusedIds = Set(webViewCache.keys).subtracting(currentWebIds)
      print("Cleaning up \(unusedIds.count) unused web views")
      unusedIds.forEach { id in
        webViewCache[id]?.removeFromSuperview()
        webViewCache[id] = nil
      }
    }

    deinit {
      saveWorkItem?.cancel()
      saveWorkItem = nil
      saveScrollWorkItem?.cancel()
      saveScrollWorkItem = nil
      contentOffsetObserver?.invalidate()

      // 清理所有缓存的视图
      cleanupImageViewCache(currentImageIds: [])
      cleanupVideoViewCache(currentVideoIds: [])
      cleanupWebViewCache(currentWebIds: [])
    }
  }
}

extension DrawingUIView.Coordinator: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    true
  }

  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    if touch.type == .pencil {
      return false
    }

    var view = touch.view
    while let currentView = view {
      if let imageView = currentView as? ResizableImageView,
         imageView.shouldReceiveElementTouches {
        return false
      }
      if let webView = currentView as? ResizableWebView,
         webView.shouldReceiveElementTouches {
        return false
      }
      view = currentView.superview
    }

    return true
  }
}
