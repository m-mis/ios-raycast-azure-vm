import Foundation

actor AzureAuth {
    static let shared = AzureAuth()

    private var cachedToken: String?
    private var tokenExpiresAt: Date?

    private init() {}

    func getAccessToken() async throws -> String {
        if let token = cachedToken, let expiresAt = tokenExpiresAt, Date() < expiresAt {
            return token
        }

        guard let credentials = KeychainHelper.loadCredentials() else {
            throw AzureError.noCredentials
        }

        let token = try await fetchToken(credentials: credentials)
        return token
    }

    func clearCache() {
        cachedToken = nil
        tokenExpiresAt = nil
    }

    private func fetchToken(credentials: AzureCredentials) async throws -> String {
        let url = URL(string: "https://login.microsoftonline.com/\(credentials.tenantId)/oauth2/v2.0/token")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "client_credentials",
            "client_id": credentials.clientId,
            "client_secret": credentials.clientSecret,
            "scope": "https://management.azure.com/.default",
        ]
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AzureError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AzureError.authenticationFailed(statusCode: httpResponse.statusCode, message: errorText)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        cachedToken = tokenResponse.accessToken
        tokenExpiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn - 60))

        return tokenResponse.accessToken
    }
}

enum AzureError: LocalizedError {
    case noCredentials
    case invalidResponse
    case authenticationFailed(statusCode: Int, message: String)
    case apiError(statusCode: Int, message: String)
    case noVmConfigured

    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "Azure credentials are not configured."
        case .invalidResponse:
            return "Invalid response from Azure."
        case .authenticationFailed(let code, let message):
            return "Authentication failed (\(code)): \(message)"
        case .apiError(let code, let message):
            return "Azure API error (\(code)): \(message)"
        case .noVmConfigured:
            return "No VM is configured. Please select a VM first."
        }
    }
}
