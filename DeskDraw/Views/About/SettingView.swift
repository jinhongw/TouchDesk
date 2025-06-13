//
//  SettingView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/3/3.
//

import SwiftUI

enum Orientation: Int {
  case horizontal = 0
  case vertical = 1
}

struct SettingView: View {
  @AppStorage("volumeBaseplateVisibility") private var volumeBaseplateVisibility = true
  @AppStorage("defaultOrientation") private var defaultOrientation = Orientation.horizontal
  
  @AppStorage("showMiniMap") private var showMiniMap = true
  @AppStorage("miniMapSize") private var miniMapSize: Double = 1
  @AppStorage("miniMapSizeInVertical") private var miniMapSizeInVertical: Double = 1.5
  
  @AppStorage("showZoomControlView") private var showZoomControlView = true
  @AppStorage("showQuickZoomButtons") private var showQuickZoomButtons = true
  @AppStorage("showRecentColors") private var showRecentColors = true
  @AppStorage("maxRecentColors") private var maxRecentColors: Int = 3
  
  @AppStorage("showQuickDrawingSwitch") private var showQuickDrawingSwitch = true
  @AppStorage("quickDrawingSwitchSize") private var quickDrawingSwitchSize: Double = 1
  @AppStorage("quickDrawingSwitchSizeInVertical") private var quickDrawingSwitchSizeInVertical: Double = 1.5
  
  @AppStorage("canvasToolSize") private var canvasToolSize: Double = 1
  @AppStorage("canvasToolSizeInVertical") private var canvasToolSizeInVertical: Double = 1.5
  
  @AppStorage("commonZoomFactors") private var commonZoomFactors: DoubleArrayStorageModel = .init(array: [100, 150, 200])

  private let quickZoomValues: [Double] = [25, 50, 100, 150, 175, 200, 250, 300, 350, 400]
  
  var body: some View {
    List {
      Section {
        NavigationLink(value: AppModel.AboutRoute.gestureGuide) {
          Text("Dominant hand setting")
        }
      }

      Section {
        Toggle(isOn: $volumeBaseplateVisibility) {
          Text("Show base plate")
        }
        VStack(alignment: .leading) {
          Text("Default Orientation")
          Picker("Default Orientation", selection: $defaultOrientation) {
            Text("Horizontal")
              .tag(Orientation.horizontal)
            Text("Vertical")
              .tag(Orientation.vertical)
          }
          .pickerStyle(PalettePickerStyle())
        }
      }

      Section {
        Toggle(isOn: $showQuickDrawingSwitch) {
          Text("Show Quick Draw Switch")
        }

        Toggle(isOn: $showMiniMap) {
          Text("Show mini map")
        }

        Toggle(isOn: $showZoomControlView) {
          Text("Show Zoom Control")
        }

        if showZoomControlView {
          Toggle(isOn: $showQuickZoomButtons) {
            Text("Show Quick Zoom Buttons")
          }

          if showQuickZoomButtons {
            quickZoomButtonsSetting
          }
        }

        Toggle(isOn: $showRecentColors) {
          Text("Show Recent Colors")
        }

        if showRecentColors {
          recentColorsSetting
        }
      }

      Section {
        canvasToolSizeSetting
        if showQuickDrawingSwitch {
          quickDrawingSwitchSizeSetting
        }

        if showMiniMap {
          miniMapSizeSetting
        }
      } header: {
        Text("Control Size")
      }
      
      Section {
        canvasToolSizeInVerticalSetting
        if showQuickDrawingSwitch {
          quickDrawingSwitchSizeInVerticalSetting
        }

        if showMiniMap {
          miniMapSizeInVerticalSetting
        }
      } header: {
        Text("Control Size - Vertical")
      }

      Section {
        resetButton
      }
    }
    .listStyle(.insetGrouped)
    .frame(width: 480)
    .navigationTitle("Settings")
  }
  
  @MainActor
  @ViewBuilder
  private var quickZoomButtonsSetting: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Quick Zoom Values")
      HStack(spacing: 8) {
        ForEach(commonZoomFactors.array.indices, id: \.self) { index in
          Picker("", selection: Binding(
            get: {
              commonZoomFactors.array[index]
            },
            set: { commonZoomFactors.array[index] = $0 }
          )) {
            ForEach(quickZoomValues, id: \.self) { value in
              Text("× \((value / 100).trimmedString())")
            }
          }
          .pickerStyle(MenuPickerStyle())
          .labelsHidden()
          if index != commonZoomFactors.array.count - 1 {
            Spacer(minLength: 0)
          }
        }
      }
    }
  }
  
  @MainActor
  @ViewBuilder
  private var recentColorsSetting: some View {
    HStack(spacing: 20) {
      Text("Maximum recent colors")
        .frame(minWidth: 160, alignment: .leading)

      HStack(spacing: 8) {
        Text("○ \(maxRecentColors)")
          .fixedSize()
        Slider(
          value: .init(
            get: { Double(maxRecentColors) },
            set: { maxRecentColors = Int($0) }
          ),
          in: 1 ... 6,
          step: 1
        )
      }
    }
  }
  
  @MainActor
  @ViewBuilder
  private var quickDrawingSwitchSizeSetting: some View {
    HStack(spacing: 20) {
      Text("Quick Draw Switch")
        .frame(width: 160, alignment: .leading)
        .multilineTextAlignment(.leading)
      HStack(spacing: 8) {
        Text("× \(quickDrawingSwitchSize.trimmedString())")
          .fixedSize()
        Slider(
          value: .init(
            get: { Double(quickDrawingSwitchSize) },
            set: { quickDrawingSwitchSize = Double($0) }
          ),
          in: 0.5 ... 3,
          step: 0.1
        )
      }
    }
  }
  
  @MainActor
  @ViewBuilder
  private var miniMapSizeSetting: some View {
    HStack(spacing: 20) {
      Text("Mini Map and Zoom Control")
        .frame(width: 160, alignment: .leading)
        .multilineTextAlignment(.leading)
      HStack(spacing: 8) {
        Text("× \(miniMapSize.trimmedString())")
          .fixedSize()
        Slider(
          value: .init(
            get: { Double(miniMapSize) },
            set: { miniMapSize = Double($0) }
          ),
          in: 0.5 ... 3,
          step: 0.1
        )
      }
    }
  }
  
  @MainActor
  @ViewBuilder
  private var quickDrawingSwitchSizeInVerticalSetting: some View {
    HStack(spacing: 20) {
      Text("Quick Draw Switch")
        .frame(width: 160, alignment: .leading)
        .multilineTextAlignment(.leading)
      HStack(spacing: 8) {
        Text("× \(quickDrawingSwitchSizeInVertical.trimmedString())")
          .fixedSize()
        Slider(
          value: .init(
            get: { Double(quickDrawingSwitchSizeInVertical) },
            set: { quickDrawingSwitchSizeInVertical = Double($0) }
          ),
          in: 0.5 ... 3,
          step: 0.1
        )
      }
    }
  }
  
  @MainActor
  @ViewBuilder
  private var miniMapSizeInVerticalSetting: some View {
    HStack(spacing: 20) {
      Text("Mini Map and Zoom Control")
        .frame(width: 160, alignment: .leading)
        .multilineTextAlignment(.leading)
      HStack(spacing: 8) {
        Text("× \(miniMapSizeInVertical.trimmedString())")
          .fixedSize()
        Slider(
          value: .init(
            get: { Double(miniMapSizeInVertical) },
            set: { miniMapSizeInVertical = Double($0) }
          ),
          in: 0.5 ... 3,
          step: 0.1
        )
      }
    }
  }
  
  @MainActor
  @ViewBuilder
  private var canvasToolSizeSetting: some View {
    HStack(spacing: 20) {
      Text("Canvas Tools")
        .frame(width: 160, alignment: .leading)
        .multilineTextAlignment(.leading)
      HStack(spacing: 8) {
        Text("× \(canvasToolSize.trimmedString())")
          .fixedSize()
        Slider(
          value: .init(
            get: { Double(canvasToolSize) },
            set: { canvasToolSize = Double($0) }
          ),
          in: 0.5 ... 3,
          step: 0.1
        )
      }
    }
  }
  
  @MainActor
  @ViewBuilder
  private var canvasToolSizeInVerticalSetting: some View {
    HStack(spacing: 20) {
      Text("Canvas Tools")
        .frame(width: 160, alignment: .leading)
        .multilineTextAlignment(.leading)
      HStack(spacing: 8) {
        Text("× \(canvasToolSizeInVertical.trimmedString())")
          .fixedSize()
        Slider(
          value: .init(
            get: { Double(canvasToolSizeInVertical) },
            set: { canvasToolSizeInVertical = Double($0) }
          ),
          in: 0.5 ... 3,
          step: 0.1
        )
      }
    }
  }
  
  @MainActor
  @ViewBuilder
  private var resetButton: some View {
    Button(action: {
      volumeBaseplateVisibility = true
      showMiniMap = true
      miniMapSize = 1
      miniMapSizeInVertical = 1.5
      showZoomControlView = true
      showRecentColors = true
      maxRecentColors = 3
      showQuickDrawingSwitch = true
      showQuickZoomButtons = true
      quickDrawingSwitchSize = 1
      quickDrawingSwitchSizeInVertical = 1.5
      canvasToolSize = 1
      canvasToolSizeInVertical = 1.5
    }, label: {
      Text("恢复默认设定")
    })
  }
}

#Preview {
  NavigationStack {
    SettingView()
      .padding(.vertical, 36)
  }
}
