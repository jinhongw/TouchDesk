//
//  GestureGuideView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/3/4.
//

import SwiftUI

struct GestureGuideView: View {
  var body: some View {
    HStack(spacing: 64) {
      VStack(spacing: 0) {
        Image("Gesture-Left")
          .resizable()
          .scaledToFit()
        Text("Move canvas with left index finger")
          .font(.headline)
          .foregroundStyle(.primary)
          .multilineTextAlignment(.center)
      }
      VStack(spacing: 0) {
        Image("Gesture-Right")
          .resizable()
          .scaledToFit()
        Text("Draw with right index finger")
          .font(.headline)
          .foregroundStyle(.primary)
          .multilineTextAlignment(.center)
      }
    }
    .padding(60)
    .navigationTitle("How to Use")
  }
}

#Preview {
  NavigationStack {
    GestureGuideView()
  }
}
