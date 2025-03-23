func updateUIView(_ canvas: PKCanvasView, context: Context) {
    canvas.isDrawingEnabled = !isLocked
    canvas.tool = getTool()

    if context.coordinator.lastDrawingId != model.id {
      print(#function, "DEBUG Change drawing")
      context.coordinator.isUpdatingFromModel = true
      canvas.undoManager?.removeAllActions()

      // 清理图片视图缓存
      context.coordinator.cleanupImageViewCache(currentImageIds: Set(model.images.map { $0.id }))

      canvas.drawing = model.drawing
      DispatchQueue.main.async {
        updateContentSizeForDrawing()
      }
      setPosition()

      // 更新图片视图
      updateImageViews(in: canvas, context: context)

      context.coordinator.lastDrawingId = model.id
      context.coordinator.lastImages = model.images
      context.coordinator.isUpdatingFromModel = false
    } else if context.coordinator.lastImages != model.images {
      print(#function, "DEBUG Change images")

      // 更新图片视图
      updateImageViews(in: canvas, context: context)

      context.coordinator.lastImages = model.images
      DispatchQueue.main.async {
        updateContentSizeForDrawing()
      }
      saveDrawing()
      updateExportImage()
    } else if context.coordinator.lastSelectorActive != isSelectorActive || context.coordinator.lastImageEditingId != imageEditingId {
      print(#function, "DEBUG Change selector active state")
      context.coordinator.lastSelectorActive = isSelectorActive
      updateImageViews(in: canvas, context: context)
    } else if context.coordinator.lastImageEditingId != imageEditingId {
      print(#function, "DEBUG Change imageEditingId")
      context.coordinator.lastImageEditingId = imageEditingId
      updateImageViews(in: canvas, context: context)
    }
  }

func makeUIView(context: Context) -> PKCanvasView {
    print(#function, "make canvas \(model.id) width: \(canvasWidth) height \(canvasHeight)")
    canvas.drawing = model.drawing
    canvas.isDrawingEnabled = !isLocked
    canvas.tool = getTool()
    canvas.backgroundColor = .clear
    canvas.drawingPolicy = .anyInput
    canvas.alwaysBounceHorizontal = true
    canvas.alwaysBounceVertical = true
    canvas.contentSize = defaultSize
    canvas.becomeFirstResponder()
    context.coordinator.lastDrawingId = model.id
    context.coordinator.lastImages = model.images
    canvas.delegate = context.coordinator

    // 添加滚动视图代理
    canvas.delegate = context.coordinator

    // 监听滚动位置变化
    let observer = canvas.observe(\.contentOffset, options: [.new]) { _, change in
      if let newOffset = change.newValue {
        context.coordinator.parent.contentOffset = newOffset
      }
    }
    context.coordinator.contentOffsetObserver = observer

    DispatchQueue.main.async {
      updateContentSizeForDrawing()
    }

    Task {
      try await Task.sleep(for: .seconds(0.5))
      setPosition()
    }

    // 清理现有的图片视图
    canvas.subviews.forEach { view in
      if view is UIImageView {
        view.removeFromSuperview()
      }
    }

    // 使用新的图片视图管理逻辑
    updateImageViews(in: canvas, context: context)

    return canvas
  }
// ... existing code ...