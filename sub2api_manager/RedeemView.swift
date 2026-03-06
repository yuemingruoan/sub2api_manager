import SwiftUI

struct RedeemView: View {
    @Environment(\.dismiss) private var dismiss
    let account: SiteAccount
    let password: String

    @State private var code = ""
    @State private var isLoading = false
    @State private var resultMessage: String?
    @State private var isError = false

    var body: some View {
        VStack(spacing: 16) {
            Text("兑换卡密")
                .font(.headline)

            Text(account.siteURL)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("输入卡密", text: $code)
                .textFieldStyle(.roundedBorder)

            if let msg = resultMessage {
                Text(msg)
                    .font(.callout)
                    .foregroundStyle(isError ? .red : .green)
            }

            HStack {
                Button("关闭") { dismiss() }
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if isLoading {
                    ProgressView().controlSize(.small)
                }
                Button("兑换") {
                    Task { await doRedeem() }
                }
                .buttonStyle(.glass)
                .tint(.green)
                .keyboardShortcut(.defaultAction)
                .disabled(code.isEmpty || isLoading)
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private func doRedeem() async {
        isLoading = true
        resultMessage = nil
        do {
            let token = try await APIService.login(
                siteURL: account.siteURL,
                email: account.email,
                password: password
            )
            let result = try await APIService.redeem(
                siteURL: account.siteURL,
                token: token,
                code: code.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            isError = false
            let typeName = result.type ?? "unknown"
            let value = result.value ?? 0
            resultMessage = "兑换成功 [\(typeName)] +\(String(format: "%.2f", value))"
            code = ""
        } catch {
            isError = true
            resultMessage = error.localizedDescription
        }
        isLoading = false
    }
}
