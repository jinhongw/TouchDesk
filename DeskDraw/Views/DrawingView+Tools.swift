//
//  DrawingView+Tools.swift
//  DeskDraw
//
//  Created by jinhong on 2025/1/2.
//

import PencilKit
import SwiftUI

extension DrawingView {
  @MainActor
  @ViewBuilder
  var tools: some View {
    HStack(spacing: 8) {
      leftTools
      Spacer(minLength: 20)
      if !appModel.isLocked {
        rightTools
      }
    }
    .padding(.leading, 68)
    .padding(.trailing, 20)
  }

  // MARK: LeftTools

  @MainActor
  @ViewBuilder
  var leftTools: some View {
    HStack {
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

      if !appModel.isLocked {
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
      }
    }
  }

  // MARK: RightTools

  @MainActor
  @ViewBuilder
  var rightTools: some View {
    HStack {
      penTool
      monolineTool
      eraserTool
      pencilTool
      crayonTool
      fountainPenTool
      colorPicker
    }
  }

  @MainActor
  @ViewBuilder
  var penTool: some View {
    inkTool(
      inkType: .pen,
      iconName: "pencil.tip",
      isSetting: isSettingPen,
      width: penWidth
    ) {
      isSettingPen.toggle()
    } setWidthAction:   { value in
      penWidth = 0.88 + value * 6
    } calculateWidth: { value in
      0.88 + value * 6
    }
  }

  @MainActor
  @ViewBuilder
  var monolineTool: some View {
    inkTool(
      inkType: .monoline,
      iconName: "pencil.and.scribble",
      isSetting: isSettingMonoline,
      width: monolineWidth
    ) {
      isSettingMonoline.toggle()
    } setWidthAction:  { value in
      monolineWidth = 0.5 + value * 0.875
    } calculateWidth: { value in
      0.5 + value * 0.875
    }
  }

  @MainActor
  @ViewBuilder
  var pencilTool: some View {
    inkTool(
      inkType: .pencil,
      iconName: "pencil",
      isSetting: isSettingPencil,
      width: pencilWidth
    ) {
      isSettingPencil.toggle()
    } setWidthAction:  { value in
      pencilWidth = max(2.41, 2.4 + value * 3.4)
    } calculateWidth: { value in
      max(2.41, 2.4 + value * 3.4)
    }
  }

  @MainActor
  @ViewBuilder
  var crayonTool: some View {
    inkTool(
      inkType: .crayon,
      iconName: "paintbrush",
      isSetting: isSettingCrayon,
      width: crayonWidth
    ) {
      isSettingCrayon.toggle()
    } setWidthAction: { value in
      crayonWidth = 10 + value * 10
    } calculateWidth: { value in
      10 + value * 10
    }
  }

  @MainActor
  @ViewBuilder
  var fountainPenTool: some View {
    inkTool(
      inkType: .fountainPen,
      iconName: "paintbrush.pointed",
      isSetting: isSettingFountainPen,
      width: fountainPenWidth
    ) {
      isSettingFountainPen.toggle()
    } setWidthAction:  { value in
      fountainPenWidth = 1.5 + value * 3.125
    } calculateWidth: { value in
      1.5 + value * 3.125
    }
  }
  
  
  @MainActor
  @ViewBuilder
  var eraserTool: some View {
    HStack {
      Button(action: {
        if toolStatus == .eraser {
          isSettingEraser.toggle()
        } else {
          toolStatus = .eraser
        }
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
    .overlay(content: {
      HStack {
        Spacer()
        VStack {
          Image(systemName: "gearshape.fill")
            .font(.caption)
            .scaleEffect(toolStatus == .eraser ? 1 : 0, anchor: .bottom)
            .opacity(toolStatus == .eraser ? 1 : 0)
          Spacer()
        }
      }
    })
    .overlay {
      VStack {
        Picker(selection: $eraserType) {
          Text("像素橡皮擦")
            .tag(DrawingView.EraserType.bitmap)
          Text("对象橡皮擦")
            .tag(DrawingView.EraserType.vector)
        } label: {
          Text("Eraser Type")
        }
        .pickerStyle(SegmentedPickerStyle())
        .fixedSize()
        if eraserType == .bitmap {
          HStack {
            ForEach(0 ... 4, id: \.self) { value in
              let value = CGFloat(value)
              Button(action: {
                eraserWidth = 16.4 + value * 16.0
              }, label: {
                Image(systemName: eraserWidth == 16.4 + value * 16.0 ? "circle.fill" : "circle")
                  .font(.system(size: 8 + value * 4, weight: .medium))
              })
            }
          }
        }
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.mini)
      .background(toolStatus == .eraser ? .white.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      .scaleEffect(toolStatus == .eraser && isSettingEraser ? 0.85 : 0, anchor: .bottom)
      .opacity(toolStatus == .eraser && isSettingEraser ? 1 : 0)
      .disabled(toolStatus != .eraser || !isSettingEraser)
      .rotation3DEffect(.degrees(-30), axis: (1, 0, 0), anchor: .center)
      .offset(y: -64)
      .offset(z: 40)
      .animation(.spring.speed(2), value: toolStatus)
      .animation(.spring.speed(2), value: isSettingEraser)
    }
    .disabled(appModel.isLocked)
  }

  @MainActor
  @ViewBuilder
  var colorPicker: some View {
    @Bindable var appModel = appModel
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
  
  @MainActor
  @ViewBuilder
  func inkTool(inkType: PKInkingTool.InkType, iconName: String, isSetting: Bool, width: CGFloat, changeIsSetting: @escaping @MainActor () -> Void, setWidthAction: @escaping @MainActor (CGFloat) -> Void, calculateWidth: @escaping (CGFloat) -> CGFloat) -> some View {
    HStack {
      Button(action: {
        if toolStatus == .ink, pencilType == inkType {
          changeIsSetting()
        } else {
          toolStatus = .ink
          pencilType = inkType
        }
      }, label: {
        Image(systemName: iconName)
          .frame(width: 20)
      })
    }
    .padding(8)
    .buttonStyle(.borderless)
    .controlSize(.small)
    .background(pencilType == inkType && toolStatus == .ink ? .white.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 32))
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
    .disabled(appModel.isLocked)
    .overlay(content: {
      HStack {
        Spacer()
        VStack {
          Image(systemName: "gearshape.fill")
            .font(.caption)
            .scaleEffect(pencilType == inkType && toolStatus == .ink ? 1 : 0, anchor: .bottom)
            .opacity(pencilType == inkType && toolStatus == .ink ? 1 : 0)
          Spacer()
        }
      }
    })
    .overlay {
      HStack {
        ForEach(0 ... 4, id: \.self) { value in
          let value = CGFloat(value)
          Button(action: {
            setWidthAction(value)
          }, label: {
            Image(systemName: width == calculateWidth(value) ? "circle.fill" : "circle")
              .font(.system(size: 8 + value * 4, weight: .medium))
          })
        }
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.mini)
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      .scaleEffect(pencilType == inkType && toolStatus == .ink && isSetting ? 0.85 : 0, anchor: .bottom)
      .opacity(pencilType == inkType && toolStatus == .ink && isSetting ? 1 : 0)
      .disabled(pencilType == inkType && toolStatus != .ink || !isSetting)
      .rotation3DEffect(.degrees(-30), axis: (1, 0, 0), anchor: .center)
      .offset(y: -64)
      .offset(z: 24)
      .animation(.spring.speed(2), value: pencilType)
      .animation(.spring.speed(2), value: toolStatus)
      .animation(.spring.speed(2), value: isSetting)
    }
  }
}

#Preview(body: {
  DrawingView()
    .environment(AppModel())
})
