//
//  DrawingView+Tools.swift
//  DeskDraw
//
//  Created by jinhong on 2025/1/2.
//

import SwiftUI
extension DrawingView {
  @MainActor
  @ViewBuilder
  var tools: some View {
    @Bindable var appModel = appModel
    HStack(spacing: 8) {
      HStack {
        Button(action: {
          appModel.showNotes = true
        }, label: {
          Image(systemName: "square.grid.2x2")
            .frame(width: 20)
        })
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      
//      HStack {
//        Button(action: {
//          appModel.hideInMini.toggle()
//        }, label: {
//          Image(systemName: "arrow.down.right.and.arrow.up.left")
//            .frame(width: 20)
//        })
//      }
//      .padding(8)
//      .buttonStyle(.borderless)
//      .controlSize(.small)
//      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      
      if canvas.undoManager?.canUndo ?? false {
        HStack {
          Button(action: {
            canvas.undoManager?.undo()
          }, label: {
            Image(systemName: "arrow.uturn.backward")
              .frame(width: 20)
          })
        }
        .padding(8)
        .buttonStyle(.borderless)
        .controlSize(.small)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
        .disabled(!(canvas.undoManager?.canUndo ?? false))
      }
      
      if canvas.undoManager?.canRedo ?? false {
        HStack {
          Button(action: {
            canvas.undoManager?.redo()
          }, label: {
            Image(systemName: "arrow.uturn.forward")
              .frame(width: 20)
          })
        }
        .padding(8)
        .buttonStyle(.borderless)
        .controlSize(.small)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
        .disabled(!(canvas.undoManager?.canRedo ?? false))
      }
      
      Spacer(minLength: 20)
      
      HStack {
        Button(action: {
          isDrawing = true
          pencilType = .pen
        }, label: {
          Image(systemName: "pencil.tip")
            .frame(width: 20)
        })
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .background(pencilType == .pen && isDrawing == true ? .white.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 32))
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      
      HStack {
        Button(action: {
          isDrawing = true
          pencilType = .marker
        }, label: {
          Image(systemName: "paintbrush.pointed")
            .frame(width: 20)
        })
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .background(pencilType == .marker && isDrawing == true ? .white.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 32))
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      
      HStack {
        Button(action: {
          isDrawing = false
        }, label: {
          Image(systemName: "eraser")
            .frame(width: 20)
        })
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .background(isDrawing == false ? .white.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      
      HStack {
        ColorPicker("", selection: $appModel.color)
          .disabled(true)
          .labelsHidden()
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .background(isDrawing == false ? .white.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      .onTapGesture {
        openWindow(id: "colorPicker")
      }
    }
    .padding(.leading, 60)
    .padding(.trailing, 20)
  }
}
