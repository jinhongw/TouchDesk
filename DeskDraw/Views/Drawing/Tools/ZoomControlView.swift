//
//  ZoomControlView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/4/11.
//

import AVFoundation
import SwiftUI

struct ZoomControlView: View {
  @Binding var zoomFactor: Double
  @State private var showQuickZoomMenu: Bool = false
  
  private let stepSize: Double = 25 // 25% 的缩放步长
  private let minZoomFactor: Double = 25
  private let maxZoomFactor: Double = 400
  private let quickZoomValues: [Double] = [25, 50, 100, 150, 200, 400]

  var body: some View {
    mainZoomControl
      .overlay(alignment: .bottom) {
        quickZoomMenu
          .opacity(showQuickZoomMenu ? 1 : 0)
          .scaleEffect(showQuickZoomMenu ? 1 : 0, anchor: .bottom)
          .offset(y: -28)
      }
      .padding(4)
  }

  @MainActor
  @ViewBuilder
  private var quickZoomMenu: some View {
    VStack(spacing: 4) {
      ForEach(quickZoomValues, id: \.self) { value in
        Button(action: {
          withAnimation(.easeInOut(duration: 0.2)) {
            zoomFactor = value
          }
          withAnimation(.spring.speed(2)) {
            showQuickZoomMenu.toggle()
          }
        }, label: {
          Text("\(Int(value))%")
            .font(.system(size: 8, weight: .medium))
            .frame(width: 32)
        })
        .controlSize(.mini)
        .buttonBorderShape(.roundedRectangle)
      }
    }
  }

  @MainActor
  @ViewBuilder
  private var mainZoomControl: some View {
    ZStack {
      RoundedRectangle(cornerSize: .init(width: 12, height: 12), style: .continuous)
        .fill(.ultraThinMaterial)
      HStack(spacing: 4) {
        // 减小缩放按钮
        Image(systemName: "minus")
          .foregroundStyle(zoomFactor <= minZoomFactor ? .primary.opacity(0.3) : Color.primary)
          .font(.system(size: 8, weight: .bold))
          .frame(width: 12, height: 12)
          .disabled(zoomFactor <= minZoomFactor)
          .padding(4)
          .contentShape(Circle())
          .hoverEffect(.highlight)
          .onTapGesture {
            guard zoomFactor > minZoomFactor else { return }
            decreaseZoom()
            AudioServicesPlaySystemSound(1104)
          }

        Text("\(Int(zoomFactor))%")
          .font(.system(size: 8, weight: .medium))
          .fixedSize()
          .frame(width: 24, height: 12)
          .padding(4)
          .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
          .hoverEffect(.highlight)
          .onTapGesture {
            withAnimation(.spring.speed(2)) {
              showQuickZoomMenu.toggle()
            }
            AudioServicesPlaySystemSound(1104)
          }

        Image(systemName: "plus")
          .foregroundStyle(zoomFactor >= maxZoomFactor ? .primary.opacity(0.3) : Color.primary)
          .font(.system(size: 8, weight: .bold))
          .frame(width: 12, height: 12)
          .disabled(zoomFactor >= maxZoomFactor)
          .padding(4)
          .contentShape(Circle())
          .hoverEffect(.highlight)
          .onTapGesture {
            guard zoomFactor < maxZoomFactor else { return }
            increaseZoom()
            AudioServicesPlaySystemSound(1104)
          }
      }
      .padding(4)
    }
    .frame(height: 20)
  }

  private func decreaseZoom() {
    withAnimation(.easeInOut(duration: 0.2)) {
      zoomFactor = max(minZoomFactor, zoomFactor - stepSize)
    }
  }

  private func increaseZoom() {
    withAnimation(.easeInOut(duration: 0.2)) {
      zoomFactor = min(maxZoomFactor, zoomFactor + stepSize)
    }
  }
}

#Preview {
  @Previewable @State var zoomFactor: Double = 100
  ZoomControlView(zoomFactor: $zoomFactor)
    .frame(width: 88)
}
