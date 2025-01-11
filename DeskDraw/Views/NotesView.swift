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
            ToolbarItem(placement: .topBarTrailing) { aboutButton }
          }
          ToolbarItem(placement: .topBarTrailing) { editButton }
        }
        .onChange(of: appModel.showNotes) { _, newValue in
          guard newValue else { return }
          print(#function, "scrollTo \(appModel.drawingIndex)")
          proxy.scrollTo(appModel.drawingIndex, anchor: .center)
        }
      }
    }
  }

  @MainActor
  @ViewBuilder
  private var allNotes: some View {
    ForEach(appModel.thumbnails.indices.reversed(), id: \.self) { index in
      ZStack {
        RoundedRectangle(cornerRadius: 20)
          .foregroundStyle(.white.opacity(0.15))
        if index <= appModel.thumbnails.count - 1 {
          Image(uiImage: appModel.thumbnails[index])
            .resizable()
            .cornerRadius(20)
        } else {
          Image(systemName: "questionmark.app.dashed")
        }
        if index == appModel.drawingIndex {
          RoundedRectangle(cornerRadius: 20)
            .stroke(Color.white, lineWidth: 3)
        }
      }
      .id(index)
      .aspectRatio(1, contentMode: .fit)
      .padding(8)
      .hoverEffect { effect, isActive, geometry in
        effect.animation(.default) {
          $0.scaleEffect(isActive ? 1.1 : 1.0)
        }
      }
      .onTapGesture {
        print(#function, "drawingIndex \(index)")
        AudioServicesPlaySystemSound(1104)
        appModel.updateDrawing(appModel.drawingIndex)
        appModel.selectDrawingIndex(index)
        appModel.showNotes = false
        appModel.showDrawing = true
      }
      .overlay {
        if isEditing {
          HStack {
            Spacer()
            VStack {
              Button(action: {
                appModel.deleteDrawing(index)
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
    ZStack {
      RoundedRectangle(cornerRadius: 20).foregroundStyle(.white.opacity(0.15))
      Image(systemName: "plus")
        .font(.extraLargeTitle2)
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
      appModel.updateDrawing(appModel.drawingIndex)
      appModel.addNewDrawing()
      appModel.showNotes = false
      appModel.showDrawing = true
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
}

#Preview {
  NotesView()
    .environment(AppModel())
}
