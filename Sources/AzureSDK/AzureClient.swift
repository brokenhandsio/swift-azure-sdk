import AsyncHTTPClient
import Logging
import NIOCore

public final actor AzureClient {
    public let client: HTTPClient
    public let logger: Logger

    public init(client: HTTPClient, logger: Logger) {
        self.client = client
        self.logger = logger
    }
}
