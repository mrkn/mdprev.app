// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "mdprev",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "mdprev", targets: ["mdprev"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-cmark.git", branch: "gfm")
    ],
    targets: [
        .executableTarget(
            name: "mdprev",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark")
            ],
            path: "src/mdprev",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "mdprevTests",
            dependencies: ["mdprev"],
            path: "tests/mdprevTests"
        )
    ]
)
