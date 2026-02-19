import SwiftUI
import StoreKit

// MARK: - Paywall
// 3-day free trial | $5.99/mo or $49.99/yr (US) | £4.99/mo or £39.99/yr (UK)
struct PaywallView: View {
    @ObservedObject var subscription = SubscriptionService.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    let onDismiss: () -> Void

    @State private var selectedProduct: Product?
    @State private var isLoadingPurchase = false

    var body: some View {
        ZStack {
            themeManager.theme.paperBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer().frame(height: 40)

                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(Color.accentGold)

                    VStack(spacing: 8) {
                        Text("Keep going with Vaulted Pro")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundColor(themeManager.theme.inkPrimary)
                            .multilineTextAlignment(.center)

                        Text("Unlimited voice notes, transcripts, and ideas. Private and secure.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(themeManager.theme.inkMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)

                    // 3-day free trial badge
                    Text("Start your 3-day free trial")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.accentGold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.accentGold.opacity(0.15))
                        .clipShape(Capsule())

                    // Subscription options
                    if subscription.isLoading && subscription.products.isEmpty {
                        ProgressView()
                            .scaleEffect(1.2)
                            .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 12) {
                            if let yearly = subscription.yearlyProduct {
                                paywallOption(
                                    product: yearly,
                                    title: "Yearly",
                                    subtitle: "Save 30%",
                                    badge: "Best value",
                                    freeTrialText: "3 days free",
                                    isYearly: true
                                )
                            }
                            if let monthly = subscription.monthlyProduct {
                                paywallOption(
                                    product: monthly,
                                    title: "Monthly",
                                    subtitle: nil,
                                    badge: nil,
                                    freeTrialText: "3 days free",
                                    isYearly: false
                                )
                            }
                        }
                    .padding(.horizontal, 40)

                        // Subscribe button
                        Button {
                            Task {
                                guard let p = selectedProduct else { return }
                                isLoadingPurchase = true
                                let ok = await subscription.purchase(p)
                                isLoadingPurchase = false
                                if ok { onDismiss() }
                            }
                        } label: {
                            Text("Start 3-Day Free Trial")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(themeManager.theme.isDark ? themeManager.theme.inkPrimary : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Capsule().fill(Color.accentGold))
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedProduct == nil || isLoadingPurchase)
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                    }

                    if let err = subscription.purchaseError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    Button("Restore Purchases") {
                        Task { await subscription.restorePurchases() }
                        if subscription.hasAccess { onDismiss() }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeManager.theme.inkMuted)

                    Spacer().frame(height: 24)

                    // Terms & privacy
                    Text("By continuing, you agree to our Terms of Service and Privacy Policy.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(themeManager.theme.inkMuted.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }

            if isLoadingPurchase {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .onAppear {
            Task {
                await subscription.loadProducts()
                await MainActor.run {
                    selectedProduct = subscription.yearlyProduct ?? subscription.monthlyProduct
                }
            }
        }
        .onChange(of: subscription.isLoading) { isNowLoading in
            if !isNowLoading, selectedProduct == nil {
                selectedProduct = subscription.yearlyProduct ?? subscription.monthlyProduct
            }
        }
    }

    private func perMonthString(for product: Product) -> String? {
        let monthlyPrice = (product.price as NSDecimalNumber).doubleValue / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: monthlyPrice)).map { "\($0)/mo" }
    }

    private func paywallOption(product: Product, title: String, subtitle: String?, badge: String?, freeTrialText: String, isYearly: Bool) -> some View {
        let isSelected = selectedProduct?.id == product.id
        return Button {
            selectedProduct = product
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(themeManager.theme.inkPrimary)
                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentGold)
                                .clipShape(Capsule())
                        }
                    }
                    if let sub = subtitle {
                        Text(sub)
                            .font(.system(size: 13))
                            .foregroundColor(themeManager.theme.inkMuted)
                    }
                    Text(freeTrialText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.accentGold.opacity(0.9))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(themeManager.theme.inkPrimary)
                    if isYearly, let perMo = perMonthString(for: product) {
                        Text(perMo)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(themeManager.theme.inkMuted)
                    }
                }
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.accentGold)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(themeManager.theme.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.accentGold : themeManager.theme.borderMuted,
                                    lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
