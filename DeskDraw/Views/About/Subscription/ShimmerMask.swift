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
      .frame(width: viewWidth * 0.5)
      .offset(x: shimmerPosition)
      .onAppear {
        guard !appeared else { return }
        appeared = true
        shimmerPosition = -viewWidth
        withAnimation(
          Animation.linear(duration: 1.5)
            .delay(5)
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
  @State private var timer: Timer? = nil

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
          setupAnimationTimer()
        }
        .onDisappear {
          appeared = false
          timer?.invalidate()
          timer = nil
        }
    }
  }

  private func setupAnimationTimer() {
    // 延迟0.5秒开始整个动画
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      guard appeared else { return }
      // 创建一个每7秒重复的定时器
      timer = Timer.scheduledTimer(withTimeInterval: 6.5, repeats: true) { _ in
        animateSparkle()
      }
      // 立即执行第一次动画
      animateSparkle()
    }
  }
  
  private func animateSparkle() {
    // 显示星星
    withAnimation(Animation.spring(duration: 1)) {
      showStars = true
    }
    
    // 1秒后隐藏星星
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      guard appeared else { return }
      withAnimation(Animation.spring(duration: 1)) {
        showStars = false
      }
    }
  }
}


#Preview(body: {
  NavigationStack {
    Text("Pro")
      .font(.system(size: 20, weight: .bold, design: .rounded))
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
      .overlay(ShimmerMask().clipShape(RoundedRectangle(cornerRadius: 12)))
      .overlay(sparklesOverlay())
      .rotationEffect(.degrees(16))
      .offset(z: 16)
      .offset(x: 36, y: -20)
  }
  .frame(width: 240, height: 240)
})
