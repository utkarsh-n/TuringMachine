import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let dimension = 1024
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let asset = root.appendingPathComponent("TuringMachine/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: asset, withIntermediateDirectories: true)
let space = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: dimension, height: dimension, bitsPerComponent: 8,
                        bytesPerRow: dimension * 4, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}
func gradient(_ colors: [CGColor], _ start: CGPoint, _ end: CGPoint) {
    context.drawLinearGradient(CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}
func circle(_ rect: CGRect, _ colors: [CGColor]) {
    context.saveGState(); context.addEllipse(in: rect); context.clip()
    gradient(colors, CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.minY))
    context.restoreGState()
}
gradient([color(0.065, 0.11, 0.17), color(0.025, 0.037, 0.065)], CGPoint(x: 0, y: 1024), CGPoint(x: 1024, y: 0))
for index in 0...20 {
    context.move(to: CGPoint(x: index * 52, y: 0)); context.addLine(to: CGPoint(x: index * 52, y: 1024))
    context.move(to: CGPoint(x: 0, y: index * 52)); context.addLine(to: CGPoint(x: 1024, y: index * 52))
    context.setStrokeColor(color(0.5, 0.8, 0.9, 0.035)); context.setLineWidth(1); context.strokePath()
}
let body = CGRect(x: 183, y: 335, width: 658, height: 658)
context.saveGState(); context.setShadow(offset: CGSize(width: 0, height: -22), blur: 40, color: color(0, 0, 0, 0.8))
circle(body, [color(0.58, 0.65, 0.68), color(0.13, 0.16, 0.19), color(0.03, 0.04, 0.07), color(0.23, 0.26, 0.3)])
context.restoreGState()
circle(body.insetBy(dx: 10, dy: 10), [color(0.1, 0.14, 0.19), color(0.025, 0.05, 0.08)])
for tick in 0..<60 {
    let angle = Double(tick) / 60 * 2 * Double.pi
    let outer = 313.0
    let inner = tick.isMultiple(of: 5) ? 289.0 : 302.0
    context.move(to: CGPoint(x: 512 + sin(angle) * inner, y: 664 + cos(angle) * inner))
    context.addLine(to: CGPoint(x: 512 + sin(angle) * outer, y: 664 + cos(angle) * outer))
    context.setLineWidth(tick.isMultiple(of: 5) ? 3 : 1.5)
    context.setStrokeColor(color(0.44, 0.91, 0.95, tick < 42 ? 0.8 : 0.15)); context.strokePath()
}
let lens = body.insetBy(dx: 60, dy: 60)
circle(lens, [color(0.19, 0.32, 0.39), color(0.045, 0.10, 0.15), color(0.025, 0.075, 0.12)])
context.setLineWidth(3); context.setStrokeColor(color(0.65, 0.85, 0.92, 0.45)); context.strokeEllipse(in: lens)
context.saveGState(); context.addEllipse(in: lens); context.clip()
let shine = CGGradient(colorsSpace: space, colors: [color(0.7, 0.91, 1, 0.3), color(0.3, 0.7, 0.8, 0)] as CFArray, locations: nil)!
context.drawRadialGradient(shine, startCenter: CGPoint(x: 380, y: 835), startRadius: 0, endCenter: CGPoint(x: 380, y: 835), endRadius: 340, options: [])
context.restoreGState()
func text(_ text: String, size: CGFloat, at point: CGPoint, color: CGColor) {
    let font = CTFontCreateWithName("Menlo-Bold" as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): color]))
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    context.textPosition = CGPoint(x: point.x - bounds.width / 2, y: point.y - bounds.height / 2)
    CTLineDraw(line, context)
}
text("q₀", size: 131, at: CGPoint(x: 512, y: 682), color: color(0.48, 0.94, 0.97))
text("δ", size: 60, at: CGPoint(x: 512, y: 526), color: color(0.93, 0.78, 0.53))
// The editable tape is the instrument's unmistakable silhouette.
for index in -2...2 {
    let rect = CGRect(x: 512 + index * 148 - 65, y: 170, width: 130, height: 130)
    let path = CGPath(roundedRect: rect, cornerWidth: 23, cornerHeight: 23, transform: nil)
    context.addPath(path); context.setFillColor(index == 0 ? color(0.13, 0.34, 0.4) : color(0.09, 0.14, 0.19)); context.fillPath()
    context.addPath(path); context.setLineWidth(index == 0 ? 4 : 2)
    context.setStrokeColor(index == 0 ? color(0.48, 0.94, 0.97) : color(0.45, 0.64, 0.72, 0.4)); context.strokePath()
    text(index.isMultiple(of: 2) ? "1" : "0", size: 71, at: CGPoint(x: rect.midX, y: rect.midY + 6), color: color(0.77, 0.94, 0.96))
}
context.move(to: CGPoint(x: 491, y: 327)); context.addLine(to: CGPoint(x: 533, y: 327)); context.addLine(to: CGPoint(x: 512, y: 308)); context.closePath()
context.setFillColor(color(0.48, 0.94, 0.97)); context.fillPath()
let output = asset.appendingPathComponent("icon.png")
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Icon export failed") }
let contents = """
{"images":[{"filename":"icon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
"""
try contents.write(to: asset.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print(output.path)
