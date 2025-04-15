import SwiftUI
import PencilKit

struct QuickDrawingSwitch: View {
  @Environment(AppModel.self) private var appModel
  
  let size: CGFloat = 50
  let gap: CGFloat = 8
  var scrollViewWidth: CGFloat {
    size * 3 + gap * 3
  }
  
  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: gap) {
          ForEach(appModel.ids.sorted { id1, id2 in
            let drawing1 = appModel.drawings[id1]
            let drawing2 = appModel.drawings[id2]
            if drawing1?.isFavorite == true && drawing2?.isFavorite == false {
              return true
            }
            if drawing1?.isFavorite == false && drawing2?.isFavorite == true {
              return false
            }
            return false
          }, id: \.self) { id in
            if let drawing = appModel.drawings[id] {
              drawingThumbnail(drawing, isFavorite: drawing.isFavorite)
                .id(id)
            }
          }
        }
        .padding(.horizontal, size * 1/4)
        .padding(.vertical, 4)
      }
      .frame(width: scrollViewWidth)
      .mask {
        HStack(spacing: 0) {
          LinearGradient(
            gradient: Gradient(colors: [.clear, .white, .white, .white, .white, .clear]),
            startPoint: .leading,
            endPoint: .trailing
          )
        }
      }
      .contentShape(Rectangle())
      .onChange(of: appModel.drawingId) { _, newId in
        if let id = newId {
          withAnimation(.smooth) {
            proxy.scrollTo(id, anchor: .center)
          }
        }
      }
      .onAppear {
        if let id = appModel.drawingId {
          withAnimation(.smooth) {
            proxy.scrollTo(id, anchor: .center)
          }
        }
      }
    }
  }
  
  @MainActor
  @ViewBuilder
  private func drawingThumbnail(_ drawing: DrawingModel, isFavorite: Bool) -> some View {
    ZStack {
      RoundedRectangle(cornerSize: .init(width: 8, height: 8), style: .continuous)
        .fill(.ultraThinMaterial)
      if let thumbnail = appModel.thumbnails[drawing.id] {
        Image(uiImage: thumbnail)
          .resizable()
          .clipShape(.rect(cornerRadius: 8, style: .continuous))
          .padding(4)
      } else {
        Image(systemName: "questionmark.app.dashed")
      }
      if drawing.id == appModel.drawingId {
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.white, lineWidth: 2)
      }
    }
    .frame(width: size, height: size)
    .contentShape(Rectangle())
    .overlay(alignment: .topTrailing, content: {
      if isFavorite {
        Image(systemName: "star.fill")
          .font(.system(size: 6))
          .padding(4)
      }
    })
    .allowsHitTesting(true)
    .onTapGesture {
      appModel.selectDrawingId(drawing.id)
      appModel.updateDrawing(drawing.id)
    }
  }
}

#Preview {
  QuickDrawingSwitch()
    .environment(AppModel())
} 
