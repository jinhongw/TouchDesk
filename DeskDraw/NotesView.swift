//
//  NotesView.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/27.
//

import SwiftUI

struct NotesView: View {
  @Environment(AppModel.self) var appModel

  let columns = [
    GridItem(.adaptive(minimum: 280)),
  ]

  var body: some View {
    let _ = print(#function, "appModel.thumbnails.count \(appModel.thumbnails.count))")
    NavigationStack {
      ScrollView {
        LazyVGrid(columns: columns, spacing: 20) {
          allNotes
          addButton
        }
        .padding(.horizontal, 24)
      }
      .navigationTitle("Notes")
    }
  }
  
  @MainActor
  @ViewBuilder
  private var allNotes: some View {
    ForEach(appModel.thumbnails.indices, id: \.self) { index in
      Button(action: {
        print(#function, "drawingIndex \(index)")
        appModel.updateDrawing(appModel.drawingIndex)
        appModel.drawingIndex = index
      }, label: {
        ZStack {
          RoundedRectangle(cornerRadius: 20).foregroundStyle(.white.opacity(0.15))
          Image(uiImage: appModel.thumbnails[index])
            .resizable()
        }
        .frame(width: 280, height: 280)
      })
      .buttonStyle(.plain)
    }
  }
  
  @MainActor
  @ViewBuilder
  private var addButton: some View {
    Button(action: {
      appModel.updateDrawing(appModel.drawingIndex)
      appModel.addNewDrawing()
    }, label: {
      ZStack {
        RoundedRectangle(cornerRadius: 20).foregroundStyle(.white.opacity(0.15))
        Image(systemName: "plus")
          .font(.extraLargeTitle2)
      }
      .frame(width: 280, height: 280)
    })
    .buttonStyle(.plain)
  }
}

#Preview {
  NotesView()
    .environment(AppModel())
}
