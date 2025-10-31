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
    var webViewCache: [UUID: ResizableWebView] = [:]
    var imageContainer: ImageContainerView?
    var contentOffsetObserver: NSKeyValueObservation?
    var lastWebs: [WebElement] = []
    var lastWebElements: [UUID: WebElement] = [:]

    init(_ parent: DrawingUIView) {
      self.parent = parent
      self.lastLocked = parent.isLocked
      super.init()
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

    func getOrCreateWebView(for webElement: WebElement) -> ResizableWebView? {
      if let cached = webViewCache[webElement.id] {
        return cached
      }
      let webView = ResizableWebView(url: webElement.url, size: webElement.size)
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
      cleanupWebViewCache(currentWebIds: [])
    }
  }
}
