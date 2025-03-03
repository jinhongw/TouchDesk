//
//  DrawingTips.swift
//  DeskDraw
//
//  Created by jinhong on 2025/3/2.
//

import SwiftUI
import TipKit

struct WelcomeTip: Tip {
  @Parameter
  static var alreadyDiscovered: Bool = false

  var title: Text {
    Text("欢迎使用 Little Sunshine")
  }

  var message: Text? {
    Text("仔细观察太阳、地球和人物的位置，你一定能明白其中的奥秘。")
      .foregroundStyle(.white)
  }

  var image: Image? {
    Image(systemName: "quote.bubble")
  }

  var rules: [Rule] {
    [
      #Rule(Self.$alreadyDiscovered) { $0 == false },
    ]
  }
}
