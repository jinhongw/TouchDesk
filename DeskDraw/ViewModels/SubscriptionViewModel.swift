//
//  SubscriptionViewModel.swift
//  DeskDraw
//
//  Created by jinhong on 2025/1/13.
//

import StoreKit
import SwiftUI

@MainActor
@Observable
class SubscriptionViewModel {
  static let hasProIndexKey = "hasPro"
  let productIDs: [String] = ["com.easybreezy.touchdesk.lifetime", "com.easybreezy.touchdesk.yearly.subscription", "com.easybreezy.touchdesk.monthly.subscription"] // TODO: Replace with your own product ids
  var products: [Product] = []
  var purchasedTransactions: [StoreKit.Transaction] = []
  var hasPro: Bool = false
  var purchasing: Bool = false
  var showNeedCancelSubscription: Bool = false

  private var updates: Task<Void, Never>?

  init() {
    loadUserDefaults()
    updates = observeTransactionUpdates()
  }

  func observeTransactionUpdates() -> Task<Void, Never> {
    Task { [unowned self] in
      for await _ in Transaction.updates {
        await self.updatePurchasedProducts()
      }
    }
  }
}

extension SubscriptionViewModel {
  func loadUserDefaults() {
    if let hasProUserDefault = UserDefaults.standard.value(forKey: SubscriptionViewModel.hasProIndexKey) as? Bool {
      logger.info("\(#function) hasProUserDefault \(hasProUserDefault)")
      hasPro = hasProUserDefault
    } else {
      logger.info("\(#function) false")
      hasPro = false
    }
  }

  func loadProducts() async {
    do {
      products = try await Product.products(for: productIDs)
        .sorted(by: { $0.price > $1.price })
    } catch {
      logger.info("\(#function) Failed to fetch products!")
    }
  }

  func checkPurchaseLifetimeAvailable() async -> Bool {
    print(#function, "DEBUG \(purchasedTransactions)")
    for await result in Transaction.currentEntitlements {
      print(#function, "DEBUG \(result)")
      guard case let .verified(transaction) = result else {
        continue
      }
      if let revocationDate = transaction.revocationDate, revocationDate < Date() {
        purchasedTransactions = purchasedTransactions.filter { $0.productID != transaction.productID }
      } else {
        purchasedTransactions = purchasedTransactions.filter { $0.productID != transaction.productID }
        purchasedTransactions.append(transaction)
      }
    }
    if purchasedTransactions.contains(where: { $0.productID.contains("subscription") }) {
      return false
    } else {
      return true
    }
  }

  func buyProduct(_ product: Product, purchase: PurchaseAction) async {
    do {
      if product.id == "com.easybreezy.touchdesk.lifetime" {
        if await !checkPurchaseLifetimeAvailable() {
          showNeedCancelSubscription = true
          return
        }
      }

      let result = try await purchase(product)
      print(#function, "DEBUG \(result)")
      switch result {
      case let .success(.verified(transaction)):
        purchasing = true
        // Successful purhcase
        await transaction.finish()
        await updatePurchasedProducts()
      case let .success(.unverified(_, error)):
        // Successful purchase but transaction/receipt can't be verified
        // Could be a jailbroken phone
        purchasing = false
        logger.info("\(#function) Unverified purchase. Might be jailbroken. Error: \(error.localizedDescription)")
      case .pending:
        // Transaction waiting on SCA (Strong Customer Authentication) or
        // approval from Ask to Buy
        purchasing = false
      case .userCancelled:
        // ^^^
        logger.info("\(#function) User Cancelled!")
        purchasing = false
        break
      @unknown default:
        logger.info("\(#function) Failed to purchase the product!")
        purchasing = false
      }
    } catch {
      logger.info("\(#function) Failed to purchase the product!")
      purchasing = false
    }
  }

  func updatePurchasedProducts() async {
    for await result in Transaction.currentEntitlements {
      logger.info("\(#function) \(result.debugDescription)")
      guard case let .verified(transaction) = result else {
        continue
      }
      if let revocationDate = transaction.revocationDate, revocationDate < Date() {
        purchasedTransactions = purchasedTransactions.filter { $0.productID != transaction.productID }
      } else {
        purchasedTransactions = purchasedTransactions.filter { $0.productID != transaction.productID }
        purchasedTransactions.append(transaction)
      }
    }
    logger.info("\(#function) purchasedTransactions \(self.purchasedTransactions.debugDescription)")
    purchasing = false
    hasPro = !purchasedTransactions.isEmpty
    UserDefaults.standard.set(!purchasedTransactions.isEmpty, forKey: SubscriptionViewModel.hasProIndexKey)
  }

  func restorePurchases() async {
    do {
      try await AppStore.sync()
      logger.info("\(#function) AppStore sync success")
    } catch {
      logger.info("\(#function) \(error.localizedDescription)")
    }
  }
}
