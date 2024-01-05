import AsyncHTTPClient
import Crypto
import Foundation
import Logging
import NIOCore
import NIOFoundationCompat
import NIOHTTP1
import XMLCoder

public struct AzureStorage {
    public enum AzureStorageError: Error {
        case getUserDelegationKeyRequestFailed
        case getOAuthTokenRequestFailed
    }

    public let client: AzureClient
    public let accountURL: String

    public init(client: AzureClient, accountURL: String) {
        self.client = client
        self.accountURL = accountURL
    }

    public func requestUserDelegationKey(
        keyStartTime: Date = Date(),
        keyExpiryTime: Date
    ) async throws -> UserDelegationKey {
        let url = accountURL + "/?restype=service&comp=userdelegationkey"
        let oAuthToken = try await client.getCachedOAuthToken()
        let headers = HTTPHeaders([
            ("Authorization", "Bearer \(oAuthToken)"),
            ("x-ms-version", "2022-11-02"),
        ])

        let body = GetUserDelegationKeyRequest(start: keyStartTime, expiry: keyExpiryTime)
        let encoder = XMLEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encodedBody = try encoder.encode(body, withRootKey: "KeyInfo")

        var request = HTTPClientRequest(url: url)
        request.method = .POST
        request.headers = headers
        request.body = .bytes(encodedBody)

        let response = try await client.client.execute(request, timeout: .seconds(30))
        let responseBody = try await response.body.collect(upTo: 1024 * 1024)
        let responseBodyData = Data(buffer: responseBody)

        guard response.status == .ok else {
            client.logger.error("Getting user delegation key failed with status code \(response.status.code)")
            throw AzureStorageError.getUserDelegationKeyRequestFailed
        }

        let decoder = XMLDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(UserDelegationKey.self, from: responseBodyData)
    }

    public func constructUserDelegationSAS(
        accountName: String,
        containerName: String,
        blobName: String,
        userDelegationKey: UserDelegationKey,
        permission: BlobSASPermission = .readWrite,
        start: Date? = nil,
        expiry: Date? = nil
    ) -> String {
        let signedResource = "c"
        let httpProtocol = "https"
        // see https://learn.microsoft.com/en-us/rest/api/storageservices/create-user-delegation-sas#construct-a-user-delegation-sas
        var queryParameters = [
            ("sr", signedResource),
            ("sp", permission.rawValue),
            ("spr", httpProtocol),
            ("skt", userDelegationKey.signedStart.ISO8601Format()),
            ("st", start?.ISO8601Format() ?? userDelegationKey.signedStart.ISO8601Format()),
            ("ske", userDelegationKey.signedExpiry.ISO8601Format()),
            ("se", expiry?.ISO8601Format() ?? userDelegationKey.signedExpiry.ISO8601Format()),
            ("skoid", userDelegationKey.signedOID),
            ("sktid", userDelegationKey.signedTID),
            ("sks", userDelegationKey.signedService.rawValue),
            ("skv", userDelegationKey.signedVersion),
            ("sv", userDelegationKey.signedVersion),
        ]

        // order is important here, don't change it. Empty strings are important too
        let stringToSign = [
            permission.rawValue,
            start?.ISO8601Format() ?? userDelegationKey.signedStart.ISO8601Format(),
            expiry?.ISO8601Format() ?? userDelegationKey.signedExpiry.ISO8601Format(),
            "/blob/" + accountName + "/" + containerName,  // + "/" + blobName,
            userDelegationKey.signedOID,
            userDelegationKey.signedTID,
            userDelegationKey.signedStart.ISO8601Format(),
            userDelegationKey.signedExpiry.ISO8601Format(),
            userDelegationKey.signedService.rawValue,
            userDelegationKey.signedVersion,
            "",  // signedAuthorizedUserObjectId
            "",  // signedUnauthorizedUserObjectId
            "",  // signedCorrelationId
            "",  // signedIP
            httpProtocol,
            userDelegationKey.signedVersion,
            signedResource,  // signedResource
            "",  // signedSnapshotTime
            "",  // signedEncryptionScope
            "",  // Cache Control
            "",  // Content Disposition
            "",  // Content Encoding
            "",  // Content Language
            "",  // Content Type
        ]
        .joined(separator: "\n")

        let key = Array(
            HMAC<SHA256>
                .authenticationCode(
                    for: stringToSign.data(using: .utf8)!,
                    using: SymmetricKey(data: Data(base64Encoded: userDelegationKey.value)!)
                )
        )

        queryParameters.append(("sig", Data(key).base64EncodedString()))

        let queryParametersString = queryParameters.map { $0.0 + "=" + $0.1 }.joined(separator: "&")

        let url =
            "https://" + accountName + ".blob.core.windows.net/" + containerName + "/" + blobName + "?"
            + queryParametersString

        return url
    }

}

public enum BlobService: String, Decodable {
    case blob = "b"
    case blobVersion = "bv"
    case blobSnapshot = "bs"
    case container = "c"
    case directory = "d"
}

/// https://learn.microsoft.com/en-us/rest/api/storageservices/create-user-delegation-sas#specify-permissions
public enum BlobSASPermission: String {
    case read = "r"
    case readWrite = "rw"
    case readDelete = "rd"
    case readList = "rl"
    // ...
}

public struct UserDelegationKey: Decodable {
    public let value: String
    public let signedOID: String
    public let signedTID: String
    public let signedStart: Date
    public let signedExpiry: Date
    public let signedService: BlobService
    public let signedVersion: String

    public enum CodingKeys: String, CodingKey {
        case value = "Value"
        case signedOID = "SignedOid"
        case signedTID = "SignedTid"
        case signedStart = "SignedStart"
        case signedExpiry = "SignedExpiry"
        case signedService = "SignedService"
        case signedVersion = "SignedVersion"
    }
}

extension AzureStorage {
    private struct GetUserDelegationKeyRequest: Encodable {
        let start: Date
        let expiry: Date

        enum CodingKeys: String, CodingKey {
            case start = "Start"
            case expiry = "Expiry"
        }
    }

}
