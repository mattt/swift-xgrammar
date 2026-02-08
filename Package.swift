// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XGrammar",
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
