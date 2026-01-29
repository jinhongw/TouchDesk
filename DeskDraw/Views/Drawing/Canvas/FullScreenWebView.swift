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
  @State private var goBackTrigger: Int = 0
  @State private var canGoBack: Bool = false

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
          goBackTrigger: goBackTrigger,
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
          },
          onCanGoBackChange: { canGoBack = $0 }
        )
          .cornerRadius(20)
          .frame(width: width, height: contentHeight)
          .colorScheme(.light)
      } else {
        Color.clear
          .frame(width: width, height: contentHeight)
      }

      HStack(spacing: 8) {
        Button {
          goBackTrigger += 1
        } label: {
          Image(systemName: "chevron.left")
            .font(.system(size: 14, weight: .semibold))
            .padding(8)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: Circle())
        .disabled(!canGoBack)
        .opacity(canGoBack ? 1 : 0)

        Button {
          appModel.exitFullScreenWeb()
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 14, weight: .semibold))
            .padding(8)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: Circle())
      }
      .padding(16)
    }
  }
}

struct FullScreenWebView: UIViewRepresentable {
  let url: URL
  let goBackTrigger: Int
  let onURLChange: (URL) -> Void
  let onCanGoBackChange: (Bool) -> Void

  class Coordinator: NSObject, WKNavigationDelegate {
    let parent: FullScreenWebView
    var lastGoBackTrigger: Int = 0

    init(parent: FullScreenWebView) {
      self.parent = parent
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      guard let currentURL = webView.url else { return }
      if currentURL != parent.url {
        parent.onURLChange(currentURL)
      }
      parent.onCanGoBackChange(webView.canGoBack)
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = true
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.navigationDelegate = context.coordinator
    webView.load(URLRequest(url: url))
    return webView
  }

  func updateUIView(_ uiView: WKWebView, context: Context) {
    if uiView.url != url {
      uiView.load(URLRequest(url: url))
    }
    if goBackTrigger > context.coordinator.lastGoBackTrigger {
      context.coordinator.lastGoBackTrigger = goBackTrigger
      if uiView.canGoBack {
        uiView.goBack()
      }
    }
  }
}

