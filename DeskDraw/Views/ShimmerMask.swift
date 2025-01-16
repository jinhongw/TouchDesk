//
//  ShimmerMask.swift
//  DeskDraw
//
//  Created by jinhong on 2025/1/16.
//
import SwiftUI

struct ShimmerMask: View {
  @State private var shimmerPosition: CGFloat = -1.0
  @State private var appeared: Bool = false

  var body: some View {
    GeometryReader { proxy in
      let viewWidth = proxy.size.width
      LinearGradient(
        gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.3), Color.clear]),
        startPoint: .leading,
        endPoint: .trailing
      )
      .frame(width: viewWidth * 0.6)
      .offset(x: shimmerPosition)
      .onAppear {
        guard !appeared else { return }
        appeared = true
        shimmerPosition = -viewWidth
        withAnimation(
          Animation.linear(duration: 2)
            .delay(1)
            .repeatForever(autoreverses: false)
        ) {
          print(#function, viewWidth)
          shimmerPosition = viewWidth
        }
      }
    }
  }
}

struct sparklesOverlay: View {
  @State private var showStars: Bool = false
  @State private var appeared: Bool = false

  var body: some View {
    GeometryReader { proxy in
      let viewWidth = proxy.size.width
      let viewHeight = proxy.size.height
      Image(systemName: "sparkles")
        .font(.callout)
        .foregroundStyle(.white)
        .rotationEffect(.degrees(12))
        .offset(x: viewWidth / 2 + 8, y: -viewHeight / 2 + 4)
        .opacity(showStars ? 1 : 0)
        .onAppear {
          guard !appeared else { return }
          appeared = true
          startAnimationLoop()
        }
    }
  }

  private func startAnimationLoop() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      print(#function, true)
      withAnimation(
        Animation.spring(duration: 1)
      ) {
        showStars = true
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
      print(#function, false)
      withAnimation(
        Animation.spring(duration: 1)
      ) {
        showStars = false
      }
      startAnimationLoop()
    }
  }
}


#Preview(body: {
  NavigationStack {
    Text("Pro")
      .font(.system(size: 20, weight: .bold, design: .rounded))
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .background(RoundedRectangle(cornerRadius: 12).foregroundStyle(.white.opacity(0.8)))
      .background(RoundedRectangle(cornerRadius: 12).foregroundStyle(LinearGradient(
        gradient: Gradient(colors: [Color.white, Color.purple, Color.orange]),
        startPoint: .leading,
        endPoint: .trailing
      )))
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
      .overlay(ShimmerMask().clipShape(RoundedRectangle(cornerRadius: 12)))
      .overlay(sparklesOverlay())
      .rotationEffect(.degrees(16))
      .offset(z: 16)
      .offset(x: 36, y: -20)
      .foregroundStyle(LinearGradient(
        gradient: Gradient(colors: [Color.orange, Color.purple]),
        startPoint: .leading,
        endPoint: .trailing
      ))
  }
  .frame(width: 240, height: 240)
})
