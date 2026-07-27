// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FaceTecVendor",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "FaceTecSDK", targets: ["FaceTecSDK"]),
        .library(name: "FaceTecSDKForDevelopment", targets: ["FaceTecSDKForDevelopment"]),
    ],
    targets: [
        // Fetched from the private vendor-swift-packages GitHub Release by
        // fetch.sh (not resolved automatically by SwiftPM -- Xcode's package
        // downloader can't authenticate against private release assets
        // reliably; see fetch.sh for why). Run fetch.sh once after cloning,
        // or after bumping RELEASE_TAG there for a new SDK version.
        .binaryTarget(
            name: "FaceTecSDK",
            path: "Frameworks/FaceTecSDK.xcframework"
        ),
        .binaryTarget(
            name: "FaceTecSDKForDevelopment",
            path: "Frameworks/FaceTecSDKForDevelopment.xcframework"
        ),
    ]
)
