//
//  FullScreenWebView.swift
//  DeskDraw
//
//  Created by AI on 2026/1/28.
//

import SwiftUI
import WebKit

struct FullScreenWebViewContainer: View {
  @Environment(AppModel.self) private var appModel

  let width: CGFloat
  let contentHeight: CGFloat

  private var currentURL: URL? {
    guard
      let drawingId = appModel.drawingId,
      let drawing = appModel.drawings[drawingId],
      let webId = appModel.fullScreenWebId,
      let web = drawing.webs.first(where: { $0.id == webId }),
      let url = URL(string: web.url)
    else {
      return nil
    }
    return url
  }

  var body: some View {
    ZStack(alignment: .topTrailing) {
      if let url = currentURL {
        FullScreenWebView(url: url)
          .cornerRadius(20)
          .frame(width: width, height: contentHeight)
          .colorScheme(.light)
      } else {
        Color.clear
          .frame(width: width, height: contentHeight)
      }

      Button {
        appModel.exitFullScreenWeb()
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 14, weight: .semibold))
          .padding(8)
      }
      .buttonStyle(.borderless)
      .background(.ultraThinMaterial, in: Circle())
      .padding(16)
    }
  }
}

struct FullScreenWebView: UIViewRepresentable {
  let url: URL

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = true
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.backgroundColor = .clear
    webView.isOpaque = false
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.load(URLRequest(url: url))
    return webView
  }

  func updateUIView(_ uiView: WKWebView, context: Context) {
    if uiView.url != url {
      uiView.load(URLRequest(url: url))
    }
  }
}

