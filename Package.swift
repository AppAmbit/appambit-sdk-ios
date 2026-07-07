// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppAmbitSdk",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "AppAmbit",
            targets: ["AppAmbit"]
        ),
        .library(
            name: "AppAmbitPushNotifications",
            targets: ["AppAmbitPushNotifications"]
        ),
        .library(
            name: "AppAmbitPushNotificationsExtension",
            targets: ["AppAmbitPushNotificationsExtension"]
        ),
    ],
    targets: [
        .target(
            name: "AppAmbit",
            path: "AppAmbitSdk/Sources"
        ),
        .target(
            name: "AppAmbitPushNotifications",
            dependencies: ["AppAmbit"],
            path: "Push/AppAmbitPushNotifications/Sources"
        ),
        .target(
            name: "AppAmbitPushNotificationsExtension",
            path: "PushExtensionSources"
        ),
    ]
)
