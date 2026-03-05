import Foundation

// MARK: - 余额查询逻辑

func fetchBalance(for account: SiteAccount, password: String) async -> AccountResult {
    var result = AccountResult(account: account, status: .loading)
    do {
        var token = try await APIService.login(
            siteURL: account.siteURL,
            email: account.email,
            password: password
        )

        do {
            let data = try await loadData(siteURL: account.siteURL, token: token)
            result.balance = data.balance
            result.subscriptions = data.subscriptions
        } catch APIError.tokenExpired {
            token = try await APIService.login(
                siteURL: account.siteURL,
                email: account.email,
                password: password
            )
            let data = try await loadData(siteURL: account.siteURL, token: token)
            result.balance = data.balance
            result.subscriptions = data.subscriptions
        }
        result.status = .success
    } catch {
        result.status = .error
        result.errorMessage = error.localizedDescription
    }
    return result
}

private func loadData(siteURL: String, token: String) async throws -> (balance: Double, subscriptions: [SubscriptionDetail]) {
    async let userInfo = APIService.fetchUserInfo(siteURL: siteURL, token: token)
    async let items = APIService.fetchProgress(siteURL: siteURL, token: token)

    let balance = try await userInfo.balance
    let progressItems = try await items
    let subs = progressItems.compactMap { item -> SubscriptionDetail? in
        guard let p = item.progress else { return nil }
        return SubscriptionDetail(
            groupName: p.group_name,
            expiresInDays: p.expires_in_days,
            daily: p.daily.map { .init(limitUSD: $0.limit_usd, usedUSD: $0.used_usd, remainingUSD: $0.remaining_usd, percentage: $0.percentage) },
            weekly: p.weekly.map { .init(limitUSD: $0.limit_usd, usedUSD: $0.used_usd, remainingUSD: $0.remaining_usd, percentage: $0.percentage) },
            monthly: p.monthly.map { .init(limitUSD: $0.limit_usd, usedUSD: $0.used_usd, remainingUSD: $0.remaining_usd, percentage: $0.percentage) }
        )
    }
    return (balance, subs)
}
