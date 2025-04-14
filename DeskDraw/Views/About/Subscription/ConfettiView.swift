//
//  ConfettiView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/1/15.
//

import SwiftUI

private enum ConfettiShape {
  case circle
  case triangle
  case rectangle

  static var random: ConfettiShape {
    let shapes: [ConfettiShape] = [.circle, .triangle, .rectangle]
    return shapes.randomElement() ?? .circle
  }
}

struct ConfettiView: View {
  @State private var animate = false
  @State private var xSpeed = Double.random(in: 0.7 ... 2)
  @State private var zSpeed = Double.random(in: 1 ... 2)
  @State private var anchor = CGFloat.random(in: 0 ... 1).rounded()
  @State private var color: Color = [Color.orange, Color.blue, Color.pink, Color.purple, Color.white, Color.indigo, Color.yellow].randomElement() ?? Color.green
  @State private var shape = ConfettiShape.random

  var body: some View {
    confettiShape
      .onAppear(perform: { animate = true })
      .rotation3DEffect(.degrees(animate ? 360 : 0), axis: (x: 1, y: 0, z: 0))
      .animation(Animation.linear(duration: xSpeed).repeatForever(autoreverses: false), value: animate)
      .rotation3DEffect(.degrees(animate ? 360 : 0), axis: (x: 0, y: 0, z: 1), anchor: UnitPoint(x: anchor, y: anchor))
      .animation(Animation.linear(duration: zSpeed).repeatForever(autoreverses: false), value: animate)
  }

  @MainActor
  @ViewBuilder
  private var confettiShape: some View {
    switch shape {
    case .circle:
      Circle()
        .fill(color)
        .frame(width: 18, height: 18)
    case .triangle:
      Triangle()
        .fill(color)
        .frame(width: 24, height: 24)
    case .rectangle:
      RoundedRectangle(cornerRadius: 4)
        .fill(color)
        .frame(width: 20, height: 12)
    }
  }
}

public struct Triangle: Shape {
  var radius: CGFloat = 4
  public func path(in rect: CGRect) -> Path {
    Path { path in
      let point1 = CGPoint(x: rect.midX, y: rect.minY)  // 顶部
      let point2 = CGPoint(x: rect.maxX, y: rect.maxY)  // 右下
      let point3 = CGPoint(x: rect.minX, y: rect.maxY)  // 左下
      
      // 从point1和point2的中点开始
      let midPoint = CGPoint(
        x: 0.5 * (point1.x + point2.x),
        y: 0.5 * (point1.y + point2.y)
      )
      
      path.move(to: midPoint)
      
      // 添加三个圆角
      path.addArc(
        tangent1End: point2,
        tangent2End: point3,
        radius: radius
      )
      
      path.addArc(
        tangent1End: point3,
        tangent2End: point1,
        radius: radius
      )
      
      path.addArc(
        tangent1End: point1,
        tangent2End: point2,
        radius: radius
      )
      
      // 闭合路径
      path.addLine(to: midPoint)
    }
  }
}

struct ConfettiContainerView: View {
  var count: Int = 100
  @State var yPosition: CGFloat = 0
  
  var body: some View {
    GeometryReader3D { proxy3D in
      ZStack {
        ForEach(0 ..< count, id: \.self) { _ in
          ConfettiView()
            .position(
              x: CGFloat.random(in: 0 ... proxy3D.size.width),
              y: yPosition != 0 ? CGFloat.random(in: 0 ... proxy3D.size.height) : yPosition
            )
            .offset(z: CGFloat.random(in: 0 ... 200))
        }
      }
      .ignoresSafeArea()
      .frame(width: proxy3D.size.width, height: proxy3D.size.height)
      .onAppear {
        yPosition = CGFloat.random(in: 0 ... 740)
      }
    }
  }
}

struct DisplayConfettiModifier: ViewModifier {
  @Binding var isActive: Bool {
    didSet {}
  }

  private let animationTime = 2.0
  private let fadeTime = 1.0

  func body(content: Content) -> some View {
    content
      .overlay(isActive ? ConfettiContainerView().opacity(isActive ? 1 : 0) : nil)
      .onChange(of: isActive) { oldValue, newValue in
        guard newValue else { return }
        print(#function, oldValue, newValue)
        Task {
          await handleAnimationSequence()
        }
      }
  }

  private func handleAnimationSequence() async {
    do {
      try await Task.sleep(nanoseconds: UInt64(animationTime * 1_000_000_000))
      withAnimation(.easeOut(duration: fadeTime)) {
        print(#function, isActive)
        isActive = false
      }
    } catch {}
  }
}

extension View {
  func displayConfetti(isActive: Binding<Bool>) -> some View {
    modifier(DisplayConfettiModifier(isActive: isActive))
  }
}

private struct CelebrationView: View {
  @State private var showConfetti = false

  var body: some View {
    VStack {
      Button("Celebrate") {
        showConfetti = true
      }
    }
    .frame(width: 480, height: 740)
    .displayConfetti(isActive: $showConfetti)
  }
}

#Preview(body: {
  NavigationStack {
    CelebrationView()
  }
  Triangle(radius: 20)
    .frame(width: 100, height: 100)
})
