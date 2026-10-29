import AppKit
// Small build-time native helper, not a runtime dependency or Xcode project.
let args = CommandLine.arguments
if args.count != 3 { fatalError("usage: icon source-image output.iconset") }
guard let source = NSImage(contentsOfFile: args[1]) else { fatalError("cannot read official icon") }
try FileManager.default.createDirectory(atPath: args[2], withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
 for scale in [1, 2] {
  let px = size * scale
  let n = CGFloat(px)
  let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  source.draw(in: NSRect(x: 0, y: 0, width: n, height: n))
  let badge = NSRect(x: n * 0.62, y: n * 0.035, width: n * 0.345, height: n * 0.345)
  NSColor.white.setStroke()
  NSColor(calibratedRed: 0.43, green: 0.23, blue: 0.86, alpha: 1).setFill()
  let circle = NSBezierPath(ovalIn: badge)
  circle.lineWidth = max(1, n * 0.018)
  circle.fill(); circle.stroke()
  let attr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: n * 0.24, weight: .bold), .foregroundColor: NSColor.white]
  let letter = "P" as NSString
  let s = letter.size(withAttributes: attr)
  letter.draw(at: NSPoint(x: badge.midX - s.width / 2, y: badge.midY - s.height / 2), withAttributes: attr)
  NSGraphicsContext.restoreGraphicsState()
  let suffix = scale == 2 ? "@2x" : ""
  try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2] + "/icon_\(size)x\(size)\(suffix).png"))
 }
}
