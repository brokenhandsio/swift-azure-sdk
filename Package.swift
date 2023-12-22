// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "swift-azure-sdk",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "AzureSDK",
            targets: ["AzureSDK"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.19.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.3"),
        .package(url: "https://github.com/CoreOffice/XMLCoder.git", from: "0.17.1"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.1.0"),
    ],
    targets: [
        .target(
            name: "AzureSDK",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "XMLCoder", package: "XMLCoder"),
                .product(name: "Crypto", package: "swift-crypto")
            ]
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: ["AzureSDK"]
        ),
    ]
)
