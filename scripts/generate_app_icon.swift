import AppKit

let size = NSSize(width: 1024, height: 1024)
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Could not create icon canvas")
}
bitmap.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

let bounds = NSRect(origin: .zero, size: size)
let gradient = NSGradient(colors: [
    NSColor(red: 1.0, green: 0.38, blue: 0.58, alpha: 1),
    NSColor(red: 0.55, green: 0.12, blue: 0.62, alpha: 1)
])!
gradient.draw(in: bounds, angle: -45)

let glow = NSBezierPath(ovalIn: NSRect(x: 132, y: 194, width: 760, height: 760))
NSColor.white.withAlphaComponent(0.12).setFill()
glow.fill()

let heart = NSBezierPath()
heart.move(to: NSPoint(x: 512, y: 220))
heart.curve(to: NSPoint(x: 170, y: 570), controlPoint1: NSPoint(x: 410, y: 310), controlPoint2: NSPoint(x: 170, y: 380))
heart.curve(to: NSPoint(x: 512, y: 835), controlPoint1: NSPoint(x: 170, y: 785), controlPoint2: NSPoint(x: 405, y: 840))
heart.curve(to: NSPoint(x: 854, y: 570), controlPoint1: NSPoint(x: 619, y: 840), controlPoint2: NSPoint(x: 854, y: 785))
heart.curve(to: NSPoint(x: 512, y: 220), controlPoint1: NSPoint(x: 854, y: 380), controlPoint2: NSPoint(x: 614, y: 310))
heart.close()
NSColor(red: 1.0, green: 0.88, blue: 0.94, alpha: 1).setFill()
heart.fill()
NSColor.white.withAlphaComponent(0.8).setStroke()
heart.lineWidth = 22
heart.stroke()

NSColor(red: 0.30, green: 0.06, blue: 0.23, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 395, y: 545, width: 38, height: 52)).fill()
NSBezierPath(ovalIn: NSRect(x: 591, y: 545, width: 38, height: 52)).fill()

let smile = NSBezierPath()
smile.move(to: NSPoint(x: 382, y: 500))
smile.curve(to: NSPoint(x: 642, y: 500), controlPoint1: NSPoint(x: 438, y: 375), controlPoint2: NSPoint(x: 586, y: 375))
smile.lineWidth = 28
smile.lineCapStyle = .round
NSColor(red: 0.30, green: 0.06, blue: 0.23, alpha: 1).setStroke()
smile.stroke()

NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render icon")
}
try png.write(to: URL(fileURLWithPath: "LoveRun/Resources/Assets.xcassets/AppIcon.appiconset/LoveRunIcon.png"))
