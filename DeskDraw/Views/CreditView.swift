//
//  CreditView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/1/11.
//

import SwiftUI

struct CreditView: View {
  var body: some View {
    List {
      Section {
        VStack(spacing: 12) {
          Image("HandCover")
            .resizable()
            .scaledToFit()
          VStack(spacing: 0) {
            Text("Hand Drawn Shapes by @Sajjad")
            Text("Licensed under CC BY 4.0")
            Link("Learn More", destination: URL(string: "https://www.figma.com/community/file/1018477313212753754/hand-drawn-shapes")!)
          }
        }
        .font(.caption)
      }
      Section {
        VStack(spacing: 12) {
          Image("HandDrawCover")
            .resizable()
            .scaledToFit()
          VStack(spacing: 0) {
            Text("Vector hands by @Sarah Laroche")
            Text("Licensed under CC BY 4.0")
            Link("Learn More", destination: URL(string: "https://www.figma.com/community/file/1095715911047812866/vector-hands")!)
          }
        }
        .font(.caption)
      }
    }
    .listStyle(.insetGrouped)
    .frame(width: 480)
    .navigationTitle("Credits")
  }
}

#Preview {
  CreditView()
}
