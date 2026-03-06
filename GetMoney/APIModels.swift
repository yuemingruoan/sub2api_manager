import Foundation

// MARK: - API 响应结构（匹配 sub2api）

struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
}

/// 通用分页结构：data 为 PaginatedResponse<T>
struct PaginatedResponse<Item: Decodable>: Decodable {
    let items: [Item]
    let total: Int
    let page: Int
    let page_size: Int
    let pages: Int
}

/// 用于 data 不关心内容的简单场景（例如删除）
struct EmptyData: Decodable {}

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

// MARK: - API Key 相关 DTO（普通用户接口）

struct APIKeyDTO: Decodable, Identifiable {
    let id: Int64
    let key: String
    let name: String
    let status: String
    let group_id: Int64?

    // 配额信息
    let quota: Double
    let quota_used: Double
    let expires_at: String?

    // 基本元数据
    let created_at: String
    let updated_at: String

    // 关联分组（可选，仅部分接口会返回）
    let group: APIGroupDTO?
}

struct APIGroupDTO: Decodable, Identifiable {
    let id: Int64
    let name: String
    let description: String?
    let platform: String
    let rate_multiplier: Double
    let subscription_type: String
    let daily_limit_usd: Double?
    let weekly_limit_usd: Double?
    let monthly_limit_usd: Double?
}

/// 用户专属分组倍率配置：key 为字符串形式的 group_id
typealias GroupRatesDTO = [String: Double]

// MARK: - API Key 请求体

struct APIKeyCreateRequest: Encodable {
    var name: String
    var group_id: Int64?
    var custom_key: String?
    var ip_whitelist: [String] = []
    var ip_blacklist: [String] = []
    var quota: Double?
    var expires_in_days: Int?
    var rate_limit_5h: Double?
    var rate_limit_1d: Double?
    var rate_limit_7d: Double?
}

struct APIKeyUpdateRequest: Encodable {
    var name: String?
    var group_id: Int64?
    var status: String?
    var ip_whitelist: [String] = []
    var ip_blacklist: [String] = []
    var quota: Double?
    var expires_at: String?
    var reset_quota: Bool?
    var rate_limit_5h: Double?
    var rate_limit_1d: Double?
    var rate_limit_7d: Double?
    var reset_rate_limit_usage: Bool?
}
