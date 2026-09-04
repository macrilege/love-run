#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: prepare_runner_sheet.swift input.png output.png\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard
    let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    fputs("Could not load input image.\n", stderr)
    exit(1)
}

let columns = 3
let rows = 2
let outputCellWidth = 512
let outputCellHeight = 512
let bytesPerPixel = 4

func rgbaPixels(for image: CGImage) -> [UInt8] {
    var pixels = [UInt8](repeating: 0, count: image.width * image.height * bytesPerPixel)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    pixels.withUnsafeMutableBytes { buffer in
        guard let context = CGContext(
            data: buffer.baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return pixels
}

struct PixelBounds {
    let minX: Int
    let minY: Int
    let maxX: Int
    let maxY: Int

    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }
}

struct FrameData {
    let bounds: PixelBounds
    let mask: [UInt8]
}

let sourcePixels = rgbaPixels(for: image)
var frames: [FrameData] = []

for row in 0..<rows {
    let cellMinY = row * image.height / rows
    let cellMaxY = (row + 1) * image.height / rows
    for column in 0..<columns {
        let cellMinX = column * image.width / columns
        let cellMaxX = (column + 1) * image.width / columns
        let cellWidth = cellMaxX - cellMinX
        let cellHeight = cellMaxY - cellMinY
        var visited = [UInt8](repeating: 0, count: cellWidth * cellHeight)
        var largestComponent: [Int] = []

        for localY in 0..<cellHeight {
            for localX in 0..<cellWidth {
                let localIndex = localY * cellWidth + localX
                let sourceIndex = ((cellMinY + localY) * image.width + cellMinX + localX) * bytesPerPixel
                guard visited[localIndex] == 0, sourcePixels[sourceIndex + 3] > 8 else { continue }

                visited[localIndex] = 1
                var component = [localIndex]
                var cursor = 0
                while cursor < component.count {
                    let current = component[cursor]
                    cursor += 1
                    let x = current % cellWidth
                    let y = current / cellWidth
                    let neighbors = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
                    for (nextX, nextY) in neighbors where nextX >= 0 && nextX < cellWidth && nextY >= 0 && nextY < cellHeight {
                        let next = nextY * cellWidth + nextX
                        let nextSource = ((cellMinY + nextY) * image.width + cellMinX + nextX) * bytesPerPixel
                        if visited[next] == 0, sourcePixels[nextSource + 3] > 8 {
                            visited[next] = 1
                            component.append(next)
                        }
                    }
                }
                if component.count > largestComponent.count { largestComponent = component }
            }
        }

        guard !largestComponent.isEmpty else {
            fputs("A sprite cell is empty.\n", stderr)
            exit(1)
        }

        var mask = [UInt8](repeating: 0, count: image.width * image.height)
        var minX = cellMaxX
        var minY = cellMaxY
        var maxX = cellMinX
        var maxY = cellMinY
        for localIndex in largestComponent {
            let x = cellMinX + localIndex % cellWidth
            let y = cellMinY + localIndex / cellWidth
            mask[y * image.width + x] = 1
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
        frames.append(FrameData(
            bounds: PixelBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY),
            mask: mask
        ))
    }
}

let widest = frames.map(\.bounds.width).max()!
let tallest = frames.map(\.bounds.height).max()!
let scale = min(
    CGFloat(outputCellWidth - 24) / CGFloat(widest),
    CGFloat(outputCellHeight - 30) / CGFloat(tallest)
)
let outputWidth = outputCellWidth * columns
let outputHeight = outputCellHeight * rows
var outputPixels = [UInt8](repeating: 0, count: outputWidth * outputHeight * bytesPerPixel)

func sourceComponent(x: Int, y: Int, channel: Int, mask: [UInt8]) -> CGFloat {
    let clampedX = min(max(0, x), image.width - 1)
    let clampedY = min(max(0, y), image.height - 1)
    guard mask[clampedY * image.width + clampedX] == 1 else { return 0 }
    return CGFloat(sourcePixels[(clampedY * image.width + clampedX) * bytesPerPixel + channel])
}

for (index, frameData) in frames.enumerated() {
    let frame = frameData.bounds
    let column = index % columns
    let row = index / columns
    let scaledWidth = Int((CGFloat(frame.width) * scale).rounded())
    let scaledHeight = Int((CGFloat(frame.height) * scale).rounded())
    let targetX = column * outputCellWidth + (outputCellWidth - scaledWidth) / 2
    let targetY = row * outputCellHeight + outputCellHeight - 16 - scaledHeight

    for destinationY in 0..<scaledHeight {
        let sourceY = CGFloat(frame.minY) + (CGFloat(destinationY) + 0.5) / scale - 0.5
        let y0 = Int(floor(sourceY))
        let y1 = y0 + 1
        let fy = sourceY - CGFloat(y0)

        for destinationX in 0..<scaledWidth {
            let sourceX = CGFloat(frame.minX) + (CGFloat(destinationX) + 0.5) / scale - 0.5
            let x0 = Int(floor(sourceX))
            let x1 = x0 + 1
            let fx = sourceX - CGFloat(x0)
            let outputIndex = ((targetY + destinationY) * outputWidth + targetX + destinationX) * bytesPerPixel

            for channel in 0..<bytesPerPixel {
                let top = sourceComponent(x: x0, y: y0, channel: channel, mask: frameData.mask) * (1 - fx)
                    + sourceComponent(x: x1, y: y0, channel: channel, mask: frameData.mask) * fx
                let bottom = sourceComponent(x: x0, y: y1, channel: channel, mask: frameData.mask) * (1 - fx)
                    + sourceComponent(x: x1, y: y1, channel: channel, mask: frameData.mask) * fx
                outputPixels[outputIndex + channel] = UInt8(clamping: Int((top * (1 - fy) + bottom * fy).rounded()))
            }
        }
    }
}

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let provider = CGDataProvider(data: Data(outputPixels) as CFData),
      let outputImage = CGImage(
        width: outputWidth,
        height: outputHeight,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: outputWidth * bytesPerPixel,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
      ),
      let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)
else {
    fputs("Could not create output image.\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(destination, outputImage, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("Could not write output image.\n", stderr)
    exit(1)
}

let formattedScale = String(format: "%.3f", scale)
print("Wrote \(outputURL.path) (\(outputWidth)x\(outputHeight), scale \(formattedScale))")
