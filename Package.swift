// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MailForge",
    platforms: [
        .macOS(.v14) // macOS Sonoma minimum
    ],
    products: [
        .executable(
            name: "MailForge",
            targets: ["MailForge"]
        )
    ],
    dependencies: [
        // SwiftNIO for async networking (IMAP/SMTP)
        .package(
            url: "https://github.com/apple/swift-nio.git",
            from: "2.65.0"
        ),
        .package(
            url: "https://github.com/apple/swift-nio-ssl.git",
            from: "2.26.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "MailForge",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio")
            ]
            // SPM default: Sources/MailForge/
        )
    ]
)
