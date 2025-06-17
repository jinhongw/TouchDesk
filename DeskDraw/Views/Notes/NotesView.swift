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
  @State private var isAddButtonVisible = true

  let canvas: PKCanvasView
  let canvasId: UUID

  private let columns = [
    GridItem(.adaptive(minimum: 180, maximum: 220)),
  ]

  private var haveFavoriteNotes: Bool {
    appModel.drawings.contains(where: { $0.value.isFavorite })
  }

  var body: some View {
    let _ = print(#function, "appModel.thumbnails.count \(appModel.thumbnails.count)")
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          VStack {
            if haveFavoriteNotes {
              LazyVGrid(columns: columns, spacing: 0) {
                addNoteButton
                ForEach(appModel.ids, id: \.self) { id in
                  if appModel.drawings[id]?.isFavorite ?? false {
                    noteView(id: id)
                      .id(id)
                      .hoverEffectGroup()
                  }
                }
              }
              Divider()
                .padding(12)
            }
            LazyVGrid(columns: columns, spacing: 0) {
              if !haveFavoriteNotes {
                addNoteButton
              }
              ForEach(appModel.ids, id: \.self) { id in
                if !(appModel.drawings[id]?.isFavorite ?? false) {
                  noteView(id: id)
                    .id(id)
                    .hoverEffectGroup()
                }
              }
            }
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
            if !isAddButtonVisible {
              ToolbarItem(placement: .topBarTrailing) { addNoteToolbarButton }
            }
            ToolbarItem(placement: .topBarTrailing) { aboutButton }
          }
          ToolbarItem(placement: .topBarTrailing) { editButton }
        }
        .onChange(of: appModel.canvasStates[canvasId]?.displayState) { _, newValue in
          guard newValue == .notes else { return }
          if let canvasDrawingId = appModel.canvasStates[canvasId]?.drawingId {
            proxy.scrollTo(canvasDrawingId, anchor: .center)
          }
        }
      }
    }
    .animation(.spring, value: isAddButtonVisible)
  }

  @MainActor
  @ViewBuilder
  private func noteView(id: UUID) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 20)
        .foregroundStyle(.white.opacity(0.15))
      if let thumbnail = appModel.thumbnails[id] {
        Image(uiImage: thumbnail)
          .resizable()
          .clipShape(.rect(cornerRadius: 16, style: .continuous))
          .padding(8)
      } else {
        Image(systemName: "questionmark.app.dashed")
      }
      if id == appModel.canvasStates[canvasId]?.drawingId {
        RoundedRectangle(cornerRadius: 20)
          .stroke(Color.white, lineWidth: 3)
      }
    }
    .aspectRatio(1, contentMode: .fit)
    .padding(8)
    .hoverEffect(.highlight)
    .onTapGesture {
      handleNoteTap(at: id)
    }
    .overlay(alignment: .topTrailing, content: {
      favoriteButton(id: id)
        .padding(20)
    })
    .overlay {
      deleteNoteButton(id: id)
    }
  }

  @MainActor
  @ViewBuilder
  private func favoriteButton(id: UUID) -> some View {
    Button(action: {
      appModel.favoriteDrawing(id: id)
    }, label: {
      Image(systemName: (appModel.drawings[id]?.isFavorite ?? false) ? "star.fill" : "star")
        .foregroundStyle(.white)
        .font(.footnote)
    })
    .buttonStyle(.plain)
    .buttonBorderShape(.circle)
    .hoverEffect { effect, isActive, geometry in
      effect.animation(.smooth) {
        $0.opacity(isActive ? 1 : (appModel.drawings[id]?.isFavorite ?? false) ? 1 : 0)
      }
    }
  }

  @MainActor
  @ViewBuilder
  private func deleteNoteButton(id: UUID) -> some View {
    if isEditing {
      HStack {
        Spacer()
        VStack {
          Button(action: {
            appModel.deleteDrawing(id, canvasId: canvasId)
          }, label: {
            Image(systemName: "minus")
          })
          Spacer()
        }
      }
    }
  }

  @MainActor
  @ViewBuilder
  private var addNoteButton: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 20).foregroundStyle(.white.opacity(0.15))
      VStack(spacing: 8) {
        Image(systemName: "plus")
          .font(.extraLargeTitle2)
        if !appModel.subscriptionViewModel.hasPro {
          Text("Left \(max(0, 3 - appModel.drawings.count)) drawings")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
    .aspectRatio(1, contentMode: .fit)
    .padding(8)
    .hoverEffect(.highlight)
    .onTapGesture {
      AudioServicesPlaySystemSound(1104)
      if appModel.drawings.count <= 2 || appModel.subscriptionViewModel.hasPro {
        addNewDrawing(canvasId: canvasId)
      } else {
        dismissWindow(id: WindowID.windowSubscriptionView.description)
        openWindow(id: WindowID.windowSubscriptionView.description)
      }
    }
    .onAppear {
      isAddButtonVisible = true
    }
    .onDisappear {
      isAddButtonVisible = false
    }
  }

  @MainActor
  @ViewBuilder
  private var addNoteToolbarButton: some View {
    Button(action: {
      AudioServicesPlaySystemSound(1104)
      if appModel.drawings.count <= 2 || appModel.subscriptionViewModel.hasPro {
        addNewDrawing(canvasId: canvasId)
      } else {
        dismissWindow(id: WindowID.windowSubscriptionView.description)
        openWindow(id: WindowID.windowSubscriptionView.description)
      }
    }, label: {
      Image(systemName: "plus")
    })
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
      appModel.canvasStates[canvasId]?.setDisplayState(.drawing)
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
      HStack {
        Image(systemName: "arrow.uturn.left")
        Text("Undo")
      }
    })
    .disabled(appModel.deletedDrawings.isEmpty)
  }

  @MainActor
  @ViewBuilder
  private var aboutButton: some View {
    Button(action: {
      dismissWindow(id: WindowID.windowAboutView.description)
      appModel.aboutNavigationPath.removeLast(appModel.aboutNavigationPath.count)
      openWindow(id: WindowID.windowAboutView.description)
    }, label: {
      Text("About")
    })
  }

  @MainActor
  @ViewBuilder
  private var subscriptionButton: some View {
    Button(action: {
      dismissWindow(id: WindowID.windowSubscriptionView.description)
      openWindow(id: WindowID.windowSubscriptionView.description)
    }, label: {
      Text("Get Pro")
    })
    .buttonStyle(.borderless)
  }

  @MainActor
  private func addNewDrawing(canvasId: UUID) {
    if let canvasDrawingId = appModel.canvasStates[canvasId]?.drawingId {
      appModel.updateDrawing(canvasDrawingId)
    }
    let newDrawingId = appModel.addNewDrawing(canvasId: canvasId)
    appModel.canvasStates[canvasId]?.setDisplayState(.drawing)
  }

  @MainActor
  private func handleNoteTap(at id: UUID) {
    AudioServicesPlaySystemSound(1104)
    if let canvasDrawingId = appModel.canvasStates[canvasId]?.drawingId {
      appModel.updateDrawing(canvasDrawingId)
    }
    appModel.canvasStates[canvasId]?.setDrawingId(id)
    appModel.canvasStates[canvasId]?.setDisplayState(.drawing)
  }
}

#Preview {
  NotesView(canvas: PKCanvasView(), canvasId: UUID())
    .environment(AppModel())
}
