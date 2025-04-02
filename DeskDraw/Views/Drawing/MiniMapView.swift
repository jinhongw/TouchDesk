import AVFoundation
import Combine
import PencilKit
import SwiftUI

struct MiniMapView: View {
  @Environment(AppModel.self) private var appModel
  let canvas: PKCanvasView
  let size: CGSize = .init(width: 88, height: 88)
  @Binding var contentOffset: CGPoint

  // 用于节流的状态
  @State private var lastUpdateTime: Date = .now
  private let canvasOverscrollDistance: CGFloat = 600

  var body: some View {
    VStack(spacing: 8) {
      // 添加缩放控制器
      ZoomControlView(zoomFactor: zoomFactorBinding)
        .frame(width: size.width)
      
      // 原有的 MiniMap 视图
      GeometryReader { geometry in
        ZStack {
          // 背景
          RoundedRectangle(cornerSize: .init(width: 12, height: 12), style: .continuous)
            .fill(.ultraThinMaterial)

          // 画布内容缩略图
          if let drawingId = appModel.drawingId,
             let thumbnail = appModel.thumbnails[drawingId]
          {
            // 计算实际内容区域
            let contentBounds = getContentBounds()
            let contentScale = calculateContentScale(contentBounds: contentBounds)

            // 计算缩略图在小地图中的位置和大小
            let thumbnailFrame = calculateThumbnailFrame(
              contentBounds: contentBounds,
              contentScale: contentScale,
              thumbnailSize: thumbnail.size
            )

            Image(uiImage: thumbnail)
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: thumbnailFrame.width, height: thumbnailFrame.height)
              .position(x: thumbnailFrame.minX + thumbnailFrame.width / 2,
                        y: thumbnailFrame.minY + thumbnailFrame.height / 2)
          }

          // 当前视口指示器
          viewportIndicator
        }
      }
      .frame(width: size.width, height: size.height)
      .gesture(
        DragGesture()
          .onChanged { value in
            updateContentOffset(value.location, isDragging: true)
          }
          .onEnded { value in
            updateContentOffset(value.location, isDragging: false)
          }
          .simultaneously(with: SpatialTapGesture()
            .onEnded { value in
              updateContentOffset(value.location, isDragging: false)
            }
          )
      )
    }
    .onChange(of: canvas.contentOffset) { _, _ in
      throttledUpdateThumbnail()
    }
    .onChange(of: appModel.drawingId) { _, _ in
      // 切换 drawing 时立即更新缩略图
      updateThumbnail()
    }
    .onChange(of: canvas.contentSize) { _, _ in
      // 画布尺寸变化时更新缩略图
      updateThumbnail()
    }
    .onChange(of: canvas.drawing) { _, _ in
      // 绘制内容变化时更新缩略图
      updateThumbnail()
    }
    .onChange(of: appModel.canvasZoomFactor) { _, _ in
      // 缩放比例变化时更新缩略图并调整内容
      updateCanvasForZoom()
    }
    .onAppear {
      updateThumbnail()
    }
  }
  
  // 创建缩放因子的绑定
  private var zoomFactorBinding: Binding<Double> {
    Binding(
      get: { appModel.canvasZoomFactor },
      set: { appModel.canvasZoomFactor = $0 }
    )
  }
  
  // 根据缩放比例更新画布内容
  private func updateCanvasForZoom() {
    // 画布的缩放由 DrawingUIViewRepresentable 处理
    // 这里只需触发画布内容的重新布局
    canvas.setNeedsDisplay()
  }

  private func getContentBounds() -> CGRect {
    guard let drawingId = appModel.drawingId,
          let drawing = appModel.drawings[drawingId]
    else {
      return CGRect(origin: .zero, size: canvas.contentSize)
    }

    // 检查是否有任何内容（绘画或图片）
    let hasDrawing = !drawing.drawing.strokes.isEmpty && !drawing.drawing.bounds.isEmpty
    var bounds = hasDrawing ? drawing.drawing.bounds : .zero

    // 从 model 中获取图片信息
    let hasImages = !drawing.images.isEmpty
    for imageElement in drawing.images {
      // 使用原始位置和大小，不应用缩放因子
      let imageFrame = CGRect(origin: imageElement.position, size: imageElement.size)
      bounds = bounds == .zero ? imageFrame : bounds.union(imageFrame)
    }

    // 如果既没有绘画也没有图片，使用画布尺寸
    if !hasDrawing && !hasImages {
      bounds = CGRect(origin: .zero, size: canvas.contentSize)
    }

    return bounds
  }

  private func calculateContentScale(contentBounds: CGRect) -> CGFloat {
    let availableWidth = size.width - 4
    let availableHeight = size.height - 4

    // 使用原始内容尺寸
    let totalWidth = canvas.contentSize.width
    let totalHeight = canvas.contentSize.height

    let scaleX = availableWidth / totalWidth
    let scaleY = availableHeight / totalHeight
    return min(scaleX, scaleY)
  }

  private func calculateThumbnailFrame(contentBounds: CGRect, contentScale: CGFloat, thumbnailSize: CGSize) -> CGRect {
    // 计算画布在小地图中的总尺寸
    let scaledCanvasWidth = canvas.contentSize.width * contentScale
    let scaledCanvasHeight = canvas.contentSize.height * contentScale

    // 计算内容区域相对于画布的位置比例
    let contentXRatio = contentBounds.minX / canvas.contentSize.width
    let contentYRatio = contentBounds.minY / canvas.contentSize.height
    let contentWidthRatio = contentBounds.width / canvas.contentSize.width
    let contentHeightRatio = contentBounds.height / canvas.contentSize.height

    // 计算缩略图在小地图中的位置和大小
    let thumbnailX = (size.width - scaledCanvasWidth) / 2 + scaledCanvasWidth * contentXRatio
    let thumbnailY = (size.height - scaledCanvasHeight) / 2 + scaledCanvasHeight * contentYRatio
    let thumbnailWidth = scaledCanvasWidth * contentWidthRatio
    let thumbnailHeight = scaledCanvasHeight * contentHeightRatio

    return CGRect(x: thumbnailX, y: thumbnailY, width: thumbnailWidth, height: thumbnailHeight)
  }

  private var viewportIndicator: some View {
    let contentScale = calculateContentScale(contentBounds: getContentBounds())
    let visibleSize = canvas.frame.size
    let zoomFactor = CGFloat(appModel.canvasZoomFactor / 100)

    // 计算视口在小地图中的尺寸，考虑缩放因子
    let viewportWidth = visibleSize.width * contentScale / zoomFactor
    let viewportHeight = visibleSize.height * contentScale / zoomFactor

    // 计算视口在小地图中的位置
    let scaledCanvasWidth = canvas.contentSize.width * contentScale
    let scaledCanvasHeight = canvas.contentSize.height * contentScale
    let contentX = (size.width - scaledCanvasWidth) / 2
    let contentY = (size.height - scaledCanvasHeight) / 2

    // 考虑缩放因子调整偏移量
    let viewportX = contentX + contentOffset.x * contentScale / zoomFactor
    let viewportY = contentY + contentOffset.y * contentScale / zoomFactor

    return RoundedRectangle(cornerSize: .init(width: 2, height: 2), style: .continuous)
      .strokeBorder(Color.white.opacity(0.8), lineWidth: 1)
      .frame(width: viewportWidth, height: viewportHeight)
      .position(x: viewportX + viewportWidth / 2, y: viewportY + viewportHeight / 2)
  }

  private func throttledUpdateThumbnail() {
    let now = Date()
    // 限制更新频率为每秒最多2次
    if now.timeIntervalSince(lastUpdateTime) > 0.5 {
      updateThumbnail()
      lastUpdateTime = now
    }
  }

  private func updateThumbnail() {
    guard let drawingId = appModel.drawingId else { return }
    Task { @MainActor in
      appModel.generateThumbnail(drawingId)
    }
  }

  private func updateContentOffset(_ location: CGPoint, isDragging: Bool = true) {
    let contentScale = calculateContentScale(contentBounds: getContentBounds())
    let visibleSize = canvas.frame.size
    let zoomFactor = CGFloat(appModel.canvasZoomFactor / 100)

    // 计算画布在小地图中的总尺寸和位置
    let scaledCanvasWidth = canvas.contentSize.width * contentScale
    let scaledCanvasHeight = canvas.contentSize.height * contentScale
    let contentX = (size.width - scaledCanvasWidth) / 2
    let contentY = (size.height - scaledCanvasHeight) / 2

    // 计算新的偏移量，考虑缩放因子
    let newX = (location.x - contentX) / contentScale * zoomFactor - visibleSize.width / 2
    let newY = (location.y - contentY) / contentScale * zoomFactor - visibleSize.height / 2

    // 确保偏移量不超出边界，考虑缩放因子
    let maxOffsetX = max(0, canvas.contentSize.width * zoomFactor - visibleSize.width)
    let maxOffsetY = max(0, canvas.contentSize.height * zoomFactor - visibleSize.height)

    let newOffset = CGPoint(
      x: min(max(0, newX), maxOffsetX),
      y: min(max(0, newY), maxOffsetY)
    )

    // 只有当偏移量真正改变时才更新
    if abs(contentOffset.x - newOffset.x) > 0.01 || abs(contentOffset.y - newOffset.y) > 0.01 {
      contentOffset = newOffset
      canvas.setContentOffset(contentOffset, animated: !isDragging)
    }
  }
}

// 缩放控制视图
struct ZoomControlView: View {
  @Binding var zoomFactor: Double
  private let stepSize: Double = 25 // 25% 的缩放步长
  
  var body: some View {
    ZStack {
      RoundedRectangle(cornerSize: .init(width: 12, height: 12), style: .continuous)
        .fill(.ultraThinMaterial)
      HStack(spacing: 4) {
        // 减小缩放按钮
        Image(systemName: "minus")
          .font(.system(size: 8, weight: .bold))
          .frame(width: 12, height: 12)
          .disabled(zoomFactor <= 25)
          .padding(4)
          .contentShape(Circle())
          .hoverEffect(.highlight)
          .onTapGesture {
            decreaseZoom()
            AudioServicesPlaySystemSound(1104)
          }
        
        Text("\(Int(zoomFactor))%")
          .font(.system(size: 8, weight: .medium))
          .frame(width: 24, height: 12)
          .padding(4)
          .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
          .hoverEffect(.highlight)
          .onTapGesture {
            zoomFactor = 100
            AudioServicesPlaySystemSound(1104)
          }
        
        Image(systemName: "plus")
          .font(.system(size: 8, weight: .bold))
          .frame(width: 12, height: 12)
          .disabled(zoomFactor >= 200)
          .padding(4)
          .contentShape(Circle())
          .hoverEffect(.highlight)
          .onTapGesture {
            increaseZoom()
            AudioServicesPlaySystemSound(1104)
          }
      }
      .padding(4)
    }
    .frame(height: 20)
    .padding(4)
  }
  
  private func decreaseZoom() {
    withAnimation(.easeInOut(duration: 0.2)) {
      zoomFactor = max(25, zoomFactor - stepSize)
    }
  }
  
  private func increaseZoom() {
    withAnimation(.easeInOut(duration: 0.2)) {
      zoomFactor = min(200, zoomFactor + stepSize)
    }
  }
}

#Preview {
  MiniMapView(canvas: PKCanvasView(), contentOffset: .constant(.init(x: 100, y: 100)))
    .environment(AppModel())
}
