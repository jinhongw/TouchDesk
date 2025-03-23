import SwiftUI
import PencilKit
import Combine

struct MiniMapView: View {
    @Environment(AppModel.self) private var appModel
    let canvas: PKCanvasView
    let size: CGSize = CGSize(width: 100, height: 100)
    @Binding var contentOffset: CGPoint
    
    // 用于节流的状态
    @State private var lastUpdateTime: Date = .now
    private let canvasOverscrollDistance: CGFloat = 600
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景
                RoundedRectangle(cornerSize: .init(width: 16, height: 16), style: .continuous)
                    .fill(Color.white.opacity(0.1))
                
                // 画布内容缩略图
                if let drawingId = appModel.drawingId,
                   let thumbnail = appModel.thumbnails[drawingId] {
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
        .gesture(DragGesture()
            .onChanged { value in
                updateContentOffset(value.location)
            }
        )
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
        .onAppear {
            updateThumbnail()
        }
    }
    
    private func getContentBounds() -> CGRect {
        var bounds = canvas.drawing.bounds
        for subview in canvas.subviews {
            if let imageView = subview as? UIImageView {
                bounds = bounds.union(imageView.frame)
            }
        }
        if bounds.isNull || bounds.isEmpty {
            bounds = CGRect(origin: .zero, size: canvas.contentSize)
        }
        return bounds
    }
    
    private func calculateContentScale(contentBounds: CGRect) -> CGFloat {
        let availableWidth = size.width - 8
        let availableHeight = size.height - 8
        
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
        
        // 计算视口在小地图中的尺寸
        let viewportWidth = visibleSize.width * contentScale
        let viewportHeight = visibleSize.height * contentScale
        
        // 计算视口在小地图中的位置
        let scaledCanvasWidth = canvas.contentSize.width * contentScale
        let scaledCanvasHeight = canvas.contentSize.height * contentScale
        let contentX = (size.width - scaledCanvasWidth) / 2
        let contentY = (size.height - scaledCanvasHeight) / 2
        
        let viewportX = contentX + contentOffset.x * contentScale
        let viewportY = contentY + contentOffset.y * contentScale
        
        return RoundedRectangle(cornerSize: .init(width: 4, height: 4), style: .continuous)
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
    
    private func updateContentOffset(_ location: CGPoint) {
        let contentScale = calculateContentScale(contentBounds: getContentBounds())
        let visibleSize = canvas.frame.size
        
        // 计算画布在小地图中的总尺寸和位置
        let scaledCanvasWidth = canvas.contentSize.width * contentScale
        let scaledCanvasHeight = canvas.contentSize.height * contentScale
        let contentX = (size.width - scaledCanvasWidth) / 2
        let contentY = (size.height - scaledCanvasHeight) / 2
        
        // 计算新的偏移量
        let newX = (location.x - contentX) / contentScale
        let newY = (location.y - contentY) / contentScale
        
        // 确保偏移量不超出边界
        let maxOffsetX = max(0, canvas.contentSize.width - visibleSize.width)
        let maxOffsetY = max(0, canvas.contentSize.height - visibleSize.height)
        
        contentOffset = CGPoint(
            x: min(max(0, newX), maxOffsetX),
            y: min(max(0, newY), maxOffsetY)
        )
        
        canvas.setContentOffset(contentOffset, animated: true)
    }
} 
