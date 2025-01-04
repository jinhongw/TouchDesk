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
      .disabled(appModel.isLocked)

      HStack {
        Button(action: {
          appModel.isLocked.toggle()
        }, label: {
          Image(systemName: appModel.isLocked ? "lock" : "lock.open")
            .frame(width: 20)
        })
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .background(appModel.isLocked ? .white.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 32))
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))

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
      .disabled(appModel.isLocked)
      
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
      .disabled(appModel.isLocked)

      Spacer(minLength: 20)

      HStack {
        Button(action: {
          toolStatus = .ink
          pencilType = .pen
        }, label: {
          Image(systemName: "pencil.tip")
            .frame(width: 20)
        })
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .background(pencilType == .pen && toolStatus == .ink ? .white.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 32))
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      .disabled(appModel.isLocked)

      HStack {
        Button(action: {
          toolStatus = .ink
          pencilType = .monoline
        }, label: {
          Image(systemName: "pencil.and.scribble")
            .frame(width: 20)
        })
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .background(pencilType == .monoline && toolStatus == .ink ? .white.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 32))
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      .disabled(appModel.isLocked)

      HStack {
        Button(action: {
          toolStatus = .eraser
        }, label: {
          Image(systemName: "eraser")
            .frame(width: 20)
        })
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .background(toolStatus == .eraser ? .white.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      .disabled(appModel.isLocked)

//      HStack {
//        Button(action: {
//          // lasso
//          toolStatus = .lasso
//        }, label: {
//          Image(systemName: "lasso")
//            .frame(width: 20)
//        })
//      }
//      .padding(8)
//      .buttonStyle(.borderless)
//      .controlSize(.small)
//      .background(toolStatus == .lasso ? .white.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
//      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
//      .disabled(appModel.isLocked)

      HStack {
        Button(action: {
          toolStatus = .ink
          pencilType = .pencil
        }, label: {
          Image(systemName: "pencil")
            .frame(width: 20)
        })
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .background(pencilType == .pencil && toolStatus == .ink ? .white.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 32))
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      .disabled(appModel.isLocked)

      HStack {
        Button(action: {
          toolStatus = .ink
          pencilType = .crayon
        }, label: {
          Image(systemName: "paintbrush")
            .frame(width: 20)
        })
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .background(pencilType == .crayon && toolStatus == .ink ? .white.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 32))
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      .disabled(appModel.isLocked)

      HStack {
        Button(action: {
          toolStatus = .ink
          pencilType = .fountainPen
        }, label: {
          Image(systemName: "paintbrush.pointed")
            .frame(width: 20)
        })
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .background(pencilType == .fountainPen && toolStatus == .ink ? .white.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 32))
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      .disabled(appModel.isLocked)

//      HStack {
//        Button(action: {
//
//        }, label: {
//          Image(systemName: "pencil.tip.crop.circle.badge.plus")
//            .frame(width: 20)
//        })
//      }
//      .padding(8)
//      .buttonStyle(.borderless)
//      .controlSize(.small)
      ////      .background(isDrawing == false ? .white.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
//      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
//      .disabled(appModel.isLocked)

      HStack {
        ColorPicker("Color", selection: $appModel.color)
          .disabled(true)
          .labelsHidden()
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.small)
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      .onTapGesture {
        dismissWindow(id: "colorPicker")
        openWindow(id: "colorPicker")
      }
      .disabled(appModel.isLocked)
    }
    .padding(.leading, 68)
    .padding(.trailing, 20)
  }
}
