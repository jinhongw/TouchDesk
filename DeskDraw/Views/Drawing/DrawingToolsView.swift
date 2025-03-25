//
//  DrawingToolsView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/1/2.
//

import AVFoundation
import PencilKit
import RealityKit
import SwiftUI

struct DrawingToolsView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismissWindow) private var dismissWindow
  @Environment(\.openImmersiveSpace) private var openImmersiveSpace

  @AppStorage("penWidth") private var penWidth: Double = 0.88
  @AppStorage("monolineWidth") private var monolineWidth: Double = 0.5
  @AppStorage("pencilWidth") private var pencilWidth: Double = 2.41
  @AppStorage("crayonWidth") private var crayonWidth: Double = 30
  @AppStorage("fountainPenWidth") var fountainPenWidth: Double = 4.625
  @AppStorage("eraserWidth") private var eraserWidth: Double = 16.4
  @AppStorage("isHorizontal") private var isHorizontal: Bool = true
  @AppStorage("drawColor") private var drawColor: Color = .white
  @AppStorage("showRecentColors") private var showRecentColors = true
  @AppStorage("recentColors") private var recentColorsArray: ColorArray = .init(colors: [])
  @AppStorage("maxRecentColors") private var maxRecentColors: Int = 3

  @State private var toolSettingType: ToolSettingType? = nil
  @State private var showColorPicker = false
  @State private var showMoreFuncsMenu = false

  @Binding var toolStatus: DrawingView.CanvasToolStatus
  @Binding var pencilType: PKInkingTool.InkType
  @Binding var eraserType: DrawingView.EraserType
  @Binding var isSelectorActive: Bool

  let canvas: PKCanvasView

  enum ToolSettingType {
    case pen
    case pencil
    case monoline
    case fountainPen
    case crayon
    case eraser
  }

  private func updateRecentColors(oldColor: Color, newColor: Color) {
    var colors = recentColorsArray.colors
    if !colors.contains(oldColor) {
      colors.insert(oldColor, at: 0)
    } else if let existColorIndex = colors.firstIndex(of: oldColor) {
      colors.remove(at: existColorIndex)
      colors.insert(oldColor, at: 0)
    }
    colors = colors.filter({$0 != newColor})
    colors = Array(colors.prefix(6))
    recentColorsArray = ColorArray(colors: colors)
  }

  var body: some View {
    HStack(spacing: 8) {
      leftTools
      Spacer(minLength: 20)
      rightTools
    }
    .rotation3DEffect(.init(radians: isHorizontal ? .pi / 4 : .pi * 2 / 3), axis: (x: 1, y: 0, z: 0))
    .padding(.leading, isHorizontal ? 68 : 28)
    .padding(.trailing, 28)
    .animation(.spring, value: isHorizontal)
    .animation(.spring.speed(2), value: appModel.isLocked)
  }

  // MARK: LeftTools

  @MainActor
  @ViewBuilder
  var leftTools: some View {
    HStack(spacing: 12) {
      showNotes
      addNewNote
      moreFuncsButton
      if appModel.isLocked {
        unlockCanvas
      } else {
        undo
        redo
      }
    }
  }

  @MainActor
  @ViewBuilder
  private var showNotes: some View {
    HStack {
      Button(action: {
        appModel.showNotes = true
      }, label: {
        Image(systemName: "square.grid.2x2")
          .frame(width: 8)
      })
      .frame(width: 44, height: 44)
      .disabled(appModel.isInPlaceCanvasImmersive)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
  }

  @MainActor
  @ViewBuilder
  private var addNewNote: some View {
    HStack {
      Button(action: {
        appModel.addNewDrawing()
      }, label: {
        Image(systemName: "plus")
          .frame(width: 8)
      })
      .frame(width: 44, height: 44)
      .disabled(appModel.isInPlaceCanvasImmersive)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
  }

  @MainActor
  @ViewBuilder
  private var moreFuncsButton: some View {
    HStack {
      Button(action: {
        showMoreFuncsMenu.toggle()
      }, label: {
        Image(systemName: "ellipsis")
          .frame(width: 8)
      })
      .frame(width: 44, height: 44)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .background(showMoreFuncsMenu ? .white.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
    .overlay {
      moreFuncsMenu
    }
    .animation(.spring.speed(2), value: showMoreFuncsMenu)
  }

  @MainActor
  @ViewBuilder
  private var unlockCanvas: some View {
    HStack {
      Button(action: {
        appModel.isLocked.toggle()
      }, label: {
        Image(systemName: appModel.isLocked ? "lock" : "lock.open")
          .frame(width: 8)
      })
      .frame(width: 44, height: 44)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .background(appModel.isLocked ? .white.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
  }

  @MainActor
  @ViewBuilder
  private var moreFuncsMenu: some View {
    VStack {
      setting
      exportImage
      toggleOrientation
      placeAssist
      lockCanvas
    }
    .rotation3DEffect(.degrees(isHorizontal ? -40 : -25), axis: (1, 0, 0), anchor: .center)
    .scaleEffect(showMoreFuncsMenu ? 1 : 0, anchor: .bottomFront)
    .opacity(showMoreFuncsMenu ? 1 : 0)
    .offset(y: isHorizontal ? -126 : -146)
    .offset(z: isHorizontal ? 84 : 64)
    .disabled(!showMoreFuncsMenu)
  }

  @MainActor
  @ViewBuilder
  private var placeAssist: some View {
    HStack {
      Button(action: {
        Task {
          appModel.isOpeningPlaceCanvasImmersive = true
          switch await openImmersiveSpace(id: AppModel.ImmersiveSpaceID.drawingImmersiveSpace.description) {
          case .opened:
            try await Task.sleep(for: .seconds(0.01))
            appModel.isInPlaceCanvasImmersive = true
            appModel.isBeginingPlacement = false
            appModel.isOpeningPlaceCanvasImmersive = false
            showMoreFuncsMenu = false
            appModel.placeCanvasImmersiveViewModel.planeAnchorHandler.moveCanvas()
            appModel.placeCanvasImmersiveViewModel.planeAnchorHandler.clearPlanes(isHorizontal: isHorizontal)
          case .userCancelled, .error:
            fallthrough
          @unknown default: break
          }
        }
      }, label: {
        HStack {
          Image(systemName: "circle.dotted.and.circle")
            .frame(width: 8)
          Text("重新放置画板")
        }
      })
      .disabled(appModel.isClosingPlaceCanvasImmersive)
      .padding(6)
      .fixedSize()
      .frame(height: 44)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
  }

  @MainActor
  @ViewBuilder
  private var exportImage: some View {
    HStack {
      Button(action: {
        Task {
          dismissWindow(id: "shareView")
          openWindow(id: "shareView")
        }
      }, label: {
        HStack {
          Image(systemName: "square.and.arrow.up")
            .frame(width: 8)
          Text("Export Image")
        }
      })
      .disabled(appModel.isClosingPlaceCanvasImmersive)
      .padding(6)
      .fixedSize()
      .frame(height: 44)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
  }

  @MainActor
  @ViewBuilder
  private var setting: some View {
    HStack {
      Button(action: {
        Task {
          dismissWindow(id: "about")
          openWindow(id: "about")
        }
      }, label: {
        HStack {
          Image(systemName: "info.circle")
            .frame(width: 8)
          Text("About")
        }
      })
      .disabled(appModel.isClosingPlaceCanvasImmersive)
      .padding(6)
      .fixedSize()
      .frame(height: 44)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
  }

  @MainActor
  @ViewBuilder
  private var lockCanvas: some View {
    HStack {
      Button(action: {
        appModel.isLocked.toggle()
        showMoreFuncsMenu = false
      }, label: {
        HStack {
          Image(systemName: appModel.isLocked ? "lock" : "lock.open")
            .frame(width: 8)
          Text(appModel.isLocked ? "Unlock Canvas" : "Lock Canvas")
        }
      })
      .padding(6)
      .fixedSize()
      .frame(height: 44)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .background(appModel.isLocked ? .white.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
  }

  @MainActor
  @ViewBuilder
  private var toggleOrientation: some View {
    HStack {
      Button(action: {
        isHorizontal.toggle()
      }, label: {
        HStack {
          HStack {
            if isHorizontal {
              Image(systemName: "square.3.layers.3d.down.left")
                .frame(width: 8)
            } else {
              Image(systemName: "square.3.layers.3d")
                .frame(width: 8)
            }
          }
          .transition(.opacity)
          .animation(.smooth, value: isHorizontal)
          Text(isHorizontal ? "切换垂直画板" : "切换水平画板")
        }
      })
      .padding(6)
      .fixedSize()
      .frame(height: 44)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
  }

  @MainActor
  @ViewBuilder
  private var undo: some View {
    HStack {
      Button(action: {
        canvas.undoManager?.undo()
      }, label: {
        Image(systemName: "arrow.uturn.backward")
          .frame(width: 8)
      })
      .frame(width: 44, height: 44)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
    .disabled(!(canvas.undoManager?.canUndo ?? false))
    .disabled(appModel.isLocked)
    .opacity(appModel.isLocked ? 0 : 1)
    .scaleEffect(appModel.isLocked ? 0 : 1, anchor: .center)
  }

  @MainActor
  @ViewBuilder
  private var redo: some View {
    HStack {
      Button(action: {
        canvas.undoManager?.redo()
      }, label: {
        Image(systemName: "arrow.uturn.forward")
          .frame(width: 8)
      })
      .frame(width: 44, height: 44)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
    .disabled(!(canvas.undoManager?.canRedo ?? false))
    .disabled(appModel.isLocked)
    .opacity(appModel.isLocked ? 0 : 1)
    .scaleEffect(appModel.isLocked ? 0 : 1, anchor: .center)
  }

  // MARK: RightTools

  /// ink pen 2.679940805277356 0.8781664588318914...25.659259612471967
  /// ink monoline 0.5 0.5...4.0
  /// ink pencil 2.4000000953674316 2.4000000953674316...16.0
  /// ink fountainPen 4.0 1.5...14.0
  @MainActor
  @ViewBuilder
  var rightTools: some View {
    HStack(spacing: 12) {
      penTool
      monolineTool
      eraserTool
      pencilTool
      crayonTool
      fountainPenTool
      selectTool
      imageTool
      colorPicker
    }
  }

  @MainActor
  @ViewBuilder
  private var selectTool: some View {
    HStack {
      Button(action: {
        isSelectorActive.toggle()
      }, label: {
        Image(systemName: "hand.point.up.left")
          .frame(width: 8)
      })
      .frame(width: 44, height: 44)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .background(isSelectorActive ? .white.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
    .disabled(appModel.isLocked)
    .opacity(appModel.isLocked ? 0 : 1)
    .scaleEffect(appModel.isLocked ? 0 : 1, anchor: .center)
  }

  @MainActor
  @ViewBuilder
  private var imageTool: some View {
    HStack {
      Button(action: {
        let visibleCenter = CGPoint(
          x: canvas.contentOffset.x + canvas.bounds.width / 2,
          y: canvas.contentOffset.y + canvas.bounds.height / 2
        )
        dismissWindow(id: "imagePicker")
        openWindow(id: "imagePicker", value: visibleCenter)
      }, label: {
        Image(systemName: "photo.on.rectangle.angled")
          .frame(width: 8)
      })
      .frame(width: 44, height: 44)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
    .disabled(appModel.isLocked)
    .opacity(appModel.isLocked ? 0 : 1)
    .scaleEffect(appModel.isLocked ? 0 : 1, anchor: .center)
  }

  @MainActor
  @ViewBuilder
  var penTool: some View {
    InkToolView(
      inkType: .pen,
      toolType: .pen,
      iconName: "pencil.tip",
      calculateWidth: { value in
        0.88 + value * 6
      },
      pencilType: $pencilType,
      settingType: $toolSettingType,
      penWidth: $penWidth,
      toolStatus: $toolStatus
    )
  }

  @MainActor
  @ViewBuilder
  var monolineTool: some View {
    InkToolView(
      inkType: .monoline,
      toolType: .monoline,
      iconName: "pencil.and.scribble",
      calculateWidth: { value in
        0.5 + value * 0.875
      },
      pencilType: $pencilType,
      settingType: $toolSettingType,
      penWidth: $monolineWidth,
      toolStatus: $toolStatus
    )
  }

  @MainActor
  @ViewBuilder
  var pencilTool: some View {
    InkToolView(
      inkType: .pencil,
      toolType: .pencil,
      iconName: "pencil",
      calculateWidth: { value in
        max(2.41, 2.4 + value * 3.4)
      },
      pencilType: $pencilType,
      settingType: $toolSettingType,
      penWidth: $pencilWidth,
      toolStatus: $toolStatus
    )
  }

  @MainActor
  @ViewBuilder
  var crayonTool: some View {
    InkToolView(
      inkType: .crayon,
      toolType: .crayon,
      iconName: "paintbrush",
      calculateWidth: { value in
        10 + value * 10
      },
      pencilType: $pencilType,
      settingType: $toolSettingType,
      penWidth: $crayonWidth,
      toolStatus: $toolStatus
    )
  }

  @MainActor
  @ViewBuilder
  var fountainPenTool: some View {
    InkToolView(
      inkType: .fountainPen,
      toolType: .fountainPen,
      iconName: "paintbrush.pointed",
      calculateWidth: { value in
        1.5 + value * 3.125
      },
      pencilType: $pencilType,
      settingType: $toolSettingType,
      penWidth: $fountainPenWidth,
      toolStatus: $toolStatus
    )
  }

  @State var lastUpdateDragValue: CGFloat = 0

  @MainActor
  @ViewBuilder
  var eraserTool: some View {
    HStack {
      Button(action: {
        if toolStatus == .eraser {
          if toolSettingType != .eraser {
            toolSettingType = .eraser
          } else {
            toolSettingType = nil
          }
        } else {
          toolStatus = .eraser
          toolSettingType = nil
        }
      }, label: {
        Image(systemName: "eraser")
          .frame(width: 8)
      })
      .frame(width: 44, height: 44)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .background(toolStatus == .eraser ? .white.opacity(toolSettingType == .eraser ? 0.6 : 0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
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
        } else {
          Image(systemName: "xmark.app.fill")
            .font(.system(size: 20, weight: .medium))
            .padding(4)
        }
      }
      .padding(8)
      .buttonStyle(.borderless)
      .controlSize(.mini)
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      .scaleEffect(toolStatus == .eraser && toolSettingType == .eraser ? 0.85 : 0, anchor: .bottom)
      .opacity(toolStatus == .eraser && toolSettingType == .eraser ? 1 : 0)
      .disabled(toolStatus != .eraser || !(toolSettingType == .eraser))
      .rotation3DEffect(.degrees(-30), axis: (1, 0, 0), anchor: .center)
      .offset(y: -64)
      .offset(z: 40)
      .animation(.spring.speed(2), value: toolStatus)
      .animation(.spring.speed(2), value: toolSettingType)
    }
    .overlay {
      ZStack {
        HStack(spacing: 2) {
          ForEach(0 ... 4, id: \.self) { value in
            let value = CGFloat(value)
            Image(systemName: eraserWidth == 16.4 + value * 16.0 ? "circle.fill" : "circle")
              .font(.system(size: 2 + value * 1, weight: .medium))
          }
        }
        .frame(width: 44, height: 60)
        .padding(12)
        .scaleEffect(toolStatus == .eraser && eraserType == .bitmap && toolSettingType != .eraser ? 1 : 0, anchor: .top)
        .opacity(toolStatus == .eraser && eraserType == .bitmap && toolSettingType != .eraser ? 1 : 0)
        Image(systemName: "xmark.app.fill")
          .frame(width: 44, height: 60)
          .padding(12)
          .font(.system(size: 6, weight: .medium))
          .scaleEffect(toolStatus == .eraser && toolSettingType != .eraser && eraserType == .vector ? 1 : 0, anchor: .top)
          .opacity(toolStatus == .eraser && toolSettingType != .eraser && eraserType == .vector ? 1 : 0)
      }
      .animation(.spring.speed(2), value: eraserType)
      .animation(.spring.speed(2), value: toolStatus)
      .animation(.spring.speed(2), value: toolSettingType)
      .offset(y: 32)
    }
    .simultaneousGesture(
      DragGesture()
        .onChanged { value in
          guard toolStatus == .eraser else { return }
          if value.translation.width - lastUpdateDragValue >= 32 {
            guard eraserType != .vector else { return }
            for i in 0 ... 4 {
              let i = CGFloat(i)
              if eraserWidth == 16.4 + i * 16.0 {
                if i == 4 {
                  lastUpdateDragValue = value.translation.width
                  eraserType = .vector
                  AudioServicesPlaySystemSound(1104)
                  print(#function, "+++ eraser vector")
                } else {
                  lastUpdateDragValue = value.translation.width
                  AudioServicesPlaySystemSound(1104)
                  eraserWidth = 16.4 + (i + 1) * 16.0
                  print(#function, "+++ eraserWidth \(eraserWidth) \(lastUpdateDragValue)")
                  break
                }
              }
            }
          } else if value.translation.width - lastUpdateDragValue <= -32 {
            if eraserType == .vector {
              eraserType = .bitmap
              AudioServicesPlaySystemSound(1104)
              print(#function, "--- eraser bitmap")
            } else {
              for i in 1 ... 4 {
                let i = CGFloat(i)
                if eraserWidth == 16.4 + i * 16.0 {
                  lastUpdateDragValue = value.translation.width
                  AudioServicesPlaySystemSound(1104)
                  eraserWidth = 16.4 + (i - 1) * 16.0
                  print(#function, "--- eraserWidth \(eraserWidth) \(lastUpdateDragValue)")
                  break
                }
              }
            }
          }
        }
        .onEnded { value in
          guard toolStatus == .eraser else { return }
          lastUpdateDragValue = 0
        }
    )
    .disabled(appModel.isLocked)
    .opacity(appModel.isLocked ? 0 : 1)
    .scaleEffect(appModel.isLocked ? 0 : 1, anchor: .center)
  }

  let testColors: [Color] = [.black, .white, .red]

  @MainActor
  @ViewBuilder
  var colorPicker: some View {
    @Bindable var appModel = appModel
    HStack {
      ColorPicker("Color", selection: $drawColor)
        .disabled(true)
        .labelsHidden()
        .frame(width: 20, height: 20)
        .onChange(of: drawColor) { oldColor, newColor in
          print(#function, "oldColor \(oldColor) newColor \(newColor)")
          updateRecentColors(oldColor: oldColor, newColor: newColor)
        }
    }
    .padding(12)
    .buttonStyle(.borderless)
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
    .contentShape(Circle())
    .hoverEffect(.highlight)
    .onTapGesture {
      AudioServicesPlaySystemSound(1104)
      dismissWindow(id: "colorPicker")
      openWindow(id: "colorPicker")
    }
    .overlay {
      if showRecentColors {
        RecentColorsView(
          colors: recentColorsArray.colors,
          maxColors: maxRecentColors,
          drawColor: $drawColor,
          updateRecentColors: updateRecentColors
        )
      }
    }
    .disabled(appModel.isLocked)
    .opacity(appModel.isLocked ? 0 : 1)
    .scaleEffect(appModel.isLocked ? 0 : 1, anchor: .center)
  }
}

struct InkToolView: View {
  @Environment(AppModel.self) private var appModel

  let inkType: PKInkingTool.InkType
  let toolType: DrawingToolsView.ToolSettingType
  let iconName: String
  let calculateWidth: (CGFloat) -> CGFloat

  @Binding var pencilType: PKInkingTool.InkType
  @Binding var settingType: DrawingToolsView.ToolSettingType?
  @Binding var penWidth: Double
  @Binding var toolStatus: DrawingView.CanvasToolStatus

  @State var lastUpdateDragValue: CGFloat = 0

  var body: some View {
    HStack {
      Button(action: {
        if toolStatus == .ink, pencilType == inkType {
          if settingType != toolType {
            settingType = toolType
          } else {
            settingType = nil
          }
        } else {
          toolStatus = .ink
          pencilType = inkType
          settingType = nil
        }
      }, label: {
        Image(systemName: iconName)
          .frame(width: 8)
      })
      .frame(width: 44, height: 44)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .background(pencilType == inkType && toolStatus == .ink ? .white.opacity(settingType == toolType ? 0.6 : 0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
    .help("\(inkType)")
    .overlay {
      widthSettingPicker
    }
    .overlay {
      widthPreview
    }
    .simultaneousGesture(
      DragGesture()
        .onChanged { value in
          guard pencilType == inkType, toolStatus == .ink else { return }
          if value.translation.width - lastUpdateDragValue >= 32 {
            for i in 0 ... 3 {
              let i = CGFloat(i)
              if penWidth == calculateWidth(i) {
                lastUpdateDragValue = value.translation.width
                AudioServicesPlaySystemSound(1104)
                penWidth = calculateWidth(i + 1)
                print(#function, "+++ penWidth \(penWidth) \(lastUpdateDragValue)")
                break
              }
            }
          } else if value.translation.width - lastUpdateDragValue <= -32 {
            for i in 1 ... 4 {
              let i = CGFloat(i)
              if penWidth == calculateWidth(i) {
                lastUpdateDragValue = value.translation.width
                AudioServicesPlaySystemSound(1104)
                penWidth = calculateWidth(i - 1)
                print(#function, "--- penWidth \(penWidth) \(lastUpdateDragValue)")
                break
              }
            }
          }
        }
        .onEnded { value in
          guard pencilType == inkType, toolStatus == .ink else { return }
          lastUpdateDragValue = 0
        }
    )
    .disabled(appModel.isLocked)
    .opacity(appModel.isLocked ? 0 : 1)
    .scaleEffect(appModel.isLocked ? 0 : 1, anchor: .center)
  }

  @MainActor
  @ViewBuilder
  private var widthSettingPicker: some View {
    HStack {
      ForEach(0 ... 4, id: \.self) { value in
        let value = CGFloat(value)
        Button(action: {
          penWidth = calculateWidth(value)
        }, label: {
          Image(systemName: penWidth == calculateWidth(value) ? "circle.fill" : "circle")
            .font(.system(size: 8 + value * 4, weight: .medium))
        })
      }
    }
    .padding(12)
    .buttonStyle(.borderless)
    .controlSize(.mini)
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
    .scaleEffect(pencilType == inkType && toolStatus == .ink && settingType == toolType ? 0.85 : 0, anchor: .bottom)
    .opacity(pencilType == inkType && toolStatus == .ink && settingType == toolType ? 1 : 0)
    .disabled(pencilType == inkType && toolStatus != .ink || !(settingType == toolType))
    .rotation3DEffect(.degrees(-30), axis: (1, 0, 0), anchor: .center)
    .offset(y: -64)
    .offset(z: 24)
    .animation(.spring.speed(2), value: pencilType)
    .animation(.spring.speed(2), value: toolStatus)
    .animation(.spring.speed(2), value: settingType)
  }

  @MainActor
  @ViewBuilder
  private var widthPreview: some View {
    HStack(spacing: 2) {
      ForEach(0 ... 4, id: \.self) { value in
        let value = CGFloat(value)
        Image(systemName: penWidth == calculateWidth(value) ? "circle.fill" : "circle")
          .font(.system(size: 2 + value * 1, weight: .medium))
      }
    }
    .frame(width: 44, height: 60)
    .padding(12)
    .scaleEffect(pencilType == inkType && toolStatus == .ink && settingType != toolType ? 1 : 0, anchor: .top)
    .opacity(pencilType == inkType && toolStatus == .ink && settingType != toolType ? 1 : 0)
    .animation(.spring.speed(2), value: pencilType)
    .animation(.spring.speed(2), value: toolStatus)
    .animation(.spring.speed(2), value: settingType)
    .offset(y: 32)
  }
}

class ImagePickerCoordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  let canvas: PKCanvasView
  let appModel: AppModel

  init(canvas: PKCanvasView, appModel: AppModel) {
    self.canvas = canvas
    self.appModel = appModel
  }

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
    picker.dismiss(animated: true)

    guard let image = info[.originalImage] as? UIImage,
          let imageData = image.jpegData(compressionQuality: 0.8) else { return }

    // 获取当前画布的可见区域中心点
    let visibleCenter = CGPoint(
      x: canvas.contentOffset.x + canvas.bounds.width / 2,
      y: canvas.contentOffset.y + canvas.bounds.height / 2
    )

    // 添加图片到画布
    appModel.addImage(imageData, at: visibleCenter, size: CGSize(width: 320, height: 320))
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
  }
}

struct ColorArray: RawRepresentable {
  var colors: [Color]

  init(colors: [Color] = []) {
    self.colors = colors
  }

  init?(rawValue: String) {
    guard let data = rawValue.data(using: .utf8),
          let colorStrings = try? JSONDecoder().decode([String].self, from: data),
          let colors = colorStrings.map({ Color(rawValue: $0) }) as? [Color]
    else {
      return nil
    }
    self.colors = colors
  }

  var rawValue: String {
    let colorStrings = colors.map { $0.rawValue }
    guard let data = try? JSONEncoder().encode(colorStrings),
          let string = String(data: data, encoding: .utf8)
    else {
      return "[]"
    }
    return string
  }
}

struct RecentColorsView: View {
  let colors: [Color]
  let maxColors: Int
  @Binding var drawColor: Color
  let updateRecentColors: (Color, Color) -> Void
  
  var body: some View {
    ZStack(spacing: 0) {
      ForEach(Array(colors.prefix(maxColors).enumerated()), id: \.offset) { index, color in
        RecentColorButton(
          index: index,
          count: colors.prefix(maxColors).count,
          color: color,
          drawColor: $drawColor,
          updateRecentColors: updateRecentColors
        )
        .id(color)
      }
    }
    .frame(width: 200, height: 200)
    .animation(.easeOut, value: colors)
    .animation(.easeOut, value: drawColor)
    .offset(z: 12)
  }
}

struct RecentColorButton: View {
  let index: Int
  let count: Int
  let color: Color
  @Binding var drawColor: Color
  let updateRecentColors: (Color, Color) -> Void
  
  var offset: CGFloat {
    switch (index, count) {
    case (_, 1): return 0.0
    case (_, 2): return 0.5
    case (3, 4): return -1
    case let (i, 5) where i > 2: return -0.5
    case let (i, c) where c > 3 && i > 2: return -0.0
    default: return 1.0
    }
  }
  
  var body: some View {
    let angle = .pi * CGFloat(CGFloat(index) - offset) / 4.0
    let radius: CGFloat = 44
    
    Button(action: {
      print(#function, "index \(index) color \(color)")
      updateRecentColors(drawColor, color)
      drawColor = color
    }, label: {
      Circle()
        .frame(width: 16, height: 16)
        .foregroundColor(color)
    })
    .buttonStyle(.plain)
    .offset(
      x: radius * sin(angle),
      y: -radius * cos(angle)
    )
  }
}

#Preview(body: {
  @Previewable @State var boradHeight: Float = 0
  @Previewable @State var toolStatus: DrawingView.CanvasToolStatus = .ink
  @Previewable @State var pencilType: PKInkingTool.InkType = .pen
  @Previewable @State var eraserType: DrawingView.EraserType = .bitmap
  @Previewable @State var isSelectorActive: Bool = false
  let canvas = PKCanvasView()

  RealityView { content, attachments in
    if let toolbarView = attachments.entity(for: "toolbarView") {
      toolbarView.position = .init(x: 0, y: 0, z: 0)
      content.add(toolbarView)
    }
  } attachments: {
    Attachment(id: "toolbarView") {
      DrawingToolsView(
        toolStatus: $toolStatus,
        pencilType: $pencilType,
        eraserType: $eraserType,
        isSelectorActive: $isSelectorActive,
        canvas: canvas
      )
      .environment(AppModel())
      .frame(width: 1024, height: 44)
    }
  }
  .frame(width: 1024)
})
