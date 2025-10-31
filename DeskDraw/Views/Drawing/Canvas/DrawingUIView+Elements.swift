//
//  DrawingUIView+Elements.swift
//  DeskDraw
//
//  Created by jinhong on 10/30/25.
//

import PencilKit
import SwiftUI

extension DrawingUIView {
  // MARK: ImageView

  func updateImageViews(in canvas: PKCanvasView, context: Context) {
    // 创建当前图片ID集合
    let currentImageIds = Set(model.images.map { $0.id })

    // 直接使用 imageViewCache
    let existingImageViews = context.coordinator.imageViewCache

    // 删除不再需要的图片视图
    for (imageId, imageView) in existingImageViews {
      if !currentImageIds.contains(imageId) {
        context.coordinator.imageContainer?.removeImageView(imageView)
        context.coordinator.imageViewCache.removeValue(forKey: imageId)
      }
    }

    // 更新或添加图片视图
    for imageElement in model.images {
      guard let imageView = context.coordinator.getOrCreateImageView(for: imageElement, in: canvas) else { continue }

      // 设置编辑状态
      imageView.editingId = imageEditingId

      // 设置锁定状态
      imageView.isLocked = isLocked

      // 设置是否可以响应点击事件
      imageView.isUserInteractionEnabled = isSelectorActive || imageView.editingId == imageElement.id

      // 使用字典快速查找上一次的图片信息
      let lastElement = context.coordinator.lastImageElements[imageElement.id]
      let needsUpdate = existingImageViews[imageElement.id] == nil ||
        lastElement?.imageData != imageElement.imageData ||
        lastElement?.position != imageElement.position ||
        lastElement?.size != imageElement.size ||
        lastElement?.rotation != imageElement.rotation

      if needsUpdate {
        // 考虑控制点触控区域，调整 frame
        let inset = imageView.controlPointTouchSize / 2
        let adjustedFrame = CGRect(
          x: imageElement.position.x - inset,
          y: imageElement.position.y - inset,
          width: imageElement.size.width + inset * 2,
          height: imageElement.size.height + inset * 2
        )
        imageView.frame = adjustedFrame
        imageView.transform = CGAffineTransform(rotationAngle: imageElement.rotation)

        // 如果视图不在容器中，添加它
        if imageView.superview == nil {
          context.coordinator.imageContainer?.addImageView(imageView)
        }
      }

      // 更新回调
      imageView.onPositionChanged = { [weak coordinator = context.coordinator] newPosition in
        guard let coordinator = coordinator else { return }
        // 需要考虑控制点触控区域的偏移
        let inset = imageView.controlPointTouchSize / 2
        let actualPosition = CGPoint(
          x: newPosition.x + inset,
          y: newPosition.y + inset
        )
        coordinator.updateImagePosition(imageId: imageElement.id, position: actualPosition)
      }

      imageView.onSizeChanged = { [weak coordinator = context.coordinator] newSize in
        guard let coordinator = coordinator else { return }
        // 需要考虑控制点触控区域的大小
        let inset = imageView.controlPointTouchSize
        let actualSize = CGSize(
          width: newSize.width - inset,
          height: newSize.height - inset
        )
        coordinator.updateImageSize(imageId: imageElement.id, size: actualSize)
      }

      imageView.onTapped = {
        guard let imageId = imageView.imageId else { return }

        if imageId == imageEditingId {
          imageEditingId = nil
        } else {
          imageEditingId = imageId
        }

        imageView.editingId = imageEditingId
        imageView.isUserInteractionEnabled = isSelectorActive || imageEditingId == imageId
      }

      // 添加删除回调
      imageView.onDelete = { [weak coordinator = context.coordinator] in
        guard let coordinator = coordinator else { return }
        coordinator.parent.deleteImage(imageElement.id)
      }
    }
  }

  // MARK: WebView

  func updateWebViews(in canvas: PKCanvasView, context: Context) {
    let currentWebIds = Set(model.webs.map { $0.id })
    let existingWebViews = context.coordinator.webViewCache

    for (webId, webView) in existingWebViews {
      if !currentWebIds.contains(webId) {
        context.coordinator.imageContainer?.removeWebView(webView)
        context.coordinator.webViewCache.removeValue(forKey: webId)
      }
    }

    for webElement in model.webs {
      guard let webView = context.coordinator.getOrCreateWebView(for: webElement) else { continue }

      webView.editingId = imageEditingId
      webView.isLocked = isLocked
      webView.isUserInteractionEnabled = isSelectorActive || webView.editingId == webElement.id

      let lastElement = context.coordinator.lastWebElements[webElement.id]
      let needsUpdate = existingWebViews[webElement.id] == nil ||
        lastElement?.url != webElement.url ||
        lastElement?.position != webElement.position ||
        lastElement?.size != webElement.size ||
        lastElement?.rotation != webElement.rotation

      if needsUpdate {
        let inset = webView.controlPointTouchSize / 2
        let adjustedFrame = CGRect(
          x: webElement.position.x - inset,
          y: webElement.position.y - inset,
          width: webElement.size.width + inset * 2,
          height: webElement.size.height + inset * 2
        )
        webView.frame = adjustedFrame
        webView.transform = CGAffineTransform(rotationAngle: webElement.rotation)
        if webView.superview == nil {
          context.coordinator.imageContainer?.addWebView(webView)
        }
      }

      webView.onPositionChanged = { [weak coordinator = context.coordinator] newPosition in
        guard let coordinator = coordinator else { return }
        let inset = webView.controlPointTouchSize / 2
        let actualPosition = CGPoint(x: newPosition.x + inset, y: newPosition.y + inset)
        coordinator.updateWebPosition(webId: webElement.id, position: actualPosition)
      }

      webView.onSizeChanged = { [weak coordinator = context.coordinator] newSize in
        guard let coordinator = coordinator else { return }
        let inset = webView.controlPointTouchSize
        let actualSize = CGSize(width: newSize.width - inset, height: newSize.height - inset)
        coordinator.updateWebSize(webId: webElement.id, size: actualSize)
      }

      webView.onTapped = {
        guard let id = webView.webId else { return }
        if id == imageEditingId {
          imageEditingId = nil
        } else {
          imageEditingId = id
        }
        webView.editingId = imageEditingId
        webView.isUserInteractionEnabled = isSelectorActive || imageEditingId == id
      }

      webView.onDelete = { [weak coordinator = context.coordinator] in
        guard let coordinator = coordinator else { return }
        coordinator.parent.deleteWeb(webElement.id)
      }
    }
    context.coordinator.lastWebs = model.webs
    context.coordinator.lastWebElements = Dictionary(uniqueKeysWithValues: model.webs.map { ($0.id, $0) })
  }
}
