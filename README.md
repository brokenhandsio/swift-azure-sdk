# Swift Azure SDK

Currently this library only supports generating presigned URLs ("SAS") for Azure Storage

## Vapor Setup

`AzureClient` caches requested authentication tokens and needs to be shutdown properly, so it makes sense to
extend `Application` with `AzureClient` to avoid recreating `AzureClient`s:

```swift
import Vapor

public extension Application {
    var azure: Azure {
        .init(application: self)
    }

    struct Azure {
        struct ClientKey: StorageKey {
            typealias Value = AzureClient 
        }

        public var client: AzureClient {
            get {
                guard let client = self.application.storage[ClientKey.self] else {
                    fatalError("AzureClient not setup. Use application.azure.client = ...")
                }
                return client
            }
            nonmutating set {
                self.application.storage.set(ClientKey.self, to: newValue) {
                    try $0.client.shutdown().wait()
                }            
            }
        }

        let application: Application
    }
}

public extension Request {
    var azure: Azure {
        .init(request: self)
    }

    struct Azure {
        var client: AzureClient {
            return request.application.azure.client
        }

        let request: Request
    }
}

```

Then in your `configure(_ app: Application)`:

```swift
app.azure.client = AzureClient(
    client: client,
    logger: app.logger,
    tenantID: <tenantID goes here>,
    clientID: <clientID goes here>,
    clientSecret: <clientSecret goes here>
) 
```

Optionally: Extend our new `Application.Azure` struct with `Storage`:

```swift
extension Application.Azure {
    struct StorageKey: StorageKey {
        typealias Value = AzureStorage
    }

    public var storage: AzureStorage {
        get {
            guard let storage = self.application.storage[StorageKey.self] else {
                fatalError("AzureStorage not setup. Use application.aws.storage = ...")
            }
            return storage
        }
        nonmutating set {
            self.application.storage[StorageKey.self] = newValue
        }
    }
}

public extension Request.Azure {
    var storage: AzureStorage {
        return request.application.azure.storage
    }
}
```

Don't forget to set up the storage service in your `configure(_ app: Application)`:

```swift
app.azure.storage = AzureStorage(client: app.azure.client, accountURL: "https://brokenhandstest.blob.core.windows.net")
```

## Generate SAS ("presigned URLs")

E.g. in your request handler:

```swift
func getSAS(_ req: Request) async throws -> String {
    let userDelegationKey = try await req.azure.storage.requestUserDelegationKey(
        keyExpiryTime: Date(timeIntervalSinceNow: 60 * 15)
    )

    let sas = storage.constructUserDelegationSAS(
        accountName: "brokenhandstest",
        containerName: "test-container",
        blobName: "123",
        userDelegationKey: userDelegationKey
    )

    return sas
}
```

