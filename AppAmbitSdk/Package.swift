// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppAmbit",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "AppAmbit",
            type: .dynamic,
            targets: ["AppAmbit"]
        ),
    ],
    targets: [
        .target(
            name: "AppAmbit"
        ),
    ]
)
