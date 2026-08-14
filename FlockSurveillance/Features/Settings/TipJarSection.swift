import StoreKit
import SwiftUI

struct TipJarSection: View {
    @State private var store = TipJarStore()

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(TipJarCopy.eyebrow)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.mutedForeground)

                Text(TipJarCopy.body)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.mutedForeground)

                if store.phase == .unavailable {
                    Text(TipJarCopy.unavailable)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.mutedForeground)
                } else if !store.products.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            ForEach(store.products, id: \.id) { product in
                                tipButton(product)
                            }
                        }
                        VStack(spacing: 8) {
                            ForEach(store.products, id: \.id) { product in
                                tipButton(product)
                            }
                        }
                    }
                    .disabled(store.phase == .purchasing || store.phase == .loading)
                    .opacity(store.phase == .purchasing ? 0.55 : 1)
                }

                statusLine
            }
        }
        .task {
            await store.load()
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch store.phase {
        case .thankYou:
            Text(TipJarCopy.thankYou)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.accent)
        case .failed(let message):
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.primary)
        case .purchasing:
            Text(TipJarCopy.working)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
        default:
            EmptyView()
        }
    }

    private func tipButton(_ product: Product) -> some View {
        Button {
            Task { await store.purchase(product) }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 4) {
                Text(store.displayName(for: product))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.foreground)
                    .multilineTextAlignment(.center)
                Text(product.displayPrice)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(AppTheme.background.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(store.displayName(for: product)), \(product.displayPrice)")
    }
}
