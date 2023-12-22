import XCTest
@testable import AzureSDK
import AsyncHTTPClient

final class StorageTests: XCTestCase {
    func testExample() async throws {
        // Obtain user delegation key using curl (for now):
        // curl -X POST -H "Content-Type: application/x-www-form-urlencoded" https://login.microsoftonline.com/9e01570c-bb4d-4ef6-9ed9-9df6a7916a28/oauth2/v2.0/token \
        // --data "client_id=6938b466-f333-492a-88e8-d6fe00fb94a0&scope=https://storage.azure.com/.default&client_secret=<insert client secret here>&grant_type=client_credentials"
        let client = HTTPClient(eventLoopGroupProvider: .singleton)
        defer { try! client.shutdown().wait() }

        let azure = AzureClient(client: client, logger: .init(label: "Mock"))
        let storage = AzureStorage(client: azure, oauthAccessToken: "")

        let userDelegationKey = try await storage.requestUserDelegationKey(keyExpiryTime: Date(timeIntervalSinceNow: 60 * 15))

        XCTAssertEqual(userDelegationKey.signedTID, "9e01570c-bb4d-4ef6-9ed9-9df6a7916a28")

        let sas = storage.constructUserDelegationSAS(accountName: "brokenhandstest", containerName: "test-container", blobName: "123", userDelegationKey: userDelegationKey)
        print(sas)
    }
}
