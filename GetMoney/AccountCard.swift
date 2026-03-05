import SwiftUI

struct AccountCard: View {
    let account: SiteAccount
    let result: AccountResult?
    var onRedeem: () -> Void
    var onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            Divider()
            cardBody
            Divider()
            cardFooter
        }
        .padding(4)
        .contentShape(Rectangle())
        .glassEffect(in: .rect(cornerRadius: 16))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(
            color: .accentColor.opacity(isHovered ? 0.18 : 0),
            radius: isHovered ? 12 : 0,
            y: isHovered ? 4 : 0
        )
        .animation(.smooth(duration: 0.25), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var cardHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.siteURL)
                    .font(.headline)
                    .lineLimit(1)
                Text(account.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            balanceView
        }
        .padding()
    }

    @ViewBuilder
    private var balanceView: some View {
        switch result?.status {
        case .loading:
            ProgressView().controlSize(.small)
        case .success:
            if let balance = result?.balance {
                Text(String(format: "$%.2f", balance))
                    .font(.title2.monospacedDigit().bold())
                    .foregroundStyle(balance > 0 ? .green : .red)
            }
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        default:
            Text("--")
                .font(.title2)
                .foregroundStyle(.quaternary)
        }
    }

    @ViewBuilder
    private var cardBody: some View {
        if let result, result.status == .success, !result.subscriptions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(result.subscriptions) { sub in
                    SubscriptionRow(detail: sub)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        } else if let msg = result?.errorMessage {
            Text(msg)
                .font(.caption)
                .foregroundStyle(.red)
                .padding()
        }
    }

    private var cardFooter: some View {
        HStack {
            Button("兑换卡密", action: onRedeem)
                .buttonStyle(.glass)
            Spacer()
            Button("删除", role: .destructive, action: onDelete)
                .buttonStyle(.glass)
                .tint(.red)
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview("有余额") {
    let account = SiteAccount(siteURL: "https://api.example.com", email: "test@example.com")
    let result = AccountResult(
        account: account,
        status: .success,
        balance: 503.55,
        subscriptions: [
            SubscriptionDetail(
                groupName: "Claude Pro",
                expiresInDays: 28,
                daily: UsageWindow(limitUSD: 5.0, usedUSD: 1.2, remainingUSD: 3.8, percentage: 24),
                weekly: UsageWindow(limitUSD: 30.0, usedUSD: 12.5, remainingUSD: 17.5, percentage: 41.7),
                monthly: nil
            )
        ]
    )
    AccountCard(account: account, result: result, onRedeem: {}, onDelete: {})
        .frame(width: 500)
        .padding()
}