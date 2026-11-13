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
            sources: ["src/Document.cpp", "src/InlineSyntax.cpp"],
            publicHeadersPath: "include"
        ),
    ],
    cxxLanguageStandard: .cxx20
)
