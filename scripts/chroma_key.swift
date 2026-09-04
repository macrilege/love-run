#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: chroma_key.swift input.png output.png\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fputs("Could not load input image.\n", stderr)
    exit(1)
}

let bytesPerPixel = 4
let bytesPerRow = image.width * bytesPerPixel
var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
let colorSpace = CGColorSpaceCreateDeviceRGB()

pixels.withUnsafeMutableBytes { buffer in
    guard let context = CGContext(
        data: buffer.baseAddress,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
}

for offset in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
    let red = Double(pixels[offset])
    let green = Double(pixels[offset + 1])
    let blue = Double(pixels[offset + 2])
    let dominance = green - max(red, blue)
    guard green > 95, dominance > 24 else { continue }

    let alpha = max(0, min(1, (72 - dominance) / 48))
    let cleanedGreen = min(green, max(red, blue) + 10)
    pixels[offset] = UInt8((red * alpha).rounded())
    pixels[offset + 1] = UInt8((cleanedGreen * alpha).rounded())
    pixels[offset + 2] = UInt8((blue * alpha).rounded())
    pixels[offset + 3] = UInt8((255 * alpha).rounded())
}

guard let provider = CGDataProvider(data: Data(pixels) as CFData),
      let output = CGImage(
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
      ),
      let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fputs("Could not create output image.\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("Could not write output image.\n", stderr)
    exit(1)
}

print("Wrote \(outputURL.path)")
