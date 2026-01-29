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
        FullScreenWebView(
          url: url,
          onURLChange: { newURL in
            guard
              let drawingId = appModel.drawingId,
              var drawing = appModel.drawings[drawingId],
              let webId = appModel.fullScreenWebId,
              let index = drawing.webs.firstIndex(where: { $0.id == webId })
            else {
              return
            }

            drawing.webs[index].url = newURL.absoluteString
            drawing.modifiedAt = Date()
            appModel.drawings[drawingId] = drawing
            appModel.updateDrawing(drawingId)
          }
        )
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
  let onURLChange: (URL) -> Void

  class Coordinator: NSObject, WKNavigationDelegate {
    let parent: FullScreenWebView

    init(parent: FullScreenWebView) {
      self.parent = parent
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      guard let currentURL = webView.url else { return }
      if currentURL != parent.url {
        parent.onURLChange(currentURL)
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = true
    let webView = WKWebView(frame: .zero, configuration: configuration)
    // webView.backgroundColor = .clear
    // webView.isOpaque = false
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.navigationDelegate = context.coordinator
    webView.load(URLRequest(url: url))
    return webView
  }

  func updateUIView(_ uiView: WKWebView, context: Context) {
    if uiView.url != url {
      uiView.load(URLRequest(url: url))
    }
  }
}

