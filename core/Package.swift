// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MarkyCore",
    products: [
        .library(name: "MarkyCore", type: .static, targets: ["MarkyCore"]),
    ],
    targets: [
        .target(
            name: "MarkyCore",
            path: ".",
            sources: ["src/BuildInfo.cpp"],
            publicHeadersPath: "include"
        ),
    ],
    cxxLanguageStandard: .cxx20
)
