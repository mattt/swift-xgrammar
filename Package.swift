// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XGrammar",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "XGrammar",
            targets: ["XGrammar"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Cxgrammar",
            publicHeadersPath: "include/xgrammar",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("cpp"),
                .headerSearchPath("3rdparty/picojson"),
                .headerSearchPath("3rdparty/dlpack/include"),
            ],
            cxxSettings: [
                .define("XGRAMMAR_ENABLE_CPPTRACE", to: "0"),
                .define("XGRAMMAR_ENABLE_INTERNAL_CHECK", to: "0"),
                .headerSearchPath("include"),
                .headerSearchPath("cpp"),
                .headerSearchPath("3rdparty/picojson"),
                .headerSearchPath("3rdparty/dlpack/include"),
            ]
        ),
        .target(
            name: "XGrammar",
            dependencies: ["Cxgrammar"],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
        .testTarget(
            name: "XGrammarTests",
            dependencies: ["XGrammar"]
        ),
    ]
)
