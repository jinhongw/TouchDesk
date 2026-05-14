//
//  FullScreenVideoView.swift
//  DeskDraw
//
//  Created by Codex on 2026/5/14.
//

import AVKit
import SwiftUI

struct FullScreenVideoViewContainer: View {
  @Environment(AppModel.self) private var appModel
  @AppStorage("isHorizontal") private var isHorizontal: Bool = true
  @State private var player: AVPlayer?
  @State private var currentVideoId: UUID?

  let width: CGFloat
  let contentHeight: CGFloat

  private var currentVideo: VideoElement? {
    guard let drawingId = appModel.drawingId,
          let drawing = appModel.drawings[drawingId],
          let videoId = appModel.fullScreenVideoId
    else {
      return nil
    }
    return drawing.videos.first(where: { $0.id == videoId })
  }

  var body: some View {
    ZStack(alignment: isHorizontal ? .topTrailing : .bottomTrailing) {
      Group {
        if let player {
          VideoPlayer(player: player)
            .frame(width: width, height: contentHeight)
            .cornerRadius(20)
            .colorScheme(.dark)
        } else {
          Color.black
            .frame(width: width, height: contentHeight)
            .cornerRadius(20)
        }
      }

      HStack {
        Button {
          appModel.exitFullScreenVideo()
        } label: {
          Image(systemName: "xmark")
            .frame(width: 8)
        }
        .frame(width: 44, height: 44)
      }
      .buttonStyle(.borderless)
      .controlSize(.small)
      .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      .padding(8)
      .rotation3DEffect(.degrees(isHorizontal ? -45 : 45), axis: (1, 0, 0), anchor: .center)
      .scaleEffect(0.8, anchor: .bottomFront)
      .offset(z: 64)
    }
    .onAppear(perform: updatePlayer)
    .onChange(of: appModel.fullScreenVideoId) { _, _ in
      updatePlayer()
    }
    .onDisappear {
      player?.pause()
      player = nil
      currentVideoId = nil
    }
  }

  private func updatePlayer() {
    guard let video = currentVideo else {
      player?.pause()
      player = nil
      currentVideoId = nil
      return
    }
    guard currentVideoId != video.id else { return }
    player?.pause()
    player = AVPlayer(url: DrawingFileManager.shared.videoURL(fileName: video.fileName))
    currentVideoId = video.id
    player?.play()
  }
}
