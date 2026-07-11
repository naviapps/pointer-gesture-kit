// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "PointerGestureKit",
  platforms: [.macOS(.v14)],
  products: [
    .library(
      name: "PointerGestureKit",
      targets: ["PointerGestureKit"]
    ),
    .library(
      name: "PointerGestureKitCoreGraphics",
      targets: ["PointerGestureKitCoreGraphics"]
    ),
  ],
  targets: [
    .target(
      name: "PointerGestureKit"
    ),
    .target(
      name: "PointerGestureKitCoreGraphics",
      dependencies: [
        "PointerGestureKit"
      ]
    ),
    .testTarget(
      name: "PointerGestureKitTests",
      dependencies: [
        "PointerGestureKit"
      ]
    ),
    .testTarget(
      name: "PointerGestureKitCoreGraphicsTests",
      dependencies: [
        "PointerGestureKit",
        "PointerGestureKitCoreGraphics",
      ]
    ),
  ]
)
