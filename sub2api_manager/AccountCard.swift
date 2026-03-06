import SwiftUI
import AppKit

struct AccountCard: View {
    let account: SiteAccount
    let result: AccountResult?
    let apiKeyState: APIKeyListState
    var onRedeem: () -> Void
    var onDelete: () -> Void
    var onLoadAPIKeys: () -> Void
    var onCreateAPIKey: (APIKeyCreateRequest) -> Void
    var onDeleteAPIKey: (APIKeyDTO) -> Void
    var onUpdateAPIKey: (APIKeyDTO, APIKeyUpdateRequest) -> Void

    @State private var isHovered = false
    @State private var isAPIKeysExpanded = false
    @State private var newAPIKeyName = ""
    @State private var selectedGroupID: Int64?
    @State private var editingKeyID: Int64?
    @State private var editingName: String = ""
    @State private var editingGroupID: Int64?
    @State private var editingStatusActive: Bool = true
    @State private var editingQuotaText: String = ""
    @State private var pendingDeleteKey: APIKeyDTO?

    var body: some View {
        ZStack {
            // 背景玻璃卡片，负责放大和阴影，不参与点击
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.clear)
                .glassEffect(in: .rect(cornerRadius: 16))
                .shadow(
                    color: .accentColor.opacity(isHovered ? 0.18 : 0),
                    radius: isHovered ? 12 : 0,
                    y: isHovered ? 4 : 0
                )
                .scaleEffect(isHovered ? 1.02 : 1.0)
                .animation(.smooth(duration: 0.25), value: isHovered)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                cardHeader
                Divider()
                cardBody
                apiKeySection
                Divider()
                cardFooter
            }
            .padding(4)
            .contentShape(Rectangle())
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .alert(item: $pendingDeleteKey) { key in
            Alert(
                title: Text("删除 API Key"),
                message: Text("确定要删除 “\(key.name)” 吗？此操作不可恢复。"),
                primaryButton: .destructive(Text("删除")) {
                    onDeleteAPIKey(key)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var cardHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.siteURL)
                    .font(.headline)
                    .lineLimit(1)
                Text(account.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            balanceView
        }
        .padding()
    }

    @ViewBuilder
    private var balanceView: some View {
        switch result?.status {
        case .loading:
            ProgressView().controlSize(.small)
        case .success:
            if let balance = result?.balance {
                Text(String(format: "$%.2f", balance))
                    .font(.title2.monospacedDigit().bold())
                    .foregroundStyle(balance > 0 ? .green : .red)
            }
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        default:
            Text("--")
                .font(.title2)
                .foregroundStyle(.quaternary)
        }
    }

    @ViewBuilder
    private var cardBody: some View {
        if let result, result.status == .success, !result.subscriptions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(result.subscriptions) { sub in
                    SubscriptionRow(detail: sub)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        } else if let msg = result?.errorMessage {
            Text(msg)
                .font(.caption)
                .foregroundStyle(.red)
                .padding()
        }
    }

    @ViewBuilder
    private var apiKeySection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.smooth(duration: 0.2)) {
                    isAPIKeysExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("API Key 管理")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(isAPIKeysExpanded ? .degrees(180) : .degrees(0))
                        .animation(.smooth(duration: 0.2), value: isAPIKeysExpanded)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            if isAPIKeysExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    switch apiKeyState.status {
                    case .idle:
                        Text("展开后将加载该账号下的 API Key 列表")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .loading:
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("正在加载 API Key...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    case .loaded:
                        if apiKeyState.items.isEmpty {
                            Text("暂无 API Key")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(apiKeyState.items) { key in
                                HStack(alignment: .top, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(key.name)
                                            .font(.subheadline)
                                        Text(truncatedKey(key.key))
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                        HStack(spacing: 8) {
                                            Text(key.status)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            if let groupName = key.group?.name {
                                                Text(groupName)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Button {
                                            toggleEdit(for: key)
                                        } label: {
                                            Text("编辑")
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                        }
                                        .buttonStyle(.borderless)
                                        .contentShape(Rectangle())

                                        Button {
                                            copyToPasteboard(key.key)
                                        } label: {
                                            Text("复制")
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                        }
                                        .buttonStyle(.borderless)
                                        .contentShape(Rectangle())

                                        Button(role: .destructive) {
                                            pendingDeleteKey = key
                                        } label: {
                                            Image(systemName: "trash")
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                        }
                                        .buttonStyle(.borderless)
                                        .contentShape(Rectangle())
                                    }
                                }
                                .padding(.vertical, 2)

                                if editingKeyID == key.id {
                                    editForm(for: key)
                                }
                            }
                        }
                    case .error:
                        if let msg = apiKeyState.errorMessage, !msg.isEmpty {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else {
                            Text("加载 API Key 时发生错误")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    Divider().padding(.vertical, 4)

                    HStack(spacing: 8) {
                        TextField("新建 API Key 名称", text: $newAPIKeyName)
                            .textFieldStyle(.roundedBorder)
                        if !apiKeyState.groups.isEmpty {
                            Picker("分组", selection: $selectedGroupID) {
                                Text("不绑定分组").tag(Int64?.none)
                                ForEach(apiKeyState.groups) { group in
                                    Text(groupDisplayName(group))
                                        .tag(Int64?.some(group.id))
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 160)
                        }
                        if apiKeyState.isCreating {
                            ProgressView().controlSize(.small)
                        }
                        Button("生成") {
                            let name = newAPIKeyName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { return }
                            var request = APIKeyCreateRequest(name: name)
                            request.group_id = selectedGroupID
                            onCreateAPIKey(request)
                            newAPIKeyName = ""
                        }
                        .buttonStyle(.glass)
                        .disabled(apiKeyState.isCreating || newAPIKeyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .font(.caption)
                }
                .padding(12)
                .glassEffect(in: .rect(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 4)
                .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .onChange(of: isAPIKeysExpanded) { expanded in
            if expanded && apiKeyState.status == .idle {
                onLoadAPIKeys()
            }
        }
    }

    @ViewBuilder
    private func editForm(for key: APIKeyDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("编辑 API Key")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("名称", text: $editingName)
                .textFieldStyle(.roundedBorder)

            if !apiKeyState.groups.isEmpty {
                Picker("分组", selection: $editingGroupID) {
                    Text("不绑定分组").tag(Int64?.none)
                    ForEach(apiKeyState.groups) { group in
                        Text(groupDisplayName(group))
                            .tag(Int64?.some(group.id))
                    }
                }
                .font(.caption)
            }

            Toggle(isOn: $editingStatusActive) {
                Text("启用")
            }
            .font(.caption)

            HStack(spacing: 8) {
                Text("配额 (USD)")
                    .font(.caption)
                TextField("留空表示不修改", text: $editingQuotaText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 120)
            }

            HStack {
                Spacer()
                Button("取消") {
                    withAnimation {
                        editingKeyID = nil
                    }
                }
                .buttonStyle(.borderless)

                Button("保存") {
                    var request = APIKeyUpdateRequest()
                    let trimmedName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedName.isEmpty, trimmedName != key.name {
                        request.name = trimmedName
                    }
                    request.group_id = editingGroupID
                    let newStatus = editingStatusActive ? "active" : "inactive"
                    if newStatus != key.status {
                        request.status = newStatus
                    }
                    let quotaText = editingQuotaText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !quotaText.isEmpty, let value = Double(quotaText) {
                        request.quota = value
                    }
                    onUpdateAPIKey(key, request)
                    withAnimation {
                        editingKeyID = nil
                    }
                }
                .buttonStyle(.glass)
                .font(.caption)
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.05))
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private var cardFooter: some View {
        HStack {
            Button("兑换卡密", action: onRedeem)
                .buttonStyle(.glass)
            Spacer()
            Button("删除", role: .destructive, action: onDelete)
                .buttonStyle(.glass)
                .tint(.red)
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func toggleEdit(for key: APIKeyDTO) {
        if editingKeyID == key.id {
            editingKeyID = nil
            return
        }
        editingKeyID = key.id
        editingName = key.name
        editingGroupID = key.group_id
        editingStatusActive = (key.status == "active")
        if key.quota > 0 {
            editingQuotaText = String(key.quota)
        } else {
            editingQuotaText = ""
        }
    }

    private func groupDisplayName(_ group: APIGroupDTO) -> String {
        if let rates = apiKeyState.groupRates,
           let rate = rates[String(group.id)],
           rate != 1.0 {
            let formatted = String(format: "x%.2f", rate)
            return "\(group.name) (\(formatted))"
        }
        return group.name
    }

    private func nameWithGroupPrefix(name: String) -> String {
        guard let gid = selectedGroupID,
              let group = apiKeyState.groups.first(where: { $0.id == gid }) else {
            return name
        }
        // 简单前缀标注分组，方便在多分组场景下识别
        return "[\(group.name)] \(name)"
    }

    private func truncatedKey(_ full: String) -> String {
        if full.count <= 16 { return full }
        let prefix = full.prefix(8)
        let suffix = full.suffix(4)
        return "\(prefix)...\(suffix)"
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

#Preview("有余额") {
    let account = SiteAccount(siteURL: "https://api.example.com", email: "test@example.com")
    let result = AccountResult(
        account: account,
        status: .success,
        balance: 503.55,
        subscriptions: [
            SubscriptionDetail(
                groupName: "Claude Pro",
                expiresInDays: 28,
                daily: UsageWindow(limitUSD: 5.0, usedUSD: 1.2, remainingUSD: 3.8, percentage: 24),
                weekly: UsageWindow(limitUSD: 30.0, usedUSD: 12.5, remainingUSD: 17.5, percentage: 41.7),
                monthly: nil
            )
        ]
    )
    let apiKeyState = APIKeyListState()
    return AccountCard(
        account: account,
        result: result,
        apiKeyState: apiKeyState,
        onRedeem: {},
        onDelete: {},
        onLoadAPIKeys: {},
        onCreateAPIKey: { _ in },
        onDeleteAPIKey: { _ in },
        onUpdateAPIKey: { _, _ in }
    )
    .frame(width: 500)
    .padding()
}
