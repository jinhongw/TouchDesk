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
  @AppStorage("isHorizontal") private var isHorizontal: Bool = true
  @State private var goBackTrigger: Int = 0
  @State private var canGoBack: Bool = false
  @State private var isLoading: Bool = true
  @State private var loadError: String?

  let width: CGFloat
  let contentHeight: CGFloat

  private var currentURL: URL? {
    guard let drawingId = appModel.drawingId,
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
    ZStack(alignment: isHorizontal ? .topTrailing : .bottomTrailing) {
      if let url = currentURL {
        ZStack {
          FullScreenWebView(
            url: url,
            goBackTrigger: goBackTrigger,
            onURLChange: { newURL in
              guard let drawingId = appModel.drawingId,
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
            onCanGoBackChange: { canGoBack = $0 },
            onLoadingChange: { isLoading = $0 },
            onErrorChange: {
              guard $0 != nil else { return }
              debugPrint(#function, "loadError \($0 ?? "")")
              loadError = $0
            }
          )
          .cornerRadius(20)
          .padding(.top, isHorizontal ? 42 : 0)
          .frame(width: width, height: contentHeight)
          .colorScheme(.light)

          if let error = loadError {
            errorOverlay(message: error)
          }
        }
      } else {
        Color.clear
          .frame(width: width, height: contentHeight)
      }

      HStack(spacing: 12) {
        HStack {
          Button {
            goBackTrigger += 1
          } label: {
            Image(systemName: "chevron.left")
              .frame(width: 8)
          }
          .frame(width: 44, height: 44)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
        .disabled(!canGoBack)
        .opacity(canGoBack ? 1 : 0)

        HStack {
          Button {
            appModel.exitFullScreenWeb()
          } label: {
            Image(systemName: "xmark")
              .frame(width: 8)
          }
          .frame(width: 44, height: 44)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
      }
      .padding(8)
      .rotation3DEffect(.degrees(isHorizontal ? -45 : 45), axis: (1, 0, 0), anchor: .center)
      .scaleEffect(0.8, anchor: .bottomFront)
      .offset(z: 64)
    }
  }

  private var loadingOverlay: some View {
    Color.clear
      .frame(width: width, height: contentHeight)
      .overlay {
        ProgressView()
          .scaleEffect(1.2)
          .tint(.white)
      }
      .cornerRadius(20)
  }

  private func errorOverlay(message: String) -> some View {
    Color.clear
      .frame(width: width, height: contentHeight)
      .overlay {
        VStack(spacing: 12) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 40))
            .foregroundStyle(.yellow)
          Text("Load Failed")
            .font(.headline)
            .foregroundStyle(.white)
          Text(message)
            .font(.subheadline)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
        }
      }
      .cornerRadius(20)
  }
}

struct FullScreenWebView: UIViewRepresentable {
  let url: URL
  let goBackTrigger: Int
  let onURLChange: (URL) -> Void
  let onCanGoBackChange: (Bool) -> Void
  let onLoadingChange: (Bool) -> Void
  let onErrorChange: (String?) -> Void

  class Coordinator: NSObject, WKNavigationDelegate {
    let parent: FullScreenWebView
    var lastGoBackTrigger: Int = 0

    init(parent: FullScreenWebView) {
      self.parent = parent
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
      parent.onLoadingChange(true)
      parent.onErrorChange(nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      parent.onLoadingChange(false)
      guard let currentURL = webView.url else { return }
      if currentURL != parent.url {
        parent.onURLChange(currentURL)
      }
      parent.onCanGoBackChange(webView.canGoBack)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
      parent.onLoadingChange(false)
      if (error as NSError).code != NSURLErrorCancelled {
        parent.onErrorChange(error.localizedDescription)
      }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      parent.onLoadingChange(false)
      if (error as NSError).code != NSURLErrorCancelled {
        parent.onErrorChange(error.localizedDescription)
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
