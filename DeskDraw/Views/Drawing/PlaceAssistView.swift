//
//  PlaceAssistView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/2/11.
//

import SwiftUI

struct MovingCircle: View {
  @State private var offset: CGSize = .zero
  private var color: Color = .init(hue: Double.random(in: 0.25 ... 0.4), saturation: 0.8, brightness: 0.9)
  private var size: CGFloat
  private var blurRadius: CGFloat
  private var offsetDistance: CGFloat

  init(width: CGFloat, style: PlaceAssistView.ColorStyle) {
    size = CGFloat.random(in: width / 2 ... width * 2)
    blurRadius = CGFloat.random(in: width / 4 ... width / 2)
    offsetDistance = width / 2
    switch style {
    case .green:
      color = Color(hue: Double.random(in: 0.25 ... 0.4), saturation: Double.random(in: 0.6 ... 1.0), brightness: Double.random(in: 0.7 ... 1.0))
    case .blue:
      color = Color(hue: Double.random(in: 0.6 ... 0.75), saturation: Double.random(in: 0.6 ... 1.0), brightness: Double.random(in: 0.7 ... 1.0))
    case .any:
      color = Color(hue: [Double.random(in: 0.0 ... 0.25), Double.random(in: 0.4 ... 0.6), Double.random(in: 0.8 ... 1)].randomElement()!, saturation: Double.random(in: 0 ... 1), brightness: Double.random(in: 0 ... 1))
    }
  }

  var body: some View {
    Circle()
      .fill(color)
      .frame(width: size, height: size)
      .blur(radius: blurRadius)
      .offset(offset)
      .onAppear {
        withAnimation(
          Animation.easeInOut(duration: Double.random(in: 1 ... 3))
            .repeatForever(autoreverses: true)
        ) {
          offset = CGSize(width: CGFloat.random(in: -offsetDistance ... offsetDistance), height: CGFloat.random(in: -offsetDistance ... offsetDistance))
        }
      }
  }
}

struct PlaceAssistView: View {
  var width: CGFloat
  var style: ColorStyle

  enum ColorStyle {
    case green
    case blue
    case any
  }

  var body: some View {
    let _ = print(#function, "PlaceAssistView Rerender \(width)")
    VStack {
      ForEach(0 ..< 3, id: \.self) { _ in
        HStack {
          ForEach(0 ..< 3, id: \.self) { _ in
            MovingCircle(width: width / 3, style: style)
              .frame(width: width / 3)
          }
        }
      }
    }
    .opacity(1)
  }
}

#Preview {
  GeometryReader3D { proxy3D in
    PlaceAssistView(width: proxy3D.size.width, style: .green)
  }
  .frame(width: 1280, height: 640)
}
