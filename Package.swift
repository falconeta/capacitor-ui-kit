// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapacitorUiKit",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "CapacitorUiKit",
            targets: ["CapacitorUIKitPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "CapacitorUIKitPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/CapacitorUIKitPlugin"),
        .testTarget(
            name: "CapacitorUIKitPluginTests",
            dependencies: ["CapacitorUIKitPlugin"],
            path: "ios/Tests/CapacitorUIKitPluginTests")
    ]
)