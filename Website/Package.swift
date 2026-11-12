// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SponsoredByIndiesWebsite",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/Ignite-Swift/Ignite.git", exact: "0.7.2")
    ],
    targets: [
        .executableTarget(name: "SponsoredByIndiesWebsite", dependencies: ["Ignite"]),
        .testTarget(name: "SponsoredByIndiesWebsiteTests", dependencies: ["SponsoredByIndiesWebsite", "Ignite"],
                    path: "Tests/SponsoredByIndiesWebsiteTests")
    ]
)
