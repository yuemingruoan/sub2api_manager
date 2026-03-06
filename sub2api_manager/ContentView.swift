import SwiftUI

struct ContentView: View {
    @StateObject private var store = AccountStore()
    @State private var results: [UUID: AccountResult] = [:]
    @State private var apiKeyStates: [UUID: APIKeyListState] = [:]
    @State private var tokens: [UUID: String] = [:]
    @State private var showAddSheet = false
    @State private var isRefreshing = false
    @State private var redeemAccount: SiteAccount?

    var body: some View {
        ZStack {
            // 全局背景渐变，确保在全屏模式下也生效
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.93, green: 0.97, blue: 1.0),
                    Color(red: 0.98, green: 0.99, blue: 0.96)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            NavigationStack {
                Group {
                    if store.accounts.isEmpty {
                        emptyState
                    } else {
                        accountGrid
                    }
                }
                .navigationTitle("GetMoney")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: 8) {
                            Button {
                                Task { await refreshAll() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .disabled(store.accounts.isEmpty || isRefreshing)

                            Button {
                                showAddSheet = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddAccountView { account, password in
                store.add(account, password: password)
            }
        }
        .sheet(item: $redeemAccount) { account in
            RedeemView(account: account, password: store.password(for: account))
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("暂无账号", systemImage: "person.crop.circle.badge.plus")
        } description: {
            Text("点击右上角 + 添加你的 sub2api 账号")
        } actions: {
            Button("添加账号") { showAddSheet = true }
                .buttonStyle(.glass)
        }
    }

    private var accountGrid: some View {
        ScrollView {
            GlassEffectContainer(spacing: 20) {
                LazyVStack(spacing: 16) {
                    ForEach(store.accounts) { account in
                        AccountCard(
                            account: account,
                            result: results[account.id],
                            apiKeyState: apiKeyStates[account.id] ?? APIKeyListState(),
                            onRedeem: { redeemAccount = account },
                            onDelete: {
                                withAnimation { store.remove(account) }
                                results[account.id] = nil
                                apiKeyStates[account.id] = nil
                            },
                            onLoadAPIKeys: {
                                Task { await loadAPIKeys(for: account) }
                            },
                            onCreateAPIKey: { request in
                                Task { await createAPIKey(for: account, request: request) }
                            },
                            onDeleteAPIKey: { apiKey in
                                Task { await deleteAPIKey(for: account, apiKey: apiKey) }
                            },
                            onUpdateAPIKey: { apiKey, request in
                                Task { await updateAPIKey(for: account, apiKey: apiKey, request: request) }
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .task {
            await refreshAll()
            await preloadAPIKeys()
        }
    }

    // MARK: - API Key 管理

    private func apiKeyState(for account: SiteAccount) -> APIKeyListState {
        apiKeyStates[account.id] ?? APIKeyListState()
    }

    private func updateAPIKeyState(for account: SiteAccount, _ update: (inout APIKeyListState) -> Void) {
        var state = apiKeyStates[account.id] ?? APIKeyListState()
        update(&state)
        apiKeyStates[account.id] = state
    }

    private func loadAPIKeys(for account: SiteAccount) async {
        // 避免重复请求：如果当前已在加载或已加载，则直接返回
        if let state = apiKeyStates[account.id],
           state.status == .loading || state.status == .loaded {
            return
        }

        updateAPIKeyState(for: account) { state in
            state.status = .loading
            state.errorMessage = nil
        }
        do {
            let (page, groups, rates) = try await callWithFreshToken(for: account) { token in
                async let pageTask = APIService.fetchAPIKeys(
                    siteURL: account.siteURL,
                    token: token
                )
                async let groupsTask = APIService.fetchAvailableGroups(
                    siteURL: account.siteURL,
                    token: token
                )
                async let ratesTask = APIService.fetchUserGroupRates(
                    siteURL: account.siteURL,
                    token: token
                )

                let page = try await pageTask
                let groups = try await groupsTask
                let rates = try await ratesTask
                return (page, groups, rates)
            }

            updateAPIKeyState(for: account) { state in
                state.status = .loaded
                state.items = page.items
                 state.groups = groups
                 state.groupRates = rates
                state.errorMessage = nil
            }
        } catch {
            updateAPIKeyState(for: account) { state in
                state.status = .error
                state.errorMessage = error.localizedDescription
            }
        }
    }

    /// 预加载所有账号的 API Key 列表（只在尚未加载时触发）
    private func preloadAPIKeys() async {
        let accounts = store.accounts
        await withTaskGroup(of: Void.self) { group in
            for account in accounts {
                let state = apiKeyStates[account.id]
                guard state == nil || state?.status == .idle else { continue }
                group.addTask {
                    await loadAPIKeys(for: account)
                }
            }
        }
    }

    private func createAPIKey(for account: SiteAccount, request: APIKeyCreateRequest) async {
        updateAPIKeyState(for: account) { state in
            state.isCreating = true
            state.errorMessage = nil
        }
        do {
            let created = try await callWithFreshToken(for: account) { token in
                try await APIService.createAPIKey(
                    siteURL: account.siteURL,
                    token: token,
                    body: request
                )
            }
            updateAPIKeyState(for: account) { state in
                state.isCreating = false
                state.status = .loaded
                state.items.insert(created, at: 0)
            }
        } catch {
            updateAPIKeyState(for: account) { state in
                state.isCreating = false
                state.status = .error
                state.errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteAPIKey(for account: SiteAccount, apiKey: APIKeyDTO) async {
        do {
            try await callWithFreshToken(for: account) { token in
                try await APIService.deleteAPIKey(
                    siteURL: account.siteURL,
                    token: token,
                    id: apiKey.id
                )
            }
            updateAPIKeyState(for: account) { state in
                state.items.removeAll { $0.id == apiKey.id }
                if state.items.isEmpty {
                    state.status = .loaded
                }
            }
        } catch {
            updateAPIKeyState(for: account) { state in
                state.status = .error
                state.errorMessage = error.localizedDescription
            }
        }
    }

    private func updateAPIKey(for account: SiteAccount, apiKey: APIKeyDTO, request: APIKeyUpdateRequest) async {
        do {
            let updated = try await callWithFreshToken(for: account) { token in
                try await APIService.updateAPIKey(
                    siteURL: account.siteURL,
                    token: token,
                    id: apiKey.id,
                    body: request
                )
            }
            updateAPIKeyState(for: account) { state in
                if let index = state.items.firstIndex(where: { $0.id == apiKey.id }) {
                    state.items[index] = updated
                }
                state.status = .loaded
                state.errorMessage = nil
            }
        } catch {
            updateAPIKeyState(for: account) { state in
                state.status = .error
                state.errorMessage = error.localizedDescription
            }
        }
    }

    private func refreshAll() async {
        isRefreshing = true
        let snapshot = store.accounts.map { ($0, store.password(for: $0)) }
        await withTaskGroup(of: AccountResult.self) { group in
            for (account, password) in snapshot {
                group.addTask {
                    await fetchBalance(for: account, password: password)
                }
            }
            for await result in group {
                results[result.account.id] = result
            }
        }
        isRefreshing = false
    }

    // MARK: - Token 缓存与自动刷新

    private func callWithFreshToken<T>(
        for account: SiteAccount,
        operation: @escaping (String) async throws -> T
    ) async throws -> T {
        let password = store.password(for: account)

        func login() async throws -> String {
            let token = try await APIService.login(
                siteURL: account.siteURL,
                email: account.email,
                password: password
            )
            tokens[account.id] = token
            return token
        }

        var token = tokens[account.id]
        if token == nil {
            token = try await login()
        }

        do {
            return try await operation(token!)
        } catch APIError.tokenExpired {
            let newToken = try await login()
            return try await operation(newToken)
        }
    }
}
