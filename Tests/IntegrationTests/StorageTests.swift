import AsyncHTTPClient
import XCTest
import AzureSDK

final class StorageTests: XCTestCase {
    let tenantID: String =
    let clientID: String =
    let clientSecret: String =

    func testExample() async throws {
        let client = HTTPClient(eventLoopGroupProvider: .singleton)
        defer { try! client.shutdown().wait() }

        let azure = AzureClient(
            client: client,
            logger: .init(label: "Mock"),
            tenantID: tenantID,
            clientID: clientID,
            clientSecret: clientSecret
        )
        let storage = AzureStorage(client: azure, accountURL: "https://brokenhandstest.blob.core.windows.net")

        let userDelegationKey = try await storage.requestUserDelegationKey(
            keyExpiryTime: Date(timeIntervalSinceNow: 60 * 15)
        )

        XCTAssertEqual(userDelegationKey.signedTID, tenantID)

        let sas = storage.constructUserDelegationSAS(
            accountName: "brokenhandstest",
            containerName: "test-container",
            blobName: "123",
            userDelegationKey: userDelegationKey
        )
        print(sas)
    }
}
