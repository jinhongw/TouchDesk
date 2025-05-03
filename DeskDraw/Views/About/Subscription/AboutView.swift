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
  @Environment(\.openURL) private var openURL
  let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

  var isSimplifiedChinese: Bool {
    Locale.current.language.languageCode?.identifier == "zh" && Locale.current.language.script!.identifier == "Hans"
  }
  
  var isLifetime: Bool {
    appModel.subscriptionViewModel.purchasedTransactions.contains(where: { $0.productID == "com.easybreezy.touchdesk.lifetime" })
  }

  var isYearlyPlan: Bool {
    appModel.subscriptionViewModel.purchasedTransactions.contains(where: { $0.productID == "com.easybreezy.touchdesk.yearly.subscription" })
  }
  
  func planName(_ id: String) -> String {
    switch id {
    case "com.easybreezy.touchdesk.lifetime": return NSLocalizedString("Lifetime", comment: "")
    case "com.easybreezy.touchdesk.yearly.subscription": return NSLocalizedString("Annual", comment: "")
    case "com.easybreezy.touchdesk.monthly.subscription": return NSLocalizedString("Monthly", comment: "")
    default: return ""
    }
  }

  var body: some View {
    @Bindable var appModel = appModel
    NavigationStack(path: $appModel.aboutNavigationPath) {
      ScrollView {
        VStack(spacing: 20) {
          header
          Divider()
          content
        }
        .padding(48)
      }
      .navigationDestination(for: AppModel.AboutRoute.self, destination: { route in
        switch route {
        case .setting: SettingView()
        case .subscription: SubscriptionView().environment(appModel.subscriptionViewModel)
        case .gestureGuide: GestureGuideView()
        case .credit: CreditView()
        }
      })
    }
  }

  @MainActor
  @ViewBuilder
  private var header: some View {
    VStack(spacing: 8) {
      Image("TouchDesk App Icon")
        .resizable()
        .frame(width: 120, height: 120)
      VStack(spacing: 4) {
        Text("TouchDesk")
          .font(.system(size: 32.0, weight: .bold))
          .fontDesign(.rounded)
          .multilineTextAlignment(.center)
          .overlay(proLogo)
        if appModel.subscriptionViewModel.hasPro, let transaction = appModel.subscriptionViewModel.purchasedTransactions.first {
          Text("\(planName(transaction.productID)) plan")
            .font(.system(size: 17.0, weight: .semibold, design: .rounded))
            .foregroundStyle(
              isLifetime ? LinearGradient(
                gradient: Gradient(colors: [Color.orange, Color.pink, Color.purple]),
                startPoint: .leading,
                endPoint: .trailing
              ) : isYearlyPlan ? LinearGradient(
                gradient: Gradient(colors: [Color.blue, Color.white]),
                startPoint: .leading,
                endPoint: .trailing
              ) : LinearGradient(
                gradient: Gradient(colors: [Color.secondary, Color.white]),
                startPoint: .leading,
                endPoint: .trailing
              ))
        }
        Text("Version: \(appVersion ?? "1.0")")
          .font(.caption)
          .foregroundColor(.secondary)
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
          .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
          .overlay(ShimmerMask().clipShape(RoundedRectangle(cornerRadius: 12)))
          .overlay(sparklesOverlay())
          .rotationEffect(.degrees(16))
          .offset(z: 8)
          .offset(x: 36, y: -20)
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
    .frame(width: 480, height: isSimplifiedChinese ? 1000 : 880)
    .scrollDisabled(true)
    .padding(.vertical, 20)
  }

  @MainActor
  @ViewBuilder
  private var settings: some View {
    NavigationLink(value: AppModel.AboutRoute.setting) {
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
    NavigationLink(value: AppModel.AboutRoute.gestureGuide) {
      HStack {
        Image(systemName: "hand.draw.fill")
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
    NavigationLink(value: AppModel.AboutRoute.subscription) {
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
            Text("解锁无限图画、iCloud 同步")
              .font(.caption)
          }
        }
      }
    }
  }

  @MainActor
  @ViewBuilder
  private var credits: some View {
    NavigationLink(value: AppModel.AboutRoute.credit) {
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
      openURL(URL(string: "https://apps.apple.com/us/app/touchdesk-desktop-canvas/id6740164313?action=write-review")!)
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
}

#Preview {
  AboutView()
    .environment(AppModel())
}
