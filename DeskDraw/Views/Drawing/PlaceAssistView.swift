//
//  PlaceAssistView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/2/11.
//

import AVFoundation
import SwiftUI

struct MovingCircle: View {
  @State private var offset: CGSize = .zero
  private var color: Color = .init(hue: Double.random(in: 0.25 ... 0.4), saturation: 0.8, brightness: 0.9)
  private var size: CGFloat
  private var blurRadius: CGFloat
  private var offsetDistance: CGFloat

  init(width: CGFloat, style: PlaceAssistLayerView.ColorStyle) {
    size = CGFloat.random(in: width / 2 ... width * 2)
    blurRadius = CGFloat.random(in: width / 3 ... width / 1.5)
    offsetDistance = width / 2
    switch style {
    case .green:
      color = Color(hue: Double.random(in: 0.25 ... 0.4), saturation: Double.random(in: 0.3 ... 1.0), brightness: Double.random(in: 0.4 ... 1.0))
    case .blue:
      color = Color(hue: Double.random(in: 0.6 ... 0.75), saturation: Double.random(in: 0.6 ... 1.0), brightness: Double.random(in: 0.7 ... 1.0))
    case .any:
      color = Color(hue: [Double.random(in: 0.0 ... 0.2), Double.random(in: 0.4 ... 0.6), Double.random(in: 0.8 ... 1)].randomElement()!, saturation: Double.random(in: 0.0 ... 1.0), brightness: Double.random(in: 0.0 ... 1.0))
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

struct PlaceAssistLayerView: View {
  var width: CGFloat
  var height: CGFloat
  var style: ColorStyle

  enum ColorStyle {
    case green
    case blue
    case any
  }

  var body: some View {
    let _ = print(#function, "PlaceAssistView Rerender \(width)")
    VStack {
      ForEach(0 ..< 5, id: \.self) { _ in
        HStack {
          ForEach(0 ..< 5, id: \.self) { _ in
            let circleWidth = CGFloat.random(in: width / 6 ... width / 3)
            MovingCircle(width: circleWidth, style: style)
              .frame(width: circleWidth)
          }
        }
      }
    }
    .opacity(1)
    .frame(width: width, height: height)
    .clipped()
  }
}

struct PlaceAssistView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.openImmersiveSpace) private var openImmersiveSpace
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismissWindow) private var dismissWindow
  @AppStorage("isHorizontal") private var isHorizontal: Bool = true
  @AppStorage("showGestureGuide") private var showGestureGuide = true

  let width: CGFloat, height: CGFloat, depth: CGFloat, placeZOffset: CGFloat

  @Binding var zRotation: Double
  @Binding var verticalZOffest: CGFloat
  @Binding var horizontalYOffest: CGFloat

  var text: AttributedString {
    var string = AttributedString(NSLocalizedString("Drag the board to any surface, \n it turns green when aligned.", comment: ""))
    if let range = string.range(of: "turns green") {
      string[range].foregroundColor = Color(red: 0.0, green: 0.8, blue: 0.0)
    } else if let range = string.range(of: "底色变绿") {
      string[range].foregroundColor = Color(red: 0.0, green: 0.8, blue: 0.0)
    } else if let range = string.range(of: "底色變綠") {
      string[range].foregroundColor = Color(red: 0.0, green: 0.8, blue: 0.0)
    } else if let range = string.range(of: "devient vert") {
      string[range].foregroundColor = Color(red: 0.0, green: 0.8, blue: 0.0)
    } else if let range = string.range(of: "wird grün") {
      string[range].foregroundColor = Color(red: 0.0, green: 0.8, blue: 0.0)
    } else if let range = string.range(of: "緑色に変わります") {
      string[range].foregroundColor = Color(red: 0.0, green: 0.8, blue: 0.0)
    } else if let range = string.range(of: "녹색으로 변합니다") {
      string[range].foregroundColor = Color(red: 0.0, green: 0.8, blue: 0.0)
    }
    return string
  }

  var body: some View {
    ZStack {
      PlaceAssistLayerView(width: width, height: height, style: .blue)
      PlaceAssistLayerView(width: width, height: height, style: .green)
        .offset(z: placeZOffset * 2)
        .opacity(appModel.isBeginingPlacement ? 0 : 0.3)
      VStack(spacing: 32) {
        Spacer(minLength: 0)
        HStack {
          Spacer(minLength: 0)
          Text(text)
            .font(.largeTitle)
            .fontDesign(.rounded)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
          Spacer(minLength: 0)
        }
        placementTools
        Spacer(minLength: 0)
      }
      .offset(z: 12)
      .offset(z: placeZOffset * 2)
      VStack {
        Spacer(minLength: 0)
        Image("Arrow_11")
          .resizable()
          .scaledToFit()
          .frame(width: 80, height: 80)
          .rotation3DEffect(.init(radians: isHorizontal ? -.pi / 12 : .pi / 12), axis: (1, 0, 0), anchor: .center)
          .offset(z: isHorizontal ? 20 : 60)
        Spacer(minLength: 0)
      }
      .scaleEffect(appModel.isBeginingPlacement ? 0 : 1)
      .offset(y: depth / 2 - 65)
      .offset(z: placeZOffset * 2)
      mainTools
    }
    .padding(12)
    .frame(width: width, height: depth )
    .clipped(antialiased: true)
    .rotation3DEffect(.degrees(90), axis: (1, 0, 0), anchor: .center)
    .offset(y: height / 2)
    .offset(z: -depth / 2)
  }
  
  @MainActor
  @ViewBuilder
  private var placementTools: some View {
    VStack {
      if isHorizontal {
        HStack(spacing: 12) {
          Image(systemName: "arrowshape.up")
            .frame(width: 20)
            .rotation3DEffect(.init(radians: -.pi / 2), axis: (1, 0, 0), anchor: .center)
            .scaleEffect(0.5)
          Slider(value: $horizontalYOffest, in: 0 ... 20, step: 1, onEditingChanged: { _ in
            AudioServicesPlaySystemSound(1104)
          })
          .backgroundStyle(.white)
          .controlSize(.small)
          Image(systemName: "arrowshape.up")
            .frame(width: 20)
            .rotation3DEffect(.init(radians: -.pi / 2), axis: (1, 0, 0), anchor: .center)
        }
        .padding(.horizontal, 200)
      } else {
        VStack(spacing: 16) {
          HStack(spacing: 12) {
            Image(systemName: "trapezoid.and.line.horizontal")
              .frame(width: 20)
              .rotation3DEffect(.init(radians: -.pi / 12), axis: (0, 1, 0), anchor: .center)
            Slider(value: $zRotation, in: -2 ... 2, step: 0.2, onEditingChanged: { _ in
              AudioServicesPlaySystemSound(1104)
            })
            .backgroundStyle(.white)
            .controlSize(.small)
            Image(systemName: "trapezoid.and.line.horizontal")
              .scaleEffect(x: -1, y: 1)
              .frame(width: 20)
              .rotation3DEffect(.init(radians: .pi / 12), axis: (0, 1, 0), anchor: .center)
          }
          .padding(.horizontal, 200)
          
          HStack(spacing: 12) {
            Image(systemName: "arrow.up.to.line.compact")
              .frame(width: 20)
              .rotation3DEffect(.init(radians: .pi / 5), axis: (1, 0, 0), anchor: .center)
            Slider(value: $verticalZOffest, in: -10 ... 10, step: 1, onEditingChanged: { _ in
              AudioServicesPlaySystemSound(1104)
            })
            .backgroundStyle(.white)
            .controlSize(.small)
            Image(systemName: "arrow.down.to.line.compact")
              .frame(width: 20)
              .rotation3DEffect(.init(radians: .pi / 5), axis: (1, 0, 0), anchor: .center)
          }
          .padding(.horizontal, 200)
        }
      }
    }
  }
  
  @MainActor
  @ViewBuilder
  private var mainTools: some View {
    HStack(spacing: 12) {
      HStack {
        Button(action: {
          isHorizontal.toggle()
          appModel.placeCanvasImmersiveViewModel.planeAnchorHandler.moveCanvas()
          appModel.placeCanvasImmersiveViewModel.planeAnchorHandler.clearPlanes(isHorizontal: isHorizontal)
        }, label: {
          HStack {
            if isHorizontal {
              Image(systemName: "square.3.layers.3d.down.left")
                .frame(width: 8)
            } else {
              Image(systemName: "square.3.layers.3d")
                .frame(width: 8)
            }
          }
          .transition(.opacity)
          .animation(.smooth, value: isHorizontal)
        })
        .padding(6)
        .frame(width: 44, height: 44)
      }
      .buttonStyle(.borderless)
      .controlSize(.small)
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      
      HStack {
        Button(action: {
          finishPlacement()
        }, label: {
          Text("Aligned with surface")
        })
        .padding(6)
        .frame(height: 44)
      }
      .buttonStyle(.borderless)
      .controlSize(.small)
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
    }
    .rotation3DEffect(.degrees(isHorizontal ? -75 : 0), axis: (1, 0, 0), anchor: .center)
    .offset(z: isHorizontal ? 200 : 50)
    .offset(y: isHorizontal ? -50 : -150)
  }

  private func finishPlacement() {
    Task {
      appModel.isClosingPlaceCanvasImmersive = true
      await dismissImmersiveSpace()
      print(#function, "dismissImmersiveSpace")
      try await Task.sleep(for: .seconds(0.01))
      appModel.isInPlaceCanvasImmersive = false
      appModel.isClosingPlaceCanvasImmersive = false
      print(#function, "isInImmersive false")
      if showGestureGuide {
        dismissWindow(id: "gestureGuide")
        openWindow(id: "gestureGuide")
        showGestureGuide = false
      }
    }
  }
}

#Preview {
  @Previewable @State var zRotation: Double = 0
  @Previewable @State var verticalZOffest: CGFloat = 0
  @Previewable @State var horizontalYOffest: CGFloat = 0
  VStack {
    GeometryReader3D { proxy in
      PlaceAssistView(width: proxy.size.width, height: proxy.size.height, depth: proxy.size.depth, placeZOffset: 2, zRotation: $zRotation, verticalZOffest: $verticalZOffest, horizontalYOffest: $horizontalYOffest)
        .environment(AppModel())
        .offset(z: 500)
    }
  }
  .frame(width: 1280, height: 680)
}
