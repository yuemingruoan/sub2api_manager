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
