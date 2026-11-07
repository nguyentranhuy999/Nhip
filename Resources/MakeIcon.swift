import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconset = root.appendingPathComponent("Nhip.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for pixels in [16,32,64,128,256,512,1024] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: pixels * 4, bitsPerPixel: 32)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let p = CGFloat(pixels)
    let background = NSBezierPath(roundedRect: NSRect(x: p * 0.07, y: p * 0.07, width: p * 0.86, height: p * 0.86), xRadius: p * 0.21, yRadius: p * 0.21)
    NSGradient(starting: NSColor(calibratedRed: 0.39, green: 0.40, blue: 0.95, alpha: 1), ending: NSColor(calibratedRed: 0.22, green: 0.16, blue: 0.65, alpha: 1))!.draw(in: background, angle: -65)
    let line = NSBezierPath(); line.lineWidth = p * 0.065; line.lineCapStyle = .round; line.lineJoinStyle = .round
    line.move(to: NSPoint(x: p * 0.22, y: p * 0.49))
    for (x,y) in [(0.34,0.49),(0.42,0.69),(0.52,0.29),(0.63,0.56),(0.69,0.49),(0.79,0.49)] { line.line(to: NSPoint(x: p * x, y: p * y)) }
    NSColor.white.setStroke(); line.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    let names: [Int: [String]] = [16:["icon_16x16"],32:["icon_16x16@2x","icon_32x32"],64:["icon_32x32@2x"],128:["icon_128x128"],256:["icon_128x128@2x","icon_256x256"],512:["icon_256x256@2x","icon_512x512"],1024:["icon_512x512@2x"]]
    for name in names[pixels]! { try data.write(to: iconset.appendingPathComponent(name + ".png")) }
}
