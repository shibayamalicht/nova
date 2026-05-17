import AppKit
import Foundation

let size: CGFloat = 1024
let cornerRadius: CGFloat = size * 0.2237

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size)
let clipPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
clipPath.addClip()

let bg = NSGradient(colors: [
    NSColor(red: 0.04, green: 0.04, blue: 0.09, alpha: 1.0),
    NSColor(red: 0.09, green: 0.04, blue: 0.18, alpha: 1.0),
    NSColor(red: 0.02, green: 0.07, blue: 0.14, alpha: 1.0)
])!
bg.draw(in: rect, angle: -55)

let cyanGlow = NSGradient(colors: [
    NSColor(red: 0.00, green: 0.90, blue: 1.00, alpha: 0.55),
    NSColor(red: 0.00, green: 0.90, blue: 1.00, alpha: 0.00)
])!
cyanGlow.draw(fromCenter: NSPoint(x: size * 0.18, y: size * 0.82), radius: 0,
              toCenter: NSPoint(x: size * 0.18, y: size * 0.82), radius: size * 0.75,
              options: [])

let purpleGlow = NSGradient(colors: [
    NSColor(red: 0.66, green: 0.33, blue: 0.97, alpha: 0.65),
    NSColor(red: 0.66, green: 0.33, blue: 0.97, alpha: 0.00)
])!
purpleGlow.draw(fromCenter: NSPoint(x: size * 0.82, y: size * 0.18), radius: 0,
                toCenter: NSPoint(x: size * 0.82, y: size * 0.18), radius: size * 0.75,
                options: [])

let pinkGlow = NSGradient(colors: [
    NSColor(red: 0.93, green: 0.28, blue: 0.60, alpha: 0.30),
    NSColor(red: 0.93, green: 0.28, blue: 0.60, alpha: 0.00)
])!
pinkGlow.draw(fromCenter: NSPoint(x: size * 0.5, y: size * 0.5), radius: 0,
              toCenter: NSPoint(x: size * 0.5, y: size * 0.5), radius: size * 0.45,
              options: [])

func drawSparkle(center: NSPoint, outerR: CGFloat, innerR: CGFloat, color: NSColor, glowColor: NSColor, glowRadius: CGFloat) {
    let path = NSBezierPath()
    let points = 4
    for i in 0..<(points * 2) {
        let angle = (Double(i) * .pi / Double(points)) - .pi / 2
        let r = i % 2 == 0 ? outerR : innerR
        let x = center.x + CGFloat(cos(angle)) * r
        let y = center.y + CGFloat(sin(angle)) * r
        if i == 0 {
            path.move(to: NSPoint(x: x, y: y))
        } else {
            path.line(to: NSPoint(x: x, y: y))
        }
    }
    path.close()

    NSGraphicsContext.current?.saveGraphicsState()
    NSGraphicsContext.current?.cgContext.setShadow(
        offset: .zero,
        blur: glowRadius,
        color: glowColor.cgColor
    )
    color.setFill()
    path.fill()
    NSGraphicsContext.current?.restoreGraphicsState()
}

drawSparkle(
    center: NSPoint(x: size * 0.5, y: size * 0.5),
    outerR: size * 0.36,
    innerR: size * 0.055,
    color: NSColor.white,
    glowColor: NSColor(red: 0.5, green: 0.9, blue: 1.0, alpha: 0.95),
    glowRadius: size * 0.10
)

drawSparkle(
    center: NSPoint(x: size * 0.78, y: size * 0.72),
    outerR: size * 0.075,
    innerR: size * 0.012,
    color: NSColor(white: 1.0, alpha: 0.92),
    glowColor: NSColor(red: 0.65, green: 0.4, blue: 1.0, alpha: 0.9),
    glowRadius: size * 0.05
)

drawSparkle(
    center: NSPoint(x: size * 0.24, y: size * 0.26),
    outerR: size * 0.055,
    innerR: size * 0.009,
    color: NSColor(white: 1.0, alpha: 0.85),
    glowColor: NSColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.85),
    glowRadius: size * 0.04
)

let highlightPath = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2),
                                  xRadius: cornerRadius - 2,
                                  yRadius: cornerRadius - 2)
let highlight = NSGradient(colors: [
    NSColor(white: 1.0, alpha: 0.12),
    NSColor(white: 1.0, alpha: 0.0)
])!
NSGraphicsContext.current?.saveGraphicsState()
highlightPath.addClip()
highlight.draw(in: NSRect(x: 0, y: size * 0.6, width: size, height: size * 0.4), angle: -90)
NSGraphicsContext.current?.restoreGraphicsState()

image.unlockFocus()

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to encode PNG")
    exit(1)
}
try png.write(to: URL(fileURLWithPath: outputPath))
print("Saved: \(outputPath)")
