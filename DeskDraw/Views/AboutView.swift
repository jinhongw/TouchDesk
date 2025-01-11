//
//  AboutView.swift
//  SunClock
//
//  Created by jinhong on 2024/12/20.
//

import MessageUI
import StoreKit
import SwiftUI
import UIKit
import TipKit

struct AboutView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.requestReview) private var requestReview
  @Environment(\.openURL) private var openURL
  @State private var isShowingMailView = false
  @State private var mailResult: Result<MFMailComposeResult, Error>? = nil
  let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          header
          Divider()
          content
          appleWeather
        }
        .padding(48)
      }
    }
  }

  @MainActor
  @ViewBuilder
  private var header: some View {
    VStack(spacing: 8) {
      Image("TouchDesk App Icon")
        .resizable()
        .frame(width: 120, height: 120)
      VStack(spacing: 2) {
        Text("TouchDesk")
          .font(.title)
        Text("Version: \(appVersion ?? "1.0")")
          .font(.caption)
          .tint(.secondary)
      }
    }
  }

  @MainActor
  @ViewBuilder
  private var content: some View {
    List {
      Section {
        credits
      }
      Section {
        appStore
        followMe
        feedback
      }
    }
    .frame(width: 480, height: 300)
    .scrollDisabled(true)
    .padding(.vertical, 20)
    .sheet(isPresented: $isShowingMailView) {
      NavigationStack {
        mailView
      }
    }
  }
  
//  @MainActor
//  @ViewBuilder
//  private var settings: some View {
//    NavigationLink {
//      SettingView()
//        .environment(appModel)
//    } label: {
//      HStack {
//        Image(systemName: "gearshape.fill")
//          .resizable()
//          .padding(6)
//          .frame(width: 36, height: 36)
//          .offset(x: 0.5)
//          .cornerRadius(18)
//          .background(LinearGradient(
//            gradient: Gradient(colors: [Color(white: 0.6), Color(white: 0.5)]),
//            startPoint: .top,
//            endPoint: .bottom
//          ), in: Circle())
//
//        VStack(alignment: .leading) {
//          Text("Settings")
//          Text("偏好设置")
//            .font(.caption)
//        }
//      }
//    }
//  }
  
  @MainActor
  @ViewBuilder
  private var credits: some View {
    NavigationLink {
      CreditView()
    } label: {
      HStack {
        Image(systemName: "info.circle")
          .resizable()
          .padding(6)
          .frame(width: 36, height: 36)
          .offset(x: 0.5)
          .cornerRadius(18)
          .background(LinearGradient(
            gradient: Gradient(colors: [Color(white: 0.6), Color(white: 0.5)]),
            startPoint: .top,
            endPoint: .bottom
          ), in: Circle())

        VStack(alignment: .leading) {
          Text("Credits")
          Text("授权信息")
            .font(.caption)
        }
      }
    }
  }
  
  @MainActor
  @ViewBuilder
  private var resetTips: some View {
    HStack {
      Image(systemName: "quote.bubble.fill")
        .resizable()
        .padding(.top, 8)
        .padding(.horizontal, 7)
        .padding(.bottom, 6)
        .frame(width: 36, height: 36)
        .cornerRadius(18)
        .background(LinearGradient(
          gradient: Gradient(colors: [Color(white: 0.6), Color(white: 0.5)]),
          startPoint: .top,
          endPoint: .bottom
        ), in: Circle())
      Button(action: {
        do {
          try Tips.resetDatastore()
          try Tips.configure()
        } catch {
          print("Error initializing TipKit \(error.localizedDescription)")
        }
      }, label: {
        VStack(alignment: .leading) {
          Text("查看提示")
          Text("重新显示所有提示")
            .font(.caption)
        }
      })
    }
  }

  @MainActor
  @ViewBuilder
  private var appStore: some View {
    Button(action: {
      presentReview()
    }, label: {
      HStack {
        Image("AppStore")
          .resizable()
          .frame(width: 36, height: 36)
          .cornerRadius(18)
        VStack(alignment: .leading) {
          Text("Rate the App")
          Text("Like the app support me")
            .font(.caption)
        }
      }
    })
  }

  @MainActor
  @ViewBuilder
  private var followMe: some View {
    Button(action: {
      openURL(URL(string: "https://x.com/easybreezy982")!)
    }, label: {
      HStack {
        Image("Twitter")
          .resizable()
          .frame(width: 36, height: 36)
          .cornerRadius(18)
        VStack(alignment: .leading) {
          Text("Follow me")
          Text("Follow me @easybreezy982 on Twitter/X")
            .font(.caption)
        }
      }
    })
  }

  @MainActor
  @ViewBuilder
  private var feedback: some View {
    Button(action: {
      isShowingMailView.toggle()
    }, label: {
      HStack {
        Image("Gmail")
          .resizable()
          .frame(width: 36, height: 36)
          .cornerRadius(18)
        VStack(alignment: .leading) {
          Text("Feedback")
          Text("Send email to jinhongw982@gmail.com")
            .font(.caption)
        }
      }
    })
  }
  
  @MainActor
  @ViewBuilder
  private var appleWeather: some View {
    VStack(spacing: 0) {
      Text("日落日出时间由  Weather 提供")
        .foregroundStyle(.secondary)
      Link("Learn More", destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!)
    }
    .font(.caption)
  }
  
  @MainActor
  @ViewBuilder
  private var mailView: some View {
    MailView(result: $mailResult)
      .ignoresSafeArea()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(action: {
            isShowingMailView.toggle()
          }, label: {
            Image(systemName: "xmark")
          })
          .frame(width: 44, height: 44)
        }
      }
  }

  private func presentReview() {
    requestReview()
  }
}

struct MailView: UIViewControllerRepresentable {
  // MARK: - Variables

  @Binding var result: Result<MFMailComposeResult, Error>?

  @Environment(\.presentationMode) var presentation

  // MARK: - Coordinator

  class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
    @Binding var presentation: PresentationMode
    @Binding var result: Result<MFMailComposeResult, Error>?

    init(presentation: Binding<PresentationMode>, result: Binding<Result<MFMailComposeResult, Error>?>) {
      _presentation = presentation
      _result = result
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
      defer {
        $presentation.wrappedValue.dismiss()
      }
      guard error == nil else {
        self.result = .failure(error!)
        return
      }
      self.result = .success(result)
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(presentation: presentation, result: $result)
  }

  // MARK: - UIViewController

  func makeUIViewController(context: UIViewControllerRepresentableContext<MailView>) -> MFMailComposeViewController {
    let vc = MFMailComposeViewController()
    vc.mailComposeDelegate = context.coordinator
    vc.setSubject(Config.reportBugSubject)
    vc.setToRecipients([Config.contactEmail])
    vc.navigationBar.prefersLargeTitles = true
    return vc
  }

  func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: UIViewControllerRepresentableContext<MailView>) {}
}

enum Config {
  // MARK: - Mail

  static let contactEmail = "jinhongw982@gmail.com"
  static let reportBugSubject = "TouchDesk Feedback"
}

#Preview {
  AboutView()
    .environment(AppModel())
}
