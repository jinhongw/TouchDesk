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
  @AppStorage("showRecentColors") private var showRecentColors = true
  @AppStorage("maxRecentColors") private var maxRecentColors: Int = 3
  var body: some View {
    List {
      Section {
        Toggle(isOn: $volumeBaseplateVisibility) {
          Text("Show base plate")
        }
        Toggle(isOn: $showMiniMap) {
          Text("Show mini map")
        }
        Toggle(isOn: $placementAssistance) {
          Text("Placement assistance")
        }
      }

      Section {
        Toggle(isOn: $showRecentColors) {
          Text("Show Recent Colors")
        }
        if showRecentColors {
          VStack(alignment: .leading) {
            Text("Maximum recent colors")
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
