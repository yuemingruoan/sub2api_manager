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

// MARK: - API Key 列表状态（按账号）

enum APIKeyListStatus: Equatable {
    case idle
    case loading
    case loaded
    case error
}

struct APIKeyListState {
    var status: APIKeyListStatus = .idle
    var items: [APIKeyDTO] = []
    var errorMessage: String?
    var isCreating: Bool = false
    var groups: [APIGroupDTO] = []
    var groupRates: GroupRatesDTO?
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
