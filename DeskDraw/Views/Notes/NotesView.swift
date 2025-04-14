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
          guard newValue else { return }
          proxy.scrollTo(appModel.drawingId, anchor: .center)
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
            .clipShape(.rect(cornerRadius: 16, style: .continuous))
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
        effect.animation(.smooth) {
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
        effect.animation(.smooth) {
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
      dismissWindow(id: "about")
      appModel.aboutNavigationPath.removeLast(appModel.aboutNavigationPath.count)
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
  }
  
  @MainActor
  private func handleNoteTap(at id: UUID) {
    AudioServicesPlaySystemSound(1104)
    appModel.updateDrawing(appModel.drawingId)
    appModel.selectDrawingId(id)
    appModel.showNotes = false
    appModel.showDrawing = true
  }
}

#Preview {
  NotesView(canvas: PKCanvasView())
    .environment(AppModel())
}
