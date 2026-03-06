import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case loginFailed(String)
    case requestFailed(String)
    case tokenExpired

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的站点 URL"
        case .loginFailed(let msg): return "登录失败: \(msg)"
        case .requestFailed(let msg): return "请求失败: \(msg)"
        case .tokenExpired: return "登录态已过期"
        }
    }
}

struct APIService {

    // MARK: - 认证与基础信息

    static func login(siteURL: String, email: String, password: String) async throws -> String {
        let url = try buildURL(siteURL, path: "/api/v1/auth/login")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "email": email,
            "password": password,
            "turnstile_token": ""
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let resp = try JSONDecoder().decode(APIResponse<AuthResponseData>.self, from: data)

        guard resp.code == 0, let token = resp.data?.access_token else {
            throw APIError.loginFailed(resp.message)
        }
        return token
    }

    static func fetchProgress(siteURL: String, token: String) async throws -> [ProgressItem] {
        let url = try buildURL(siteURL, path: "/api/v1/subscriptions/progress")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkUnauthorized(response)
        let resp = try JSONDecoder().decode(APIResponse<[ProgressItem]>.self, from: data)

        guard resp.code == 0, let items = resp.data else {
            throw APIError.requestFailed(resp.message)
        }
        return items
    }

    static func fetchUserInfo(siteURL: String, token: String) async throws -> UserInfoDTO {
        let url = try buildURL(siteURL, path: "/api/v1/auth/me")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkUnauthorized(response)
        let resp = try JSONDecoder().decode(APIResponse<UserInfoDTO>.self, from: data)

        guard resp.code == 0, let info = resp.data else {
            throw APIError.requestFailed(resp.message)
        }
        return info
    }

    static func redeem(siteURL: String, token: String, code: String) async throws -> RedeemResultDTO {
        let url = try buildURL(siteURL, path: "/api/v1/redeem")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["code": code])

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkUnauthorized(response)
        let resp = try JSONDecoder().decode(APIResponse<RedeemResultDTO>.self, from: data)

        guard resp.code == 0, let result = resp.data else {
            throw APIError.requestFailed(resp.message)
        }
        return result
    }

    // MARK: - API Key 相关接口（普通用户）

    /// 获取当前用户的 API Key 列表（/api/v1/keys）
    static func fetchAPIKeys(
        siteURL: String,
        token: String,
        page: Int = 1,
        pageSize: Int = 50,
        search: String? = nil,
        status: String? = nil,
        groupID: Int64? = nil
    ) async throws -> PaginatedResponse<APIKeyDTO> {
        let baseURL = try buildURL(siteURL, path: "/api/v1/keys")
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        var items: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]
        if let search, !search.isEmpty {
            items.append(URLQueryItem(name: "search", value: search))
        }
        if let status, !status.isEmpty {
            items.append(URLQueryItem(name: "status", value: status))
        }
        if let groupID {
            items.append(URLQueryItem(name: "group_id", value: String(groupID)))
        }
        components.queryItems = items

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkUnauthorized(response)

        let resp = try JSONDecoder().decode(APIResponse<PaginatedResponse<APIKeyDTO>>.self, from: data)
        guard resp.code == 0, let pageData = resp.data else {
            throw APIError.requestFailed(resp.message)
        }
        return pageData
    }

    /// 创建 API Key（/api/v1/keys）
    static func createAPIKey(
        siteURL: String,
        token: String,
        body: APIKeyCreateRequest
    ) async throws -> APIKeyDTO {
        let url = try buildURL(siteURL, path: "/api/v1/keys")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkUnauthorized(response)

        let resp = try JSONDecoder().decode(APIResponse<APIKeyDTO>.self, from: data)
        guard resp.code == 0, let key = resp.data else {
            throw APIError.requestFailed(resp.message)
        }
        return key
    }

    /// 更新 API Key（/api/v1/keys/:id）
    static func updateAPIKey(
        siteURL: String,
        token: String,
        id: Int64,
        body: APIKeyUpdateRequest
    ) async throws -> APIKeyDTO {
        let url = try buildURL(siteURL, path: "/api/v1/keys/\(id)")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkUnauthorized(response)

        let resp = try JSONDecoder().decode(APIResponse<APIKeyDTO>.self, from: data)
        guard resp.code == 0, let key = resp.data else {
            throw APIError.requestFailed(resp.message)
        }
        return key
    }

    /// 删除 API Key（/api/v1/keys/:id）
    static func deleteAPIKey(
        siteURL: String,
        token: String,
        id: Int64
    ) async throws {
        let url = try buildURL(siteURL, path: "/api/v1/keys/\(id)")

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkUnauthorized(response)

        let resp = try JSONDecoder().decode(APIResponse<EmptyData>.self, from: data)
        guard resp.code == 0 else {
            throw APIError.requestFailed(resp.message)
        }
    }

    /// 获取可绑定的分组列表（/api/v1/groups/available）
    static func fetchAvailableGroups(
        siteURL: String,
        token: String
    ) async throws -> [APIGroupDTO] {
        let url = try buildURL(siteURL, path: "/api/v1/groups/available")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkUnauthorized(response)

        let resp = try JSONDecoder().decode(APIResponse<[APIGroupDTO]>.self, from: data)
        guard resp.code == 0, let groups = resp.data else {
            throw APIError.requestFailed(resp.message)
        }
        return groups
    }

    /// 获取当前用户的专属分组倍率配置（/api/v1/groups/rates）
    static func fetchUserGroupRates(
        siteURL: String,
        token: String
    ) async throws -> GroupRatesDTO {
        let url = try buildURL(siteURL, path: "/api/v1/groups/rates")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkUnauthorized(response)

        let resp = try JSONDecoder().decode(APIResponse<GroupRatesDTO>.self, from: data)
        guard resp.code == 0, let rates = resp.data else {
            throw APIError.requestFailed(resp.message)
        }
        return rates
    }

    // MARK: - 内部工具

    private static func buildURL(_ base: String, path: String) throws -> URL {
        let trimmed = base.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: trimmed + path) else {
            throw APIError.invalidURL
        }
        return url
    }

    private static func checkUnauthorized(_ response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw APIError.tokenExpired
        }
    }
}
