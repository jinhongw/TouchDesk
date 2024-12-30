//
//  NotesView.swift
//  DeskDraw
//
//  Created by jinhong on 2024/12/27.
//

import SwiftUI

struct NotesView: View {
  @Environment(AppModel.self) var appModel

  let columns = [
    GridItem(.adaptive(minimum: 280))
  ]

  var body: some View {
    let _ = print(#function, "appModel.thumbnails.count \(appModel.thumbnails.count))")
    ScrollView {
      LazyVGrid(columns: columns, spacing: 20) {
        ForEach(appModel.thumbnails.indices, id: \.self) { index in
          Button(action: {
            print(#function, "drawingIndex \(index)")
            appModel.drawingIndex = index
            appModel.saveDataModel()
          }, label: {
            Image(uiImage: appModel.thumbnails[index].image)
              .resizable()
              .frame(width: 280, height: 280)
              .background(RoundedRectangle(cornerRadius: 12).foregroundStyle(.white))
          })
        }
      }
      .padding(20)
    }
  }
}

#Preview {
  NotesView()
    .environment(AppModel())
}
