// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Fideliair",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Fideliair", targets: ["Fideliair"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Fideliair",
            dependencies: [],
            path: "Fideliair",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
