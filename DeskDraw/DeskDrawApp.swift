//
//  DeskDrawApp.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/26.
//

import os
import SwiftUI

@main
struct DeskDrawApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismissWindow) private var dismissWindow

  @AppStorage("defaultOrientation") private var defaultOrientation = Orientation.horizontal
  @AppStorage("volumeBaseplateVisibility") private var volumeBaseplateVisibility = true
  @AppStorage("horizontalWindowWidth") private var horizontalWindowWidth: Double = 884
  @AppStorage("horizontalWindowHeight") private var horizontalWindowHeight: Double = 476
  @AppStorage("horizontalWindowDepth") private var horizontalWindowDepth: Double = 476
  @AppStorage("verticalWindowWidth") private var verticalWindowWidth: Double = 1280
  @AppStorage("verticalWindowHeight") private var verticalWindowHeight: Double = 720

  @State private var appModel = AppModel()
  @State private var activeWindows: [WindowID] = []
  @State private var drawingImmersiveStyle: ImmersionStyle = .mixed

  var body: some Scene {
    WindowGroup(id: WindowID.windowLaunchView.description) {
      EmptyView()
        .windowStateTracked(id: .windowLaunchView, scenePhase: scenePhase, activeWindows: $activeWindows)
    }
    .windowStyle(.plain)
    .persistentSystemOverlays(.hidden)
    .onChange(of: scenePhase) { oldValue, newValue in
      switch newValue {
      case .background:
        break
      case .inactive:
        break
      case .active:
        if activeWindows.contains(.windowLaunchView) {
          dismissWindow(id: WindowID.windowLaunchView.description)
        }
        if !activeWindows.contains(.windowHorizontalDrawingView), !activeWindows.contains(.windowVerticalDrawingView) {
          switch defaultOrientation {
          case .horizontal:
            if let lastDrawingIdString = UserDefaults.standard.value(forKey: AppModel.drawingIdKey) as? String,
               let lastDrawingId = UUID(uuidString: lastDrawingIdString)
            {
              let (canvasId, _) = appModel.createCanvas(drawingId: lastDrawingId)
              openWindow(id: WindowID.windowHorizontalDrawingView.description, value: canvasId)
            } else {
              // TODO
            }
          case .vertical:
            if let lastDrawingIdString = UserDefaults.standard.value(forKey: AppModel.drawingIdKey) as? String,
               let lastDrawingId = UUID(uuidString: lastDrawingIdString)
            {
              let (canvasId, _) = appModel.createCanvas(drawingId: lastDrawingId)
              openWindow(id: WindowID.windowVerticalDrawingView.description, value: canvasId)
            } else {
              // TODO
            }
          }
        }
      @unknown default: break
      }
    }

    WindowGroup(id: WindowID.windowHorizontalDrawingView.description, for: UUID.self) { $canvasId in
      if let canvasId,
         let displayState = appModel.canvasStates[canvasId]?.displayState
      {
        HorizontalDrawingView(canvasId: canvasId)
          .windowStateTracked(id: .windowHorizontalDrawingView, scenePhase: scenePhase, activeWindows: $activeWindows)
          .volumeBaseplateVisibility(volumeBaseplateVisibility ? (displayState != .drawing ? .hidden : .automatic) : .hidden)
          .persistentSystemOverlays(displayState == .mini ? .hidden : .visible)
          .environment(appModel)
          .task {
            await appModel.subscriptionViewModel.updatePurchasedProducts()
          }
      }
    }
    .windowStyle(.volumetric)
    .volumeWorldAlignment(.gravityAligned)
    .upperLimbVisibility(.visible)
    .defaultSize(width: horizontalWindowWidth, height: horizontalWindowHeight, depth: horizontalWindowDepth)
    .windowResizability(.contentSize)

    WindowGroup(id: WindowID.windowVerticalDrawingView.description, for: UUID.self) { $canvasId in
      if let canvasId,
         let displayState = appModel.canvasStates[canvasId]?.displayState
      {
        VerticalDrawingView(canvasId: canvasId)
          .windowStateTracked(id: .windowHorizontalDrawingView, scenePhase: scenePhase, activeWindows: $activeWindows)
          .volumeBaseplateVisibility(volumeBaseplateVisibility ? (displayState != .drawing ? .hidden : .automatic) : .hidden)
          .persistentSystemOverlays(displayState == .mini ? .hidden : .visible)
          .environment(appModel)
          .task {
            await appModel.subscriptionViewModel.updatePurchasedProducts()
          }
      }
    }
    .windowStyle(.plain)
    .defaultSize(width: verticalWindowWidth, height: verticalWindowHeight)

    WindowGroup(id: WindowID.windowAboutView.description) {
      AboutView()
        .windowStateTracked(id: .windowAboutView, scenePhase: scenePhase, activeWindows: $activeWindows)
        .environment(appModel)
    }

    .windowResizability(.contentSize)
    .defaultWindowPlacement { content, context in
      WindowPlacement(.utilityPanel, size: CGSize(width: 480, height: 760))
    }

    WindowGroup(id: WindowID.windowGestureGuideView.description) {
      NavigationStack {
        GestureGuideView()
          .windowStateTracked(id: .windowGestureGuideView, scenePhase: scenePhase, activeWindows: $activeWindows)
      }
    }
    .windowResizability(.contentSize)
    .defaultWindowPlacement { content, context in
      WindowPlacement(.utilityPanel, size: CGSize(width: 620, height: 1024))
    }

    WindowGroup(id: WindowID.windowColorPickerView.description) {
      ColorPickerView()
        .windowStateTracked(id: .windowColorPickerView, scenePhase: scenePhase, activeWindows: $activeWindows)
    }
    .windowResizability(.contentSize)
    .defaultWindowPlacement { content, context in
      WindowPlacement(.utilityPanel)
    }

    WindowGroup(id: WindowID.windowSubscriptionView.description) {
      SubscriptionView(topPadding: 48)
        .windowStateTracked(id: .windowSubscriptionView, scenePhase: scenePhase, activeWindows: $activeWindows)
        .environment(appModel.subscriptionViewModel)
    }
    .windowResizability(.contentSize)
    .defaultWindowPlacement { content, context in
      WindowPlacement(.utilityPanel, size: CGSize(width: 480, height: 760))
    }

    WindowGroup(id: WindowID.windowExportImageView.description, for: UUID.self) { $canvasId in
      ExportImageView(image: appModel.exportImage, bounds: appModel.getCurrentDrawing(for: canvasId ?? UUID())?.bounds.size ?? .init(width: 320, height: 320))
        .windowStateTracked(id: .windowExportImageView, scenePhase: scenePhase, activeWindows: $activeWindows)
        .onAppear {
          print(#function, "appModel.isShareImageViewShowing = true")
          appModel.isShareImageViewShowing = true
          // Note: This is for export, so we use the current global drawing
          guard let canvasId, let drawingId = appModel.canvasStates[canvasId]?.drawingId else { return }
          appModel.generateThumbnail(drawingId, isFullScale: true)
        }
        .onDisappear {
          print(#function, "appModel.isShareImageViewShowing = false")
          appModel.isShareImageViewShowing = false
          appModel.exportImage = nil
        }
    }
    .windowResizability(.contentSize)
//    .defaultWindowPlacement { content, context in
//      guard let drawing = appModel.getCurrentDrawing(for: canvasId ?? UUID()) else {
//        return WindowPlacement(.utilityPanel, size: CGSize(width: 480, height: 480))
//      }
//      return WindowPlacement(.utilityPanel, size: CGSize(width: 480, height: 460 + 480 * drawing.bounds.height / drawing.bounds.width))
//    }

    WindowGroup(id: WindowID.windowImagePickerView.description, for: ImagePickerDataModel.self) { $data in
      if let point = data?.point, let canvasId = data?.canvasId {
        ImagePickerView(point: point, canvasId: canvasId)
          .windowStateTracked(id: .windowImagePickerView, scenePhase: scenePhase, activeWindows: $activeWindows)
          .environment(appModel)
      }
    }
    .windowResizability(.contentSize)
    .defaultWindowPlacement { content, context in
      WindowPlacement(.utilityPanel)
    }

    WindowGroup(id: WindowID.windowCanvasInspectView.description, for: UUID.self) { $canvasId in
      CanvasInspectView(canvasId: canvasId)
        .windowStateTracked(id: .windowCanvasInspectView, scenePhase: scenePhase, activeWindows: $activeWindows)
        .environment(appModel)
    }
//    .defaultWindowPlacement { content, context in
//      guard let drawing = appModel.currentDrawing else {
//        return WindowPlacement(.utilityPanel, size: CGSize(width: 1024, height: 1024))
//      }
//      return WindowPlacement(.utilityPanel, size: CGSize(width: max(1024, drawing.bounds.width + 120), height: max(1024, drawing.bounds.height + 120)))
//    }
  }
}

struct ImagePickerDataModel: Hashable, Codable {
  let point: CGPoint
  let canvasId: UUID
}

let logger = Logger(subsystem: "jinhonn.com.DeskDraw", category: "general")

enum WindowID: String, CustomStringConvertible {
  case windowLaunchView
  case windowHorizontalDrawingView
  case windowVerticalDrawingView
  case windowAboutView
  case windowGestureGuideView
  case windowColorPickerView
  case windowSubscriptionView
  case windowExportImageView
  case windowImagePickerView
  case windowCanvasInspectView

  var description: String {
    rawValue
  }
}

extension View {
  func windowStateTracked(id: WindowID, scenePhase: ScenePhase, activeWindows: Binding<[WindowID]>) -> some View {
    onChange(of: scenePhase) { _, newPhase in
      switch newPhase {
      case .active:
        debugPrint(#function, "\(id): \(scenePhase)")
        activeWindows.wrappedValue.append(id)
      case .background:
        debugPrint(#function, "\(id): \(scenePhase)")
        if let index = activeWindows.wrappedValue.firstIndex(of: id) {
          activeWindows.wrappedValue.remove(at: index)
        }
      default:
        return
      }
    }
    .onAppear {
      debugPrint(#function, "\(id): Appeared")
      activeWindows.wrappedValue.append(id)
    }
    .onDisappear {
      debugPrint(#function, "\(id): Disappeared")
      if let index = activeWindows.wrappedValue.firstIndex(of: id) {
        activeWindows.wrappedValue.remove(at: index)
      }
    }
  }
}
