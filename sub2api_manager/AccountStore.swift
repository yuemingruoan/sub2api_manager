import Foundation

/// 沙盒合规的账号持久化：
/// - 账号元数据（URL、邮箱）存储在 Application Support 目录的 JSON 文件中
/// - 密码存储在 Keychain 中
class AccountStore: ObservableObject {
    @Published var accounts: [SiteAccount] = []

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("GetMoney", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("accounts.json")
        load()
    }

    func add(_ account: SiteAccount, password: String) {
        accounts.append(account)
        KeychainHelper.save(password: password, for: account.id.uuidString)
        save()
    }

    func remove(_ account: SiteAccount) {
        accounts.removeAll { $0.id == account.id }
        KeychainHelper.delete(for: account.id.uuidString)
        save()
    }

    func password(for account: SiteAccount) -> String {
        KeychainHelper.load(for: account.id.uuidString) ?? ""
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([SiteAccount].self, from: data)
        else { return }
        accounts = saved
    }
}
