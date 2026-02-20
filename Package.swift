// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VTSImaging",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "VTSImaging",
            targets: ["App"]
        ),
    ],
    dependencies: [
        .package(path: "../ml-stable-diffusion"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "StableDiffusion", package: "ml-stable-diffusion")
            ],
            path: "Sources/App",
            resources: [
                .copy("../Resources")
            ]
        ),
    ]
)
