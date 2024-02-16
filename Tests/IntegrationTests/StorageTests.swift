import AsyncHTTPClient
import AzureSDK
import XCTest

final class StorageTests: XCTestCase {
    let tenantID: String = ""
    let clientID: String = ""
    let clientSecret: String = ""
    let storageAccountName: String = ""
    let containerName: String = ""

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
        let storage = AzureStorage(client: azure, accountURL: "https://\(storageAccountName).blob.core.windows.net")

        let userDelegationKey = try await storage.requestUserDelegationKey(
            keyExpiryTime: Date().addingTimeInterval(60 * 60 * 24) // 24 hours
        )

        XCTAssertEqual(userDelegationKey.signedTID, tenantID)

        let sas = storage.constructUserDelegationBlobSAS(
            accountName: storageAccountName,
            containerName: containerName,
            blobName: "",
            userDelegationKey: userDelegationKey,
            permission: BlobSASPermission.read
        )
        print(sas)
    }
}
