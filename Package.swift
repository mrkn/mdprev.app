// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "mdprev",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "MDPrevRendering", targets: ["MDPrevRendering"]),
        .executable(name: "mdprev", targets: ["mdprev"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-cmark.git", branch: "gfm")
    ],
    targets: [
        .target(
            name: "MDPrevRendering",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark")
            ],
            path: "src/MDPrevRendering",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "mdprev",
            dependencies: [
                "MDPrevRendering"
            ],
            path: "src/mdprev"
        ),
        .testTarget(
            name: "mdprevTests",
            dependencies: ["mdprev", "MDPrevRendering"],
            path: "tests/mdprevTests"
        )
    ]
)
