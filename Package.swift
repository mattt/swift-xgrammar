// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XGrammar",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "XGrammar",
            targets: ["XGrammar"]
        )
    ],
    targets: [
        .target(
            name: "Cxgrammar",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("cpp"),
            ],
            cxxSettings: [
                .define("XGRAMMAR_ENABLE_CPPTRACE", to: "0"),
                .define("XGRAMMAR_ENABLE_INTERNAL_CHECK", to: "0"),
                .headerSearchPath("include"),
                .headerSearchPath("cpp"),
            ]
        ),
        .target(
            name: "XGrammar",
            dependencies: ["Cxgrammar"]
        ),
        .testTarget(
            name: "XGrammarTests",
            dependencies: ["XGrammar"]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
