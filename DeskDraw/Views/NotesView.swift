//
//  NotesView.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/27.
//

import AVFoundation
import PencilKit
import SwiftUI

struct NotesView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismissWindow) private var dismissWindow
  @State private var isEditing = false
  
  let canvas: PKCanvasView

  private let columns = [
    GridItem(.adaptive(minimum: 180, maximum: 220)),
  ]

  var body: some View {
    let _ = print(#function, "appModel.thumbnails.count \(appModel.thumbnails.count))")
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVGrid(columns: columns, spacing: 0) {
            addButton
            allNotes
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 24)
        }
        .navigationTitle("Notes")
        .toolbar {
          ToolbarItem(placement: .topBarLeading) { returnButton }
          if isEditing {
            ToolbarItem(placement: .topBarTrailing) { undoButton }
          } else {
            if !appModel.subscriptionViewModel.hasPro {
              ToolbarItem(placement: .topBarTrailing) { subscriptionButton }
            }
            ToolbarItem(placement: .topBarTrailing) { aboutButton }
          }
          ToolbarItem(placement: .topBarTrailing) { editButton }
        }
        .onChange(of: appModel.showNotes) { _, newValue in
//          guard newValue else { return }
//          print(#function, "scrollTo \(appModel.drawingIndex)")
//          proxy.scrollTo(appModel.drawingIndex, anchor: .center)
        }
      }
    }
  }

  @MainActor
  @ViewBuilder
  private var allNotes: some View {
    ForEach(appModel.ids, id: \.self) { id in
      ZStack {
        RoundedRectangle(cornerRadius: 20)
          .foregroundStyle(.white.opacity(0.15))
        if let thumbnail = appModel.thumbnails[id] {
          Image(uiImage: thumbnail)
            .resizable()
            .cornerRadius(16)
            .padding(8)
        } else {
          Image(systemName: "questionmark.app.dashed")
        }
        if id == appModel.drawingId {
          RoundedRectangle(cornerRadius: 20)
            .stroke(Color.white, lineWidth: 3)
        }
      }
      .id(id)
      .aspectRatio(1, contentMode: .fit)
      .padding(8)
      .hoverEffect { effect, isActive, geometry in
        effect.animation(.default) {
          $0.scaleEffect(isActive ? 1.1 : 1.0)
        }
      }
      .onTapGesture {
        handleNoteTap(at: id)
      }
      .overlay {
        if isEditing {
          HStack {
            Spacer()
            VStack {
              Button(action: {
                appModel.deleteDrawing(id)
              }, label: {
                Image(systemName: "minus")
              })
              Spacer()
            }
          }
        }
      }
    }
  }

  @MainActor
  @ViewBuilder
  private var addButton: some View {
    if appModel.subscriptionViewModel.hasPro {
      ZStack {
        RoundedRectangle(cornerRadius: 20).foregroundStyle(.white.opacity(0.15))
        VStack(spacing: 8) {
          Image(systemName: "plus")
            .font(.extraLargeTitle2)
        }
      }
      .aspectRatio(1, contentMode: .fit)
      .padding(8)
      .hoverEffect { effect, isActive, geometry in
        effect.animation(.default) {
          $0.scaleEffect(isActive ? 1.1 : 1.0)
        }
      }
      .onTapGesture {
        AudioServicesPlaySystemSound(1104)
        addNewDrawing()
      }
    } else {
      ZStack {
        RoundedRectangle(cornerRadius: 20).foregroundStyle(.white.opacity(0.15))
        VStack(spacing: 8) {
          Image(systemName: "plus")
            .font(.extraLargeTitle2)
          Text("Left \(max(0, 3 - appModel.drawings.count)) drawings")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .aspectRatio(1, contentMode: .fit)
      .padding(8)
      .hoverEffect { effect, isActive, geometry in
        effect.animation(.default) {
          $0.scaleEffect(isActive ? 1.1 : 1.0)
        }
      }
      .onTapGesture {
        AudioServicesPlaySystemSound(1104)
        if appModel.drawings.count <= 2 {
          addNewDrawing()
        } else {
          dismissWindow(id: "subscription")
          openWindow(id: "subscription")
        }
      }
    }
  }

  @MainActor
  @ViewBuilder
  private var editButton: some View {
    Button(action: {
      isEditing.toggle()
    }, label: {
      Text(isEditing ? "Done" : "Edit")
    })
  }

  @MainActor
  @ViewBuilder
  private var returnButton: some View {
    Button(action: {
      appModel.showNotes = false
      appModel.showDrawing = true
    }, label: {
      Text("Back")
    })
  }

  @MainActor
  @ViewBuilder
  private var undoButton: some View {
    Button(action: {
      appModel.recoverNote()
    }, label: {
      Image(systemName: "arrow.uturn.left")
    })
    .disabled(appModel.deletedDrawings.isEmpty)
  }

  @MainActor
  @ViewBuilder
  private var aboutButton: some View {
    Button(action: {
      dismissWindow(id: "about")
      openWindow(id: "about")
    }, label: {
      Text("About")
    })
  }

  @MainActor
  @ViewBuilder
  private var subscriptionButton: some View {
    Button(action: {
      dismissWindow(id: "subscription")
      openWindow(id: "subscription")
    }, label: {
      Text("Get Pro")
    })
    .buttonStyle(.borderless)
  }
  
  @MainActor
  private func addNewDrawing() {
    appModel.updateDrawing(appModel.drawingId)
    appModel.addNewDrawing()
    appModel.showNotes = false
    appModel.showDrawing = true
    
//    Task {
//      print(#function, "canvas \(canvas.debugDescription) \(canvas.frame)")
//      
//      // 检查绘图和画布状态
////      guard let lastIndex = appModel.drawings.indices.last,
////            let currentDrawing = appModel.drawings[safe: lastIndex]?.drawing else {
////        print(#function, "No drawings available")
////        return
////      }
//      guard let currentDrawing = appModel.currentDrawing?.drawing else { return }
//      
//      let isDrawingValid = !currentDrawing.strokes.isEmpty
//      let isCanvasValid = !canvas.drawing.bounds.isNull && !canvas.frame.width.isNaN && !canvas.frame.height.isNaN
//      
//      guard isDrawingValid && isCanvasValid else {
//        print(#function, "Not set position")
//        return
//      }
//      
//      try await Task.sleep(for: .seconds(0.1))
//      
//      // 计算偏移量
//      let bounds = currentDrawing.bounds
//      print(#function, "onTapGesture frame \(canvas.frame.width) \(canvas.frame.height) minX \(bounds.minX) midX \(bounds.midX)")
//      
//      let xOffset: CGFloat
//      if bounds.width > canvas.frame.width {
//        xOffset = bounds.minX
//      } else {
//        xOffset = bounds.midX - canvas.frame.width / 2
//      }
//      
//      let yOffset: CGFloat
//      if bounds.height > canvas.frame.height {
//        yOffset = bounds.minY
//      } else {
//        yOffset = bounds.midY - canvas.frame.height / 2
//      }
//      
//      let finalX = max(xOffset, 0)
//      let finalY = max(yOffset, 0)
//      
//      print(#function, "onTapGesture setContentOffset x \(finalX) y \(finalY)")
//      canvas.setContentOffset(CGPoint(x: finalX, y: finalY), animated: false)
//    }
  }
  
  @MainActor
  private func handleNoteTap(at id: UUID) {
    print(#function, "drawingId \(id)")
    AudioServicesPlaySystemSound(1104)
    
    // 安全检查
//    guard index >= 0, index < appModel.drawings.count else {
//      print(#function, "Invalid index: \(index)")
//      return
//    }
    
    appModel.updateDrawing(appModel.drawingId)
    appModel.selectDrawingId(id)
    appModel.showNotes = false
    appModel.showDrawing = true
    
//    Task {
//      // 检查绘图和画布状态
//      guard let currentDrawing = appModel.currentDrawing?.drawing else { return }
////      let currentDrawing = appModel.drawings[id].drawing
//      
//      let isDrawingValid = !currentDrawing.strokes.isEmpty
//      let isCanvasValid = !canvas.drawing.bounds.isNull && !canvas.frame.width.isNaN && !canvas.frame.height.isNaN
//      
//      guard isDrawingValid && isCanvasValid else {
//        print(#function, "Not set position")
//        return
//      }
//      
//      try await Task.sleep(for: .seconds(0.1))
//      
//      // 计算偏移量
//      let bounds = currentDrawing.bounds
//      print(#function, "onTapGesture frame \(canvas.frame.width) \(canvas.frame.height) minX \(bounds.minX) midX \(bounds.midX)")
//      
//      let xOffset: CGFloat
//      if bounds.width > canvas.frame.width {
//        xOffset = bounds.minX
//      } else {
//        xOffset = bounds.midX - canvas.visibleSize.width / 2
//      }
//      
//      let yOffset: CGFloat
//      if bounds.height > canvas.frame.height {
//        yOffset = bounds.minY
//      } else {
//        yOffset = bounds.midY - canvas.visibleSize.height / 2
//      }
//      
//      let finalX = max(xOffset, 0)
//      let finalY = max(yOffset, 0)
//      
//      print(#function, "onTapGesture setContentOffset x \(finalX) y \(finalY)")
//      canvas.setContentOffset(CGPoint(x: finalX, y: finalY), animated: false)
//    }
  }
}

//extension Collection {
//    /// 返回指定索引的元素，如果索引越界则返回 nil
//    subscript(safe index: Index) -> Element? {
//        return indices.contains(index) ? self[index] : nil
//    }
//}

#Preview {
  NotesView(canvas: PKCanvasView())
    .environment(AppModel())
}
