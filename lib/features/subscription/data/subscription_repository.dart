class SubscriptionRepository {
  Future<bool> checkSubscriptionStatus() async {
    // TODO: Verify receipt with backend
    return true;
  }

  Future<void> purchaseSubscription(String productId) async {
    // TODO: Integreate with store_kit / in_app_purchase
  }

  Future<void> restorePurchases() async {
    // TODO: Restore
  }
}
