//
//  ConfettiView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/1/15.
//

import SwiftUI

struct ConfettiView: View {
  @State var animate = false
  @State var xSpeed = Double.random(in: 0.7 ... 2)
  @State var zSpeed = Double.random(in: 1 ... 2)
  @State var anchor = CGFloat.random(in: 0 ... 1).rounded()

  var body: some View {
    Rectangle()
      .fill([Color.orange, Color.blue, Color.pink, Color.purple, Color.white, Color.secondary].randomElement() ?? Color.green)
      .frame(width: 20, height: 12)
      .onAppear(perform: { animate = true })
      .rotation3DEffect(.degrees(animate ? 360 : 0), axis: (x: 1, y: 0, z: 0))
      .animation(Animation.linear(duration: xSpeed).repeatForever(autoreverses: false), value: animate)
      .rotation3DEffect(.degrees(animate ? 360 : 0), axis: (x: 0, y: 0, z: 1), anchor: UnitPoint(x: anchor, y: anchor))
      .animation(Animation.linear(duration: zSpeed).repeatForever(autoreverses: false), value: animate)
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
    didSet {
      
    }
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
  .frame(width: 480, height: 740)
})
