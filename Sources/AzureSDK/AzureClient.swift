import AsyncHTTPClient
import Foundation
import Logging
import NIOCore
import NIOFoundationCompat

public final actor AzureClient {
    public enum AzureClientError: Error {
        case oAuthTokenRequestFailed
    }

    public let client: HTTPClient
    public let logger: Logger
    public let tenantID: String
    public let clientID: String
    public let clientSecret: String

    private var oAuthToken: OAuthToken?

    public init(client: HTTPClient, logger: Logger, tenantID: String, clientID: String, clientSecret: String) {
        self.client = client
        self.logger = logger
        self.tenantID = tenantID
        self.clientID = clientID
        self.clientSecret = clientSecret
    }

    public func getCachedOAuthToken() async throws -> String {
        if let oAuthToken, oAuthToken.expiresIn < Date() {
            return oAuthToken.accessToken
        } else {
            self.oAuthToken = try await requestOAuthToken()
            return self.oAuthToken!.accessToken
        }
    }

    private func requestOAuthToken() async throws -> OAuthToken {
        let url = "https://login.microsoftonline.com/\(tenantID)/oauth2/v2.0/token"
        let formDataString =
            "client_id=\(clientID)&scope=https://storage.azure.com/.default&client_secret=\(clientSecret)&grant_type=client_credentials"
        let formData = formDataString.data(using: .utf8)!
        let contentLength = formData.count
        var request = HTTPClientRequest(url: url)
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
        request.headers.add(name: "Content-Length", value: "\(contentLength)")
        request.body = .bytes(ByteBuffer(data: formData))

        let response = try await client.execute(request, timeout: .seconds(30))
        let responseBody = try await response.body.collect(upTo: 1024 * 1024)
        let responseBodyData = Data(buffer: responseBody)

        guard response.status == .ok else {
            logger.error("Getting OAuth token failed with status code \(response.status.code)")
            throw AzureClientError.oAuthTokenRequestFailed
        }

        let oAuthResponse = try OAuthToken.decoder.decode(OAuthToken.self, from: responseBodyData)
        return oAuthResponse
    }
}
