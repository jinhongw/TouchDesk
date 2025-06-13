//
//  ZoomControlView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/4/11.
//

import AVFoundation
import PencilKit
import SwiftUI

struct ZoomControlView: View {
  @AppStorage("showMiniMap") private var showMiniMap = true
  @AppStorage("showQuickZoomButtons") private var showQuickZoomButtons = true
  @AppStorage("commonZoomFactors") private var commonZoomFactors: DoubleArrayStorageModel = .init(array: [100, 150, 200])
  
  @Binding var zoomFactor: Double
  
  @State private var showQuickZoomMenu: Bool = false
  @State private var lastDragPosition: CGFloat = 0 // 添加状态变量记录上一次拖动位置
  @State private var draging: Bool = false

  private let minZoomFactor: Double = 25
  private let maxZoomFactor: Double = 400
  private let quickZoomValues: [Double] = [25, 50, 100, 150, 175, 200, 250, 300, 350, 400]
  private let sliderValues: [Double] = (0 ... 15).map { Double($0) }
  private let sliderZoomValues: [Double] = (0 ... 15).map { Double(25 + ($0 * 25)) }
  

  private var currentValue: Double {
    (zoomFactor - 25) / 25
  }

  var body: some View {
    VStack {
      if showQuickZoomButtons {
        zoomControlButtons
      }
      zoomControlSlider
        .overlay(alignment: .bottom) {
          quickZoomMenu
            .opacity(showQuickZoomMenu ? 1 : 0)
            .scaleEffect(showQuickZoomMenu ? 0.8 : 0, anchor: .bottom)
            .offset(y: -28)
        }
    }
  }

  @MainActor
  @ViewBuilder
  private var zoomControlButtons: some View {
    HStack(spacing: 4) {
      ForEach(commonZoomFactors.array, id: \.self) { commonZoomFactor in
        Button(action: {
          withAnimation(.spring.speed(2)) {
            zoomFactor = commonZoomFactor
          }
        }, label: {
          Text("×\((commonZoomFactor / 100).trimmedString())")
            .fixedSize()
            .font(.system(size: 8, weight: .bold))
            .frame(maxWidth: .infinity)
        })
        .controlSize(.mini)
        .buttonBorderShape(.roundedRectangle)
        .background {
          if zoomFactor == commonZoomFactor {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .foregroundColor(.white.opacity(0.6))
          }
        }
      }
      if !showMiniMap {
        FoldMiniMapButton()
      }
    }
  }

  @MainActor
  @ViewBuilder
  private var zoomControlSlider: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(.ultraThinMaterial)
      HStack(spacing: 4) {
        zoomSlider
        quickSwitchButton
        if !showMiniMap && !showQuickZoomButtons {
          FoldMiniMapButton()
        }
      }
      .padding(4)
      .padding(.leading, 4)
    }
    .frame(height: 20)
    .simultaneousGesture(
      DragGesture(minimumDistance: 8)
        .onChanged { value in
          let currentPosition = value.translation.width
          let dragDistance = currentPosition - lastDragPosition
          guard abs(dragDistance) < 20 else {
            lastDragPosition = currentPosition
            return
          }
          if abs(dragDistance) >= 10 {
            if !draging { draging = true }
            let step = dragDistance > 0 ? 1 : -1
            let newValue = Int(currentValue) + step
            let clampedValue = min(max(newValue, 0), 15)
            if clampedValue != Int(currentValue) {
              withAnimation(.spring.speed(2)) {
                zoomFactor = Double(25 + (clampedValue * 25))
              }
              AudioServicesPlaySystemSound(1104)
              lastDragPosition = currentPosition
            }
          }
        }
        .onEnded { _ in
          lastDragPosition = 0
          draging = false
        }
    )
  }
  
  func getZoomSliderValue(_ value: Double) -> String {
    let reslut = (25 + value * 25) / 100
    return "×\(reslut.trimmedString())"
  }
  
  @MainActor
  @ViewBuilder
  private var zoomSlider: some View {
    HStack(alignment: .bottom, spacing: 1) {
      ForEach(sliderValues, id: \.self) { value in
        Capsule()
          .frame(width: value == currentValue ? 2 : 1, height: value == currentValue ? 8 : pow((value + 1) * 1.5, 1.0 / 1.6))
          .foregroundColor(value == currentValue ? .white : .secondary)
          .overlay {
            Text(getZoomSliderValue(value))
              .font(.headline)
              .padding(4)
              .background(content: {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .fill(.ultraThinMaterial)
              })
              .fixedSize()
              .opacity(value == currentValue && draging ? 1 : 0)
              .offset(y: -32)
              .animation(nil, value: currentValue)
              .animation(nil, value: draging)
          }
          .padding(.horizontal, 1)
          .overlay {
            Rectangle()
              .frame(width: 4, height: 28)
              .foregroundColor(.white.opacity(0.01))
              .opacity(0.01)
              .onTapGesture(perform: {
                withAnimation(.spring.speed(2)) {
                  zoomFactor = Double(25 + (value * 25))
                }
                AudioServicesPlaySystemSound(1104)
              })
          }
      }
    }
  }

  @MainActor
  @ViewBuilder
  private var quickSwitchButton: some View {
    Text("×\((zoomFactor / 100).trimmedString())")
      .font(.system(size: 8, weight: .bold))
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
      .simultaneousGesture(
        TapGesture(count: 2)
          .onEnded { _ in
            withAnimation(.spring.speed(2)) {
              zoomFactor = 100
            }
            Task {
              try? await Task.sleep(for: .seconds(0.1))
              withAnimation(.spring.speed(2)) {
                showQuickZoomMenu = false
              }
            }
            AudioServicesPlaySystemSound(1104)
          }
      )
  }

  @MainActor
  @ViewBuilder
  private var quickZoomMenu: some View {
    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 2)

    LazyVGrid(columns: columns, spacing: 4) {
      ForEach(quickZoomValues, id: \.self) { value in
        Button(action: {
          withAnimation(.spring.speed(2)) {
            zoomFactor = value
          }
          withAnimation(.spring.speed(2)) {
            showQuickZoomMenu.toggle()
          }
        }, label: {
          Text("×\((value / 100).trimmedString())")
            .fixedSize()
            .font(.system(size: 10, weight: .bold))
            .frame(maxWidth: .infinity)
        })
        .controlSize(.mini)
        .buttonBorderShape(.roundedRectangle)
        .background {
          if zoomFactor == value {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .foregroundColor(.white.opacity(0.6))
          }
        }
      }
    }
    .frame(width: 138)
  }
}

struct FoldMiniMapButton: View {
  @AppStorage("showMiniMap") private var showMiniMap = true
  var body: some View {
    Image(systemName: showMiniMap ? "chevron.compact.down" : "chevron.compact.up")
      .foregroundStyle(.primary)
      .font(.system(size: 8, weight: .bold))
      .frame(width: 12, height: 12)
      .padding(4)
      .contentShape(Circle())
      .hoverEffect(.highlight)
      .onTapGesture {
        showMiniMap.toggle()
        AudioServicesPlaySystemSound(1104)
      }
  }
}

#Preview {
  MiniMapView(canvas: PKCanvasView(), isHorizontal: true, contentOffset: .constant(.init(x: 100, y: 100)))
    .environment(AppModel())
}
