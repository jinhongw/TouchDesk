//
//  SettingView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/3/3.
//

import SwiftUI

struct SettingView: View {
  @AppStorage("volumeBaseplateVisibility") private var volumeBaseplateVisibility = true
  @AppStorage("placementAssistance") private var placementAssistance = true
  @AppStorage("showMiniMap") private var showMiniMap = true
  @AppStorage("miniMapSize") private var miniMapSize: Double = 1
  @AppStorage("showZoomControlView") private var showZoomControlView = true
  @AppStorage("showQuickZoomButtons") private var showQuickZoomButtons = true
  @AppStorage("showRecentColors") private var showRecentColors = true
  @AppStorage("maxRecentColors") private var maxRecentColors: Int = 3
  @AppStorage("showQuickDrawingSwitch") private var showQuickDrawingSwitch = true
  @AppStorage("quickDrawingSwitchSize") private var quickDrawingSwitchSize: Double = 1
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

        Toggle(isOn: $placementAssistance) {
          Text("Placement assistance")
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
        }

        Toggle(isOn: $showRecentColors) {
          Text("Show Recent Colors")
        }

        if showRecentColors {
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
      }

      if showQuickDrawingSwitch || showMiniMap || showZoomControlView {
        Section {
          if showQuickDrawingSwitch {
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

          if showMiniMap {
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
        } header: {
          Text("Control Size")
        }
      }

      Section {
        Button(action: {
          volumeBaseplateVisibility = true
          placementAssistance = true
          showMiniMap = true
          miniMapSize = 1
          showZoomControlView = true
          showRecentColors = true
          maxRecentColors = 3
          showQuickDrawingSwitch = true
          quickDrawingSwitchSize = 1
        }, label: {
          Text("恢复默认设定")
        })
      }
    }
    .listStyle(.insetGrouped)
    .frame(width: 480)
    .navigationTitle("Settings")
  }
}

#Preview {
  NavigationStack {
    SettingView()
      .padding(.vertical, 36)
  }
}
