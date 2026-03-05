import SwiftUI

struct SubscriptionRow: View {
    let detail: SubscriptionDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(detail.groupName)
                    .font(.subheadline.bold())
                Spacer()
                Text("剩余 \(detail.expiresInDays) 天")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                if let d = detail.daily {
                    windowLabel("日", window: d)
                }
                if let w = detail.weekly {
                    windowLabel("周", window: w)
                }
                if let m = detail.monthly {
                    windowLabel("月", window: m)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func windowLabel(_ period: String, window: UsageWindow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(period)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: "$%.2f / $%.2f", window.remainingUSD, window.limitUSD))
                .font(.caption.monospacedDigit())
            ProgressView(value: min(window.percentage, 100), total: 100)
                .tint(window.percentage > 80 ? .red : .blue)
        }
        .frame(minWidth: 120)
    }
}
