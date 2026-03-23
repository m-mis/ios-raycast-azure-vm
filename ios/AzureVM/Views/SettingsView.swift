import SwiftUI

struct SettingsView: View {
    var onSaved: () -> Void

    @State private var tenantId: String = ""
    @State private var clientId: String = ""
    @State private var clientSecret: String = ""
    @State private var isTesting = false
    @State private var testResult: TestResult?

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        Form {
            Section {
                TextField("Tenant ID", text: $tenantId)
                    .textContentType(.none)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                TextField("Client ID", text: $clientId)
                    .textContentType(.none)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("Client Secret", text: $clientSecret)
                    .textContentType(.password)
            } header: {
                Text("Azure Service Principal")
            } footer: {
                Text("Create a Service Principal in Azure Entra ID with Reader + VM Contributor roles on your subscription.")
            }

            Section {
                Button {
                    Task { await testConnection() }
                } label: {
                    HStack {
                        Text("Test Connection")
                        Spacer()
                        if isTesting {
                            ProgressView()
                        } else if let result = testResult {
                            switch result {
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            case .failure:
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
                .disabled(!isValid || isTesting)

                if case .failure(let message) = testResult {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Save & Continue") {
                    save()
                }
                .disabled(!isValid)
                .fontWeight(.semibold)
            }

            if KeychainHelper.loadCredentials() != nil {
                Section {
                    Button("Delete Credentials", role: .destructive) {
                        KeychainHelper.deleteCredentials()
                        tenantId = ""
                        clientId = ""
                        clientSecret = ""
                        testResult = nil
                    }
                }
            }
        }
        .navigationTitle("Azure Credentials")
        .onAppear {
            if let existing = KeychainHelper.loadCredentials() {
                tenantId = existing.tenantId
                clientId = existing.clientId
                clientSecret = existing.clientSecret
            }
        }
    }

    private var isValid: Bool {
        !tenantId.isEmpty && !clientId.isEmpty && !clientSecret.isEmpty
    }

    private func save() {
        let credentials = AzureCredentials(tenantId: tenantId, clientId: clientId, clientSecret: clientSecret)
        _ = KeychainHelper.saveCredentials(credentials)
        Task { await AzureAuth.shared.clearCache() }
        onSaved()
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil

        let credentials = AzureCredentials(tenantId: tenantId, clientId: clientId, clientSecret: clientSecret)
        _ = KeychainHelper.saveCredentials(credentials)
        await AzureAuth.shared.clearCache()

        do {
            _ = try await AzureAPI.listSubscriptions()
            testResult = .success
        } catch {
            testResult = .failure(error.localizedDescription)
        }

        isTesting = false
    }
}
