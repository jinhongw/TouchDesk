//
//  GestureGuideView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/3/4.
//

import SwiftUI

struct GestureGuideView: View {
  @State private var puichGuideStatus: PuichGuideStatus = .showRight
  @State private var animationTimer: Timer?
  @State private var pichGestureGuideAppeared: Bool = false

  enum PuichGuideStatus {
    case showRight
    case rightPiching
    case rightPiched
    case showLeft
    case leftPiching
    case leftPiched
  }

  var body: some View {
    TabView {
      pichGestureGuide
      rightDominantHandGestureGuide
      leftDominantHandGestureGuide
    }
    .padding(.bottom, 20)
    .tabViewStyle(.page)
    .navigationTitle("How to Use")
  }

  @MainActor
  @ViewBuilder
  private var pichGestureGuide: some View {
    VStack(spacing: 0) {
      HStack(spacing: 64) {
        ZStack {
          Image(.leftHandPinch)
            .resizable()
            .scaledToFit()
            .opacity(puichGuideStatus == .leftPiching ? 1 : 0)
          Image(.leftHandPinchHalfway)
            .resizable()
            .scaledToFit()
            .opacity(puichGuideStatus == .showLeft || puichGuideStatus == .leftPiched ? 1 : puichGuideStatus == .leftPiching ? 0 : 0.3)
        }
        .overlay(alignment: .top, content: {
          Text("惯用手")
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .opacity(pichGestureGuideAppeared && puichGuideStatus == .leftPiched ? 1 : pichGestureGuideAppeared && (puichGuideStatus == .showRight || puichGuideStatus == .rightPiching) ? 0.3 : 0)
        })
        .offset(z: puichGuideStatus == .showLeft || puichGuideStatus == .leftPiching || puichGuideStatus == .leftPiched ? 50 : 0)
        ZStack {
          Image(.leftHandPinch)
            .resizable()
            .scaledToFit()
            .scaleEffect(x: -1)
            .opacity(puichGuideStatus == .rightPiching ? 1 : 0)
          Image(.leftHandPinchHalfway)
            .resizable()
            .scaledToFit()
            .scaleEffect(x: -1)
            .opacity(puichGuideStatus == .showRight || puichGuideStatus == .rightPiched ? 1 : puichGuideStatus == .rightPiching ? 0 : 0.3)
        }
        .overlay(alignment: .top, content: {
          Text("惯用手")
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .opacity(puichGuideStatus == .rightPiched ? 1 : puichGuideStatus == .showLeft || puichGuideStatus == .leftPiching ? 0.3 : 0)
        })
        .offset(z: puichGuideStatus == .showRight || puichGuideStatus == .rightPiching || puichGuideStatus == .rightPiched ? 50 : 0)
      }
      .offset(y: -20)
      Text("最近一次「捏合点击」画布的手，会成为惯用手。")
        .font(.headline)
        .foregroundStyle(.primary)
        .multilineTextAlignment(.center)
    }
    .padding(60)
    .onAppear {
      print(#function, "onAppear puichGuideStatus")
      
      withAnimation(.easeInOut(duration: 0.8)) {
        puichGuideStatus = .showRight
      }
      
      animationTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
        withAnimation(.easeInOut(duration: 0.8)) {
          switch puichGuideStatus {
          case .showRight:
            puichGuideStatus = .rightPiching
          case .rightPiching:
            puichGuideStatus = .rightPiched
            pichGestureGuideAppeared = true
          case .rightPiched:
            puichGuideStatus = .showLeft
          case .showLeft:
            puichGuideStatus = .leftPiching
          case .leftPiching:
            puichGuideStatus = .leftPiched
          case .leftPiched:
            puichGuideStatus = .showRight
          }
        }
      }
    }
    .onDisappear {
      print(#function, "onDisappear puichGuideStatus")
      pichGestureGuideAppeared = false
      animationTimer?.invalidate()
      animationTimer = nil
    }
  }

  @MainActor
  @ViewBuilder
  private var rightDominantHandGestureGuide: some View {
    VStack(spacing: 0) {
      HStack(spacing: 64) {
        Image(.gestureLeftMove)
          .resizable()
          .scaledToFit()
        Image(.gestureRightDraw)
          .resizable()
          .scaledToFit()
      }
      Text("惯用手为右手时")
        .font(.headline)
        .foregroundStyle(.primary)
        .multilineTextAlignment(.center)
    }
    .padding(60)
  }

  @MainActor
  @ViewBuilder
  private var leftDominantHandGestureGuide: some View {
    VStack(spacing: 0) {
      HStack(spacing: 64) {
        Image(.gestureRightDraw)
          .resizable()
          .scaledToFit()
          .scaleEffect(x: -1)
        Image(.gestureLeftMove)
          .resizable()
          .scaledToFit()
          .scaleEffect(x: -1)
      }
      Text("惯用手为左手时")
        .font(.headline)
        .foregroundStyle(.primary)
        .multilineTextAlignment(.center)
    }
    .padding(60)
  }
}

#Preview {
  NavigationStack {
    GestureGuideView()
  }.frame(width: 620, height: 480)
}
