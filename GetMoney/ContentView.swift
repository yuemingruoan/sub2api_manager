import SwiftUI

struct ContentView: View {
    @StateObject private var store = AccountStore()
    @State private var results: [UUID: AccountResult] = [:]
    @State private var showAddSheet = false
    @State private var isRefreshing = false
    @State private var redeemAccount: SiteAccount?

    var body: some View {
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
                            onRedeem: { redeemAccount = account },
                            onDelete: {
                                withAnimation { store.remove(account) }
                                results[account.id] = nil
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .task { await refreshAll() }
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
}
