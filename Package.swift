// swift-tools-version: 5.9
//
//  Package.swift
//  KitoSearch
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "KitoSearch",
    platforms: [.iOS(.v17)],
    products: [.library(name: "KitoSearch", targets: ["KitoSearch"])],
    dependencies: [
        .package(url: "https://github.com/WykSofts-Inc/KitoCore.git", from: "1.1.0"),
    ],
    targets: [
        .target(name: "KitoSearch", dependencies: [.product(name: "KitoCore", package: "KitoCore")]),
        .testTarget(name: "KitoSearchTests", dependencies: ["KitoSearch"]),
    ]
)
