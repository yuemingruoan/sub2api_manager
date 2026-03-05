import Foundation

// MARK: - 本地账号模型

struct SiteAccount: Codable, Identifiable {
    var id = UUID()
    var siteURL: String
    var email: String
}

// MARK: - 账号查询结果

struct AccountResult: Identifiable {
    let id = UUID()
    let account: SiteAccount
    var status: ResultStatus = .idle
    var balance: Double?
    var subscriptions: [SubscriptionDetail] = []
    var errorMessage: String?
}

enum ResultStatus {
    case idle, loading, success, error
}

struct SubscriptionDetail: Identifiable {
    let id = UUID()
    let groupName: String
    let expiresInDays: Int
    let daily: UsageWindow?
    let weekly: UsageWindow?
    let monthly: UsageWindow?
}

struct UsageWindow {
    let limitUSD: Double
    let usedUSD: Double
    let remainingUSD: Double
    let percentage: Double
}
