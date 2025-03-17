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

  @State private var settingType: SettingType? = nil
  @State private var showColorPicker = false
  @State private var showMoreFuncsMenu = false

  @Binding var toolStatus: DrawingView.CanvasToolStatus
  @Binding var pencilType: PKInkingTool.InkType
  @Binding var eraserType: DrawingView.EraserType

  let canvas: PKCanvasView

  enum SettingType {
    case pen
    case pencil
    case monoline
    case fountainPen
    case crayon
    case eraser
  }

  var body: some View {
    HStack(spacing: 8) {
      leftTools
      Spacer(minLength: 20)
      rightTools
    }
    .rotation3DEffect(.init(radians: isHorizontal ? .pi / 4 : .pi * 2 / 3), axis: (x: 1, y: 0, z: 0))
    .padding(.leading, isHorizontal ? 68 : 20)
    .padding(.trailing, 20)
    .animation(.spring, value: isHorizontal)
    .animation(.spring.speed(2), value: appModel.isLocked)
  }

  // MARK: LeftTools

  @MainActor
  @ViewBuilder
  var leftTools: some View {
    HStack(spacing: 12) {
      showNotes
      lockCanvas
      moreFuncsButton
      undo
      redo
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
  private var lockCanvas: some View {
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
  private var moreFuncsMenu: some View {
    VStack {
      exportImage
      toggleOrientation
      placeAssist
      setting
    }
    .rotation3DEffect(.degrees(isHorizontal ? -35 : -25), axis: (1, 0, 0), anchor: .center)
    .scaleEffect(showMoreFuncsMenu ? 1 : 0, anchor: .bottom)
    .opacity(showMoreFuncsMenu ? 1 : 0)
    .offset(y: -108)
    .offset(z: 64)
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
      imageTool
      colorPicker
    }
  }

  @MainActor
  @ViewBuilder
  private var imageTool: some View {
    HStack {
      Button(action: {
//        if toolStatus == .image {
//        } else {
//          toolStatus = .image
//        }
        let visibleCenter = CGPoint(
          x: canvas.contentOffset.x + canvas.bounds.width / 2,
          y: canvas.contentOffset.y + canvas.bounds.height / 2
        )
        dismissWindow(id: "imagePicker")
        openWindow(id: "imagePicker", value: visibleCenter)
      }, label: {
        Image(systemName: "photo.on.rectangle.angled.fill")
          .frame(width: 8)
      })
      .frame(width: 44, height: 44)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
//    .background(toolStatus == .image ? .white.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
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
      setType: .pen,
      iconName: "pencil.tip",
      calculateWidth: { value in
        0.88 + value * 6
      },
      pencilType: $pencilType,
      settingType: $settingType,
      penWidth: $penWidth,
      toolStatus: $toolStatus
    )
  }

  @MainActor
  @ViewBuilder
  var monolineTool: some View {
    InkToolView(
      inkType: .monoline,
      setType: .monoline,
      iconName: "pencil.and.scribble",
      calculateWidth: { value in
        0.5 + value * 0.875
      },
      pencilType: $pencilType,
      settingType: $settingType,
      penWidth: $monolineWidth,
      toolStatus: $toolStatus
    )
  }

  @MainActor
  @ViewBuilder
  var pencilTool: some View {
    InkToolView(
      inkType: .pencil,
      setType: .pencil,
      iconName: "pencil",
      calculateWidth: { value in
        max(2.41, 2.4 + value * 3.4)
      },
      pencilType: $pencilType,
      settingType: $settingType,
      penWidth: $pencilWidth,
      toolStatus: $toolStatus
    )
  }

  @MainActor
  @ViewBuilder
  var crayonTool: some View {
    InkToolView(
      inkType: .crayon,
      setType: .crayon,
      iconName: "paintbrush",
      calculateWidth: { value in
        10 + value * 10
      },
      pencilType: $pencilType,
      settingType: $settingType,
      penWidth: $crayonWidth,
      toolStatus: $toolStatus
    )
  }

  @MainActor
  @ViewBuilder
  var fountainPenTool: some View {
    InkToolView(
      inkType: .fountainPen,
      setType: .fountainPen,
      iconName: "paintbrush.pointed",
      calculateWidth: { value in
        1.5 + value * 3.125
      },
      pencilType: $pencilType,
      settingType: $settingType,
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
          if settingType != .eraser {
            settingType = .eraser
          } else {
            settingType = nil
          }
        } else {
          toolStatus = .eraser
          settingType = nil
        }
      }, label: {
        Image(systemName: "eraser")
          .frame(width: 8)
      })
      .frame(width: 44, height: 44)
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .background(toolStatus == .eraser ? .white.opacity(settingType == .eraser ? 0.6 : 0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
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
      .scaleEffect(toolStatus == .eraser && settingType == .eraser ? 0.85 : 0, anchor: .bottom)
      .opacity(toolStatus == .eraser && settingType == .eraser ? 1 : 0)
      .disabled(toolStatus != .eraser || !(settingType == .eraser))
      .rotation3DEffect(.degrees(-30), axis: (1, 0, 0), anchor: .center)
      .offset(y: -64)
      .offset(z: 40)
      .animation(.spring.speed(2), value: toolStatus)
      .animation(.spring.speed(2), value: settingType)
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
        .scaleEffect(toolStatus == .eraser && eraserType == .bitmap && settingType != .eraser ? 1 : 0, anchor: .top)
        .opacity(toolStatus == .eraser && eraserType == .bitmap && settingType != .eraser ? 1 : 0)
        Image(systemName: "xmark.app.fill")
          .frame(width: 44, height: 60)
          .padding(12)
          .font(.system(size: 6, weight: .medium))
          .scaleEffect(toolStatus == .eraser && settingType != .eraser && eraserType == .vector ? 1 : 0, anchor: .top)
          .opacity(toolStatus == .eraser && settingType != .eraser && eraserType == .vector ? 1 : 0)
      }
      .animation(.spring.speed(2), value: eraserType)
      .animation(.spring.speed(2), value: toolStatus)
      .animation(.spring.speed(2), value: settingType)
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

  @MainActor
  @ViewBuilder
  var colorPicker: some View {
    @Bindable var appModel = appModel
    HStack {
      ColorPicker("Color", selection: $drawColor)
        .disabled(true)
        .labelsHidden()
        .frame(width: 20, height: 20)
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
    .disabled(appModel.isLocked)
    .opacity(appModel.isLocked ? 0 : 1)
    .scaleEffect(appModel.isLocked ? 0 : 1, anchor: .center)
  }
}

struct InkToolView: View {
  @Environment(AppModel.self) private var appModel

  let inkType: PKInkingTool.InkType
  let setType: DrawingToolsView.SettingType
  let iconName: String
  let calculateWidth: (CGFloat) -> CGFloat

  @Binding var pencilType: PKInkingTool.InkType
  @Binding var settingType: DrawingToolsView.SettingType?
  @Binding var penWidth: Double
  @Binding var toolStatus: DrawingView.CanvasToolStatus

  @State var lastUpdateDragValue: CGFloat = 0

  var body: some View {
    HStack {
      Button(action: {
        if toolStatus == .ink, pencilType == inkType {
          if settingType != setType {
            settingType = setType
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
    .background(pencilType == inkType && toolStatus == .ink ? .white.opacity(settingType == setType ? 0.6 : 0.3) : .clear, in: RoundedRectangle(cornerRadius: 32))
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
    .scaleEffect(pencilType == inkType && toolStatus == .ink && settingType == setType ? 0.85 : 0, anchor: .bottom)
    .opacity(pencilType == inkType && toolStatus == .ink && settingType == setType ? 1 : 0)
    .disabled(pencilType == inkType && toolStatus != .ink || !(settingType == setType))
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
    .scaleEffect(pencilType == inkType && toolStatus == .ink && settingType != setType ? 1 : 0, anchor: .top)
    .opacity(pencilType == inkType && toolStatus == .ink && settingType != setType ? 1 : 0)
    .animation(.spring.speed(2), value: pencilType)
    .animation(.spring.speed(2), value: toolStatus)
    .animation(.spring.speed(2), value: settingType)
    .offset(y: 32)
  }
}

#Preview(body: {
  @Previewable @State var boradHeight: Float = 0
  @Previewable @State var toolStatus: DrawingView.CanvasToolStatus = .ink
  @Previewable @State var pencilType: PKInkingTool.InkType = .pen
  @Previewable @State var eraserType: DrawingView.EraserType = .bitmap
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
        canvas: canvas
      )
      .environment(AppModel())
      .frame(width: 1024, height: 44)
    }
  }
  .frame(width: 1024)
})

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
