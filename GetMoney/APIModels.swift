import Foundation

// MARK: - API 响应结构（匹配 sub2api）

struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
}

struct AuthResponseData: Decodable {
    let access_token: String
    let token_type: String
}

struct ProgressItem: Decodable {
    let subscription: SubscriptionDTO?
    let progress: ProgressDTO?
}

struct SubscriptionDTO: Decodable {
    let id: Int64
    let group_id: Int64
    let status: String
    let expires_at: String?
    let group: GroupDTO?
}

struct GroupDTO: Decodable {
    let name: String?
}

struct ProgressDTO: Decodable {
    let id: Int64?
    let group_name: String
    let expires_in_days: Int
    let daily: UsageWindowDTO?
    let weekly: UsageWindowDTO?
    let monthly: UsageWindowDTO?
}

struct UsageWindowDTO: Decodable {
    let limit_usd: Double
    let used_usd: Double
    let remaining_usd: Double
    let percentage: Double
}

struct RedeemResultDTO: Decodable {
    let id: Int64?
    let code: String?
    let type: String?
    let value: Double?
    let status: String?
    let group_id: Int64?
    let validity_days: Int?
    let group: GroupDTO?
}

struct UserInfoDTO: Decodable {
    let id: Int64
    let email: String
    let username: String?
    let balance: Double
}
