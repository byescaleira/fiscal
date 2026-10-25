// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FiscalKit",
    defaultLocalization: "pt-BR",
    platforms: [.iOS("27.0"), .macOS("27.0"), .visionOS("27.0")],
    products: [
        .library(
            name: "FiscalWidgetKit", targets: ["FiscalDomain", "FiscalData", "FiscalDesignSystem"]),
        .library(
            name: "FiscalKit",
            targets: ["FiscalDomain", "FiscalData", "FeatureCore", "FeatureSettings", "AppShell"]),
    ],
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.5.0")
    ],
    targets: [
        .target(name: "FiscalDomain"),
        .target(name: "FiscalData", dependencies: ["FiscalDomain"]),
        .target(name: "FiscalDesignSystem"),
        .target(
            name: "FiscalResource", resources: [.process("Assets"), .process("art-credits.json")]),
        .target(
            name: "FeatureCore",
            dependencies: [
                "FiscalDomain", "FiscalDesignSystem", "FiscalResource",
                .product(name: "Lottie", package: "lottie-spm"),
            ]),
        .target(
            name: "FeatureGuides",
            dependencies: ["FiscalDomain", "FiscalDesignSystem", "FeatureCore"]),
        .target(
            name: "FeatureLiveResults",
            dependencies: ["FiscalDomain", "FiscalDesignSystem", "FeatureCore"]),
        .target(
            name: "FeatureToday",
            dependencies: ["FiscalDomain", "FiscalDesignSystem", "FeatureCore"]),
        .target(
            name: "FeatureMine",
            dependencies: ["FiscalDomain", "FiscalDesignSystem", "FeatureCore"]),
        .target(
            name: "FeatureProfile",
            dependencies: ["FiscalDomain", "FiscalDesignSystem", "FeatureCore"]),
        .target(
            name: "FeatureVotes",
            dependencies: ["FiscalDomain", "FiscalDesignSystem", "FeatureCore"]),
        .target(
            name: "FeatureMoney",
            dependencies: ["FiscalDomain", "FiscalDesignSystem", "FeatureCore"]),
        .target(
            name: "FeatureSearch",
            dependencies: ["FiscalDomain", "FiscalDesignSystem", "FeatureCore"]),
        .target(
            name: "FeatureLens",
            dependencies: ["FiscalDomain", "FiscalDesignSystem", "FeatureCore"]),
        .target(
            name: "FeatureShare",
            dependencies: ["FiscalDomain", "FiscalDesignSystem", "FeatureCore"]),
        .target(
            name: "FeatureSettings",
            dependencies: ["FiscalDomain", "FiscalDesignSystem", "FiscalResource", "FeatureCore"]),
        .target(
            name: "AppShell",
            dependencies: [
                "FiscalDomain", "FiscalData", "FiscalDesignSystem", "FeatureCore",
                "FeatureGuides", "FeatureLiveResults", "FeatureSettings", "FeatureToday",
                "FeatureMine", "FeatureProfile", "FeatureVotes", "FeatureMoney", "FeatureSearch",
                "FeatureLens", "FeatureShare",
            ]),
        .testTarget(name: "FiscalDomainTests", dependencies: ["FiscalDomain"]),
        .testTarget(name: "FiscalDataTests", dependencies: ["FiscalDomain", "FiscalData"]),
        .testTarget(name: "FiscalDesignSystemTests", dependencies: ["FiscalDesignSystem"]),
        .testTarget(name: "FiscalResourceTests", dependencies: ["FiscalResource"]),
        .testTarget(
            name: "FeatureCoreTests",
            dependencies: [
                "FiscalDomain", "FiscalData", "FiscalDesignSystem", "FiscalResource",
                "FeatureCore",
            ]),
        .testTarget(
            name: "FeatureGuidesTests",
            dependencies: ["FiscalDomain", "FiscalData", "FeatureCore", "FeatureGuides"]),
        .testTarget(
            name: "FeatureLiveResultsTests",
            dependencies: ["FiscalDomain", "FiscalData", "FeatureCore", "FeatureLiveResults"]),
        .testTarget(
            name: "FeatureTodayTests",
            dependencies: ["FiscalDomain", "FiscalData", "FeatureCore", "FeatureToday"]),
        .testTarget(
            name: "FeatureMineTests",
            dependencies: ["FiscalDomain", "FiscalData", "FeatureCore", "FeatureMine"]),
        .testTarget(
            name: "FeatureProfileTests",
            dependencies: ["FiscalDomain", "FiscalData", "FeatureCore", "FeatureProfile"]),
        .testTarget(
            name: "FeatureVotesTests",
            dependencies: ["FiscalDomain", "FiscalData", "FeatureCore", "FeatureVotes"]),
        .testTarget(
            name: "FeatureMoneyTests",
            dependencies: ["FiscalDomain", "FiscalData", "FeatureCore", "FeatureMoney"]),
        .testTarget(
            name: "FeatureSearchTests",
            dependencies: ["FiscalDomain", "FiscalData", "FeatureCore", "FeatureSearch"]),
        .testTarget(
            name: "FeatureLensTests",
            dependencies: ["FiscalDomain", "FiscalData", "FeatureCore", "FeatureLens"]),
        .testTarget(
            name: "FeatureShareTests",
            dependencies: ["FiscalDomain", "FiscalData", "FeatureCore", "FeatureShare"]),
        .testTarget(
            name: "FeatureSettingsTests",
            dependencies: ["FiscalDomain", "FiscalData", "FeatureCore", "FeatureSettings"]),
        .testTarget(
            name: "AppShellTests",
            dependencies: ["FiscalDomain", "FiscalData", "FeatureCore", "AppShell"]),
    ]
)
