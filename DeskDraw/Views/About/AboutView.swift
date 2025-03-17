//
//  AboutView.swift
//  SunClock
//
//  Created by jinhong on 2024/12/20.
//

import StoreKit
import SwiftUI
import UIKit

struct AboutView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.requestReview) private var requestReview
  @Environment(\.openURL) private var openURL
  let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

  var isSimplifiedChinese: Bool {
    Locale.current.language.languageCode?.identifier == "zh" && Locale.current.language.script!.identifier == "Hans"
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          header
          Divider()
          content
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
          .font(.system(size: 32.0, weight: .bold))
          .fontDesign(.rounded)
          .overlay(proLogo)
        Text("Version: \(appVersion ?? "1.0")")
          .font(.caption)
          .tint(.secondary)
      }
    }
  }
  
  @MainActor
  @ViewBuilder
  private var proLogo: some View {
    VStack {
      HStack {
        Spacer(minLength: 0)
        Text("Pro")
          .font(.system(size: 20, weight: .bold, design: .rounded))
          .padding(.horizontal, 5)
          .padding(.vertical, 2)
          .background(RoundedRectangle(cornerRadius: 12).foregroundStyle(.white.opacity(0.8)))
          .background(RoundedRectangle(cornerRadius: 12).foregroundStyle(LinearGradient(
            gradient: Gradient(colors: [Color.white, Color.purple, Color.orange]),
            startPoint: .leading,
            endPoint: .trailing
          )))
          .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
          .overlay(ShimmerMask().clipShape(RoundedRectangle(cornerRadius: 12)))
          .overlay(sparklesOverlay())
          .rotationEffect(.degrees(16))
          .offset(z: 16)
          .offset(x: 36, y: -20)
          .foregroundStyle(LinearGradient(
            gradient: Gradient(colors: [Color.orange, Color.purple]),
            startPoint: .leading,
            endPoint: .trailing
          ))
          .opacity(appModel.subscriptionViewModel.hasPro ? 1 : 0)
      }
      Spacer(minLength: 0)
    }
  }

  @MainActor
  @ViewBuilder
  private var content: some View {
    List {
      Section {
        upgrade
      }
      Section {
        settings
        gestureGuide
      }
      Section {
        appStore
        if isSimplifiedChinese {
          followMeOnREDnote
        }
        followMe
        feedback
      }
      Section {
        credits
        privacyPolicy
        termsOfService
      }
      Section {
        littleSunshineLink
        easyballLink
      } header: {
        Text("Made by easybreezy")
          .font(.subheadline)
      }
    }
    .frame(width: 480, height: 880)
    .scrollDisabled(true)
    .padding(.vertical, 20)
  }

  @MainActor
  @ViewBuilder
  private var settings: some View {
    NavigationLink {
      SettingView()
        .environment(appModel)
    } label: {
      HStack {
        Image(systemName: "gearshape.fill")
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
          Text("Settings")
          Text("偏好设置")
            .font(.caption)
        }
      }
    }
  }
  
  @MainActor
  @ViewBuilder
  private var gestureGuide: some View {
    NavigationLink {
      GestureGuideView()
    } label: {
      HStack {
        Image(systemName: "questionmark.circle.fill")
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
          Text("How to Use")
          Text("Drawing & Canvas Gestures")
            .font(.caption)
        }
      }
    }
  }

  @MainActor
  @ViewBuilder
  private var upgrade: some View {
    NavigationLink {
      SubscriptionView()
        .environment(appModel.subscriptionViewModel)
    } label: {
      HStack {
        Image(systemName: "crown.fill")
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
          Text(appModel.subscriptionViewModel.hasPro ? "TouchDesk Pro" : "Upgrade to Pro")
          if let expirationDate = appModel.subscriptionViewModel.purchasedTransactions.first?.expirationDate {
            Text("Until \(expirationDate.formatted(date: .abbreviated, time: .omitted))")
              .font(.caption)
          } else if appModel.subscriptionViewModel.hasPro {
            Text("Lifetime plan")
              .font(.caption)
          } else {
            Text("解锁无限图画、iCloud 储存")
              .font(.caption)
          }
        }
      }
    }
  }

  @MainActor
  @ViewBuilder
  private var credits: some View {
    NavigationLink {
      CreditView()
    } label: {
      HStack {
        Image(systemName: "info.circle.fill")
          .resizable()
          .padding(7)
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
        }
      }
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
  private var followMeOnREDnote: some View {
    Button(action: {
      openURL(URL(string: "https://www.xiaohongshu.com/user/profile/5b45feb211be104b64fba5f0")!)
    }, label: {
      HStack {
        Image("REDnote")
          .resizable()
          .frame(width: 36, height: 36)
          .cornerRadius(18)
        VStack(alignment: .leading) {
          Text("Follow me")
          Text("Follow me @easybreezy on 小红书")
            .font(.caption)
        }
      }
    })
  }

  @MainActor
  @ViewBuilder
  private var feedback: some View {
    Button(action: {
      let subject = "TouchDesk Feedback"
      
      // 获取系统信息
      let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
      let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
      let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
      let deviceModel = UIDevice.current.model
      
      // 构建邮件正文
      let body = """
      
      
      App Version: \(appVersion) (\(buildNumber))
      System Version: \(systemVersion)
      Device Model: \(deviceModel)
      """
      
      let email = "jinhongw982@gmail.com"
      
      let mailto = "mailto:\(email)?subject=\(subject)&body=\(body)"
          .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

      if let url = URL(string: mailto) {
          openURL(url)
      }
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
  private var privacyPolicy: some View {
    Button(action: {
      openURL(URL(string: "https://www.privacypolicies.com/live/3c26c477-7f4a-4891-a76d-57bf99968465")!)
    }, label: {
      HStack {
        Image(systemName: "lock.shield.fill")
          .resizable()
          .padding(.horizontal, 9)
          .padding(.vertical, 7)
          .frame(width: 36, height: 36)
          .offset(y: 0.5)
          .cornerRadius(18)
          .background(LinearGradient(
            gradient: Gradient(colors: [Color(white: 0.6), Color(white: 0.5)]),
            startPoint: .top,
            endPoint: .bottom
          ), in: Circle())
        VStack(alignment: .leading) {
          Text("Privacy Policy")
        }
      }
    })
  }
  
  @MainActor
  @ViewBuilder
  private var termsOfService: some View {
    Button(action: {
      openURL(URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
    }, label: {
      HStack {
        Image(systemName: "newspaper.fill")
          .resizable()
          .padding(9)
          .frame(width: 36, height: 36)
          .cornerRadius(18)
          .background(LinearGradient(
            gradient: Gradient(colors: [Color(white: 0.6), Color(white: 0.5)]),
            startPoint: .top,
            endPoint: .bottom
          ), in: Circle())
        VStack(alignment: .leading) {
          Text("Term of Service")
        }
      }
    })
  }
  
  @MainActor
  @ViewBuilder
  private var easyballLink: some View {
    Button(action: {
      openURL(URL(string: "https://apps.apple.com/us/app/easyball-airshot/id6642670140")!)
    }, label: {
      HStack {
        Image("easyball_icon")
          .resizable()
          .frame(width: 36, height: 36)
          .cornerRadius(18)
        VStack(alignment: .leading) {
          Text("EasyBall - AirShot")
          Text("Shoot as if it's real life")
            .font(.caption)
        }
      }
    })
  }
  
  @MainActor
  @ViewBuilder
  private var littleSunshineLink: some View {
    Button(action: {
      openURL(URL(string: "https://apps.apple.com/us/app/little-sunshine-sunclock/id6739750403")!)
    }, label: {
      HStack {
        Image("little_sunshine_icon")
          .resizable()
          .frame(width: 36, height: 36)
          .cornerRadius(18)
        VStack(alignment: .leading) {
          Text("Little Sunshine - SunClock")
          Text("Feel time through the Sun")
            .font(.caption)
        }
      }
    })
  }

  private func presentReview() {
    requestReview()
  }
}

#Preview {
  AboutView()
    .environment(AppModel())
}
