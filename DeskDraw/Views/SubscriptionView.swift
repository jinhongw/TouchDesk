//
//  SubscriptionView.swift
//  DeskDraw
//
//  Created by jinhong on 2025/1/13.
//

import AVFoundation
import StoreKit
import SwiftUI

struct SubscriptionView: View {
  // MARK: - Properties

  @Environment(SubscriptionViewModel.self) private var subscriptionViewModel
  @State private var selectedProduct: Product? = nil
  @State private var showConfetti = false
  @State private var showWelcome = false

  var isLifetime: Bool {
    subscriptionViewModel.purchasedTransactions.contains(where: { $0.productID == "com.easybreezy.touchdesk.lifetime" })
  }

  var isYearlyPlan: Bool {
    subscriptionViewModel.purchasedTransactions.contains(where: { $0.productID == "com.easybreezy.touchdesk.yearly.subscription" })
  }

  func manageSubscription() {
    print(#function, "DEBUG", UIApplication.shared.connectedScenes)
    if let window = UIApplication.shared.connectedScenes.first {
      Task {
        do {
          try await AppStore.showManageSubscriptions(in: window as! UIWindowScene)
        } catch {
          print(error)
        }
      }
    }
  }

  func planName(_ id: String) -> String {
    switch id {
    case "com.easybreezy.touchdesk.lifetime": return NSLocalizedString("Lifetime", comment: "")
    case "com.easybreezy.touchdesk.yearly.subscription": return NSLocalizedString("Annual", comment: "")
    case "com.easybreezy.touchdesk.monthly.subscription": return NSLocalizedString("Monthly", comment: "")
    default: return ""
    }
  }

  // MARK: - Layout

  var body: some View {
    @Bindable var subscriptionViewModel = subscriptionViewModel
    ScrollView {
      VStack(alignment: .center, spacing: 32) {
        proAccessView
        if !subscriptionViewModel.hasPro {
          if !subscriptionViewModel.products.isEmpty {
            VStack(spacing: 20) {
              productsListView
              purchaseSection
            }
          } else {
            VStack {
              Spacer()
              ProgressView()
                .progressViewStyle(.circular)
                .ignoresSafeArea(.all)
              Spacer()
            }
          }
        }
      }
      .padding(.horizontal, 48)
      .padding(.bottom, 48)
      .frame(width: 480)
      .task {
        await subscriptionViewModel.loadProducts()
        selectedProduct = subscriptionViewModel.products.first
      }
      .alert("Need Cancel Subscription First", isPresented: $subscriptionViewModel.showNeedCancelSubscription) {
        Button("OK", role: .cancel) {}
        Button("Manage") {
          manageSubscription()
        }
      }
    }
    .overlay(purchaseLoding)
    .displayConfetti(isActive: $showConfetti)
    .onChange(of: subscriptionViewModel.hasPro) { oldValue, newValue in
      if oldValue == false, newValue == true {
        showConfetti = true
        showWelcome = true
      }
    }
  }

  @MainActor
  @ViewBuilder
  private var purchaseLoding: some View {
    VStack {
      Spacer()
      HStack {
        Spacer()
        ProgressView()
          .padding(32)
          .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32))
          .offset(z: 12)
        Spacer()
      }
      Spacer()
    }
    .background {
      Rectangle()
        .foregroundStyle(.black.opacity(0.3))
        .ignoresSafeArea(.all)
    }
    .ignoresSafeArea(.all)
    .opacity(subscriptionViewModel.purchasing ? 1 : 0)
  }

  private var proAccessView: some View {
    VStack(alignment: .center, spacing: 20) {
      VStack(spacing: 8) {
        Image("TouchDesk App Icon")
          .resizable()
          .frame(width: 120, height: 120)
        VStack(spacing: 4) {
          Text(subscriptionViewModel.hasPro ? showWelcome ? "Welcome to TouchDesk" : "TouchDesk" : "Unlock Pro Access")
            .font(.system(size: 32.0, weight: .bold))
            .fontDesign(.rounded)
            .multilineTextAlignment(.center)
            .overlay(proLogo)
          if subscriptionViewModel.hasPro, let transaction = subscriptionViewModel.purchasedTransactions.first {
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
            if let expirationDate = transaction.expirationDate {
              Text("Until \(expirationDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
            }
          }
        }
      }
      if subscriptionViewModel.hasPro {
        Divider()
      }

      VStack(spacing: 8) {
        HStack(alignment: .center) {
          Image(systemName: "infinity")
            .font(.system(size: 17.0, weight: .bold))
            .foregroundStyle(LinearGradient(
              gradient: Gradient(colors: [Color.orange, Color.pink, Color.purple]),
              startPoint: .leading,
              endPoint: .trailing
            ))
          Text("Unlimited drawings")
            .font(.system(size: 17.0, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.leading)
        }
        HStack(alignment: .center) {
          Image(systemName: "icloud")
            .font(.system(size: 17.0, weight: .bold))
            .foregroundStyle(LinearGradient(
              gradient: Gradient(colors: [Color.blue, Color.white]),
              startPoint: .leading,
              endPoint: .trailing
            ))
          Text("Save in iCloud")
            .font(.system(size: 17.0, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.leading)
        }
        HStack(alignment: .center) {
          Image(systemName: "hands.and.sparkles")
            .font(.system(size: 17.0, weight: .bold))
            .foregroundStyle(LinearGradient(
              gradient: Gradient(colors: [Color.secondary, Color.white]),
              startPoint: .leading,
              endPoint: .trailing
            ))
          Text("Coming features")
            .font(.system(size: 17.0, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.leading)
        }
      }

      if subscriptionViewModel.hasPro {
        if subscriptionViewModel.purchasedTransactions.first?.productID == "com.easybreezy.touchdesk.lifetime" {
          Divider()
          Button(action: {
            showConfetti = true
          }, label: {
            Text("Confetti")
              .foregroundStyle(LinearGradient(
                gradient: Gradient(colors: [Color.orange, Color.pink, Color.purple]),
                startPoint: .leading,
                endPoint: .trailing
              ))
              .font(.system(size: 17, weight: .semibold, design: .rounded))
              .frame(maxWidth: .infinity)
          })
          .overlay(ShimmerMask().clipShape(RoundedRectangle(cornerRadius: 32)))
        } else {
          Divider()
          Button(action: {
            manageSubscription()
          }, label: {
            Text("Manage Subscription")
              .foregroundStyle(.white)
              .font(.system(size: 17, weight: .semibold, design: .rounded))
              .frame(maxWidth: .infinity)
          })
        }
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
          .opacity(subscriptionViewModel.hasPro ? 1 : 0)
      }
      Spacer(minLength: 0)
    }
  }

  private var productsListView: some View {
    VStack {
      ForEach(subscriptionViewModel.products, id: \.self) { product in
        SubscriptionItemView(product: product, purchasing: subscriptionViewModel.purchasing, selectedProduct: $selectedProduct)
      }
    }
    .disabled(subscriptionViewModel.purchasing)
  }

  private var purchaseSection: some View {
    VStack(alignment: .center, spacing: 4) {
      PurchaseButtonView(selectedProduct: $selectedProduct, subscriptionViewModel: subscriptionViewModel)
      Button("Restore Purchases") {
        Task {
          await subscriptionViewModel.restorePurchases()
        }
      }
      .font(.caption)
      .buttonStyle(.borderless)
    }
    .disabled(subscriptionViewModel.purchasing)
  }
}

struct SubscriptionItemView: View {
  var product: Product
  var purchasing: Bool
  @Binding var selectedProduct: Product?

  func planDescribe(_ product: Product) -> String? {
    switch product.id {
    case "com.easybreezy.touchdesk.lifetime": return NSLocalizedString("One-time purchase, no subscription", comment: "")
    case "com.easybreezy.touchdesk.yearly.subscription": return NSLocalizedString("Save 42% compared to monthly - cancel anytime", comment: "")
    case "com.easybreezy.touchdesk.monthly.subscription": return NSLocalizedString("Cancel anytime", comment: "")
    default: return nil
    }
  }

  func planRenewCircle(_ product: Product) -> String? {
    switch product.id {
    case "com.easybreezy.touchdesk.lifetime": return nil
    case "com.easybreezy.touchdesk.yearly.subscription": return NSLocalizedString("/yr", comment: "")
    case "com.easybreezy.touchdesk.monthly.subscription": return NSLocalizedString("/mo", comment: "")
    default: return nil
    }
  }

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .bottom, spacing: 8) {
          Text("\(product.displayName)")
            .font(.system(size: 16.0, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.leading)
          if product.id == "com.easybreezy.touchdesk.lifetime" {
            HStack(spacing: 4) {
              Text("\(product.displayPrice)")
                .font(.system(size: 16.0, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
              Text("\(product.displayPrice.removePriceNumbers())\(String(format: "%.2f", Double(truncating: product.price as NSNumber) / 0.5))")
                .font(.system(size: 12.0, weight: .regular, design: .rounded))
                .strikethrough()
            }
          } else {
            Text("\(product.displayPrice)\(planRenewCircle(product) ?? "")")
              .font(.system(size: 16.0, weight: .semibold, design: .rounded))
              .multilineTextAlignment(.leading)
          }
        }
        if let describe = planDescribe(product) {
          Text(describe)
            .font(.system(size: 14.0, weight: .regular, design: .rounded))
            .multilineTextAlignment(.leading)
        }
      }
      Spacer()
      Image(systemName: selectedProduct == product ? "checkmark.circle.fill" : "circle")
        .foregroundColor(selectedProduct == product ? .white : .white)
    }

    .padding(.horizontal, 20)
    .padding(.vertical, 20)
    .background(selectedProduct == product ? .white.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 24))
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 24))
    .opacity(purchasing ? 0.6 : 1)
    .contentShape(RoundedRectangle(cornerRadius: 24))
    .hoverEffect(.highlight)
    .overlay(offLogo)
    .onTapGesture {
      AudioServicesPlaySystemSound(1104)
      selectedProduct = product
    }
  }

  @MainActor
  @ViewBuilder
  private var offLogo: some View {
    VStack {
      HStack {
        Spacer(minLength: 0)
        Text("50% OFF")
          .font(.system(size: 16, weight: .bold, design: .rounded))
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .background(RoundedRectangle(cornerRadius: 12).foregroundStyle(.red.opacity(0.8)))
          .background(RoundedRectangle(cornerRadius: 12).foregroundStyle(LinearGradient(
            gradient: Gradient(colors: [Color.white, Color.purple, Color.orange]),
            startPoint: .leading,
            endPoint: .trailing
          )))
          .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
          .overlay(ShimmerMask().clipShape(RoundedRectangle(cornerRadius: 12)))
          .overlay(sparklesOverlay().offset(x: 20))
          .rotationEffect(.degrees(8))
          .offset(z: 16)
          .offset(x: 12, y: -12)
          .opacity(product.id == "com.easybreezy.touchdesk.lifetime" ? 1 : 0)
      }
      Spacer(minLength: 0)
    }
  }
}

// MARK: Subscription Item

struct PurchaseButtonView: View {
  @Environment(\.purchase) var purchase
  @Binding var selectedProduct: Product?
  var subscriptionViewModel: SubscriptionViewModel

  var body: some View {
    Button(action: {
      if let selectedProduct = selectedProduct {
        Task {
          await subscriptionViewModel.buyProduct(selectedProduct, purchase: purchase)
        }
      } else {
        print("Please select a product before purchasing.")
      }
    }) {
      HStack {
        Text("Purchase")
          .foregroundStyle(.white)
          .font(.system(size: 17, weight: .semibold, design: .rounded))
      }
      .frame(maxWidth: .infinity)
    }
    .disabled(selectedProduct == nil)
  }
}

#Preview(body: {
  NavigationStack {
    SubscriptionView()
      .environment(SubscriptionViewModel())
      .padding(.top, 64)
  }
  .frame(width: 480, height: 740)
})

extension String {
    func removePriceNumbers() -> String {
        let pattern = "\\d+([.,]\\d+)?"
        return self.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
}
