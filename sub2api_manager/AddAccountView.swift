import SwiftUI

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var siteURL = ""
    @State private var email = ""
    @State private var password = ""

    var onAdd: (SiteAccount, String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("添加账号")
                .font(.headline)

            TextField("站点 URL（如 https://example.com）", text: $siteURL)
                .textFieldStyle(.roundedBorder)

            TextField("邮箱", text: $email)
                .textFieldStyle(.roundedBorder)

            SecureField("密码", text: $password)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("添加") {
                    let account = SiteAccount(
                        siteURL: siteURL.trimmingCharacters(in: .whitespacesAndNewlines),
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    onAdd(account, password)
                    dismiss()
                }
                .buttonStyle(.glass)
                .tint(.accentColor)
                .keyboardShortcut(.defaultAction)
                .disabled(siteURL.isEmpty || email.isEmpty || password.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
