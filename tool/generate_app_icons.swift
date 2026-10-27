#!/usr/bin/env swift

// Regenerates every platform launcher icon from the checked-in Kritha brand
// sources. Run from the repository root:
//
//   swift tool/generate_app_icons.swift
//
// Android, iOS, macOS and Windows are generated. iOS icons are flattened over
// a slightly enlarged copy of the artwork so Apple's no-alpha rule is met
// without changing the visible rounded-square silhouette.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)

func source(_ relative: String) -> CGImage {
    let url = root.appendingPathComponent(relative)
    guard
        let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    else {
        fatalError("Missing or unreadable icon source: \(relative)")
    }
    return image
}

let fullIcon = source("assets/images/kritha_app_icon.png")
let adaptiveForeground = source("assets/images/kritha_icon_foreground.png")
let adaptiveBackground = source("assets/images/kritha_icon_background.png")
let adaptiveMonochrome = source("assets/images/kritha_icon_monochrome.png")

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func render(
    _ image: CGImage,
    size: Int,
    opaqueBackground: Bool = false
) -> CGImage {
    let alphaInfo: CGImageAlphaInfo = opaqueBackground
        ? .noneSkipLast
        : .premultipliedLast
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: alphaInfo.rawValue
    )!
    context.interpolationQuality = .high
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)

    if opaqueBackground {
        // Fill the canvas first, then extend the artwork beyond the edge and
        // draw it again at full size. The result is fully opaque, including the
        // rounded corners that Apple masks itself.
        context.setFillColor(
            CGColor(red: 0.0, green: 0.47843, blue: 1.0, alpha: 1.0)
        )
        context.fill(bounds)
        let bleed = 0.35
        let overscan = bounds.insetBy(
            dx: -bounds.width * bleed,
            dy: -bounds.height * bleed
        )
        context.draw(image, in: overscan)
    }

    context.draw(image, in: bounds)
    return context.makeImage()!
}

func writePNG(_ image: CGImage, to relative: String) {
    let url = root.appendingPathComponent(relative)
    try! fileManager.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        fatalError("Could not create PNG destination: \(relative)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Could not write PNG: \(relative)")
    }
}

func writeText(_ text: String, to relative: String) {
    let url = root.appendingPathComponent(relative)
    try! fileManager.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try! text.write(to: url, atomically: true, encoding: .utf8)
}

// ---------------------------------------------------------------------------
// Android
// ---------------------------------------------------------------------------

let androidDensities: [(name: String, legacy: Int, adaptive: Int)] = [
    ("mdpi", 48, 108),
    ("hdpi", 72, 162),
    ("xhdpi", 96, 216),
    ("xxhdpi", 144, 324),
    ("xxxhdpi", 192, 432),
]

for density in androidDensities {
    let base = "android/app/src/main/res/mipmap-\(density.name)"
    let legacy = render(fullIcon, size: density.legacy)
    writePNG(legacy, to: "\(base)/ic_launcher.png")
    writePNG(legacy, to: "\(base)/ic_launcher_round.png")

    writePNG(
        render(adaptiveForeground, size: density.adaptive),
        to: "\(base)/ic_launcher_foreground.png"
    )
    writePNG(
        render(adaptiveBackground, size: density.adaptive),
        to: "\(base)/ic_launcher_background.png"
    )
    writePNG(
        render(adaptiveMonochrome, size: density.adaptive),
        to: "\(base)/ic_launcher_monochrome.png"
    )
}

let adaptiveIcon = """
    <?xml version="1.0" encoding="utf-8"?>
    <adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
        <background android:drawable="@mipmap/ic_launcher_background"/>
        <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
        <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
    </adaptive-icon>

    """
writeText(
    adaptiveIcon,
    to: "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml"
)
writeText(
    adaptiveIcon,
    to: "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml"
)

// ---------------------------------------------------------------------------
// iOS (opaque, Xcode asset catalogue sizes)
// ---------------------------------------------------------------------------

let iosIcons: [(String, Int)] = [
    ("Icon-App-20x20@1x.png", 20),
    ("Icon-App-20x20@2x.png", 40),
    ("Icon-App-20x20@3x.png", 60),
    ("Icon-App-29x29@1x.png", 29),
    ("Icon-App-29x29@2x.png", 58),
    ("Icon-App-29x29@3x.png", 87),
    ("Icon-App-40x40@1x.png", 40),
    ("Icon-App-40x40@2x.png", 80),
    ("Icon-App-40x40@3x.png", 120),
    ("Icon-App-60x60@2x.png", 120),
    ("Icon-App-60x60@3x.png", 180),
    ("Icon-App-76x76@1x.png", 76),
    ("Icon-App-76x76@2x.png", 152),
    ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-1024x1024@1x.png", 1024),
]

for (name, size) in iosIcons {
    writePNG(
        render(fullIcon, size: size, opaqueBackground: true),
        to: "ios/Runner/Assets.xcassets/AppIcon.appiconset/\(name)"
    )
}

// ---------------------------------------------------------------------------
// macOS (824x824 icon grid with Apple HIG drop shadow)
// ---------------------------------------------------------------------------

func renderMacOS(_ image: CGImage, size: Int) -> CGImage {
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.interpolationQuality = .high

    let scale = 0.805
    let iconSize = Double(size) * scale
    let xOffset = (Double(size) - iconSize) / 2.0
    let yOffset = Double(size) * 0.10
    let iconRect = CGRect(x: xOffset, y: yOffset, width: iconSize, height: iconSize)

    context.saveGState()
    let shadowColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0.25)
    let shadowBlur = Double(size) * 0.04
    let shadowOffset = CGSize(width: 0, height: -Double(size) * 0.018)
    context.setShadow(offset: shadowOffset, blur: shadowBlur, color: shadowColor)
    context.draw(image, in: iconRect)
    context.restoreGState()

    context.draw(image, in: iconRect)
    return context.makeImage()!
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    writePNG(
        renderMacOS(fullIcon, size: size),
        to: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_\(size).png"
    )
}

// ---------------------------------------------------------------------------
// Windows (intermediate PNGs are packed into the .ico by package_ico.py)
// ---------------------------------------------------------------------------

for size in [16, 24, 32, 48, 64, 128, 256] {
    writePNG(
        render(fullIcon, size: size),
        to: "build/icon_gen/windows/icon_\(size).png"
    )
}

print("Generated Android, iOS and macOS icons. Run tool/package_ico.py next.")
