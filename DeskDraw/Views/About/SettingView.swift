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
//      header: {
//        Text("Canvas")
//      }
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


