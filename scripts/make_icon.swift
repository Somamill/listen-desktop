import AppKit

let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSGraphicsContext.current?.imageInterpolation = .high

func ink(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896),
                        xRadius: 203, yRadius: 203)
NSGradient(colors: [ink(0x6C8295), ink(0x293B4C), ink(0x16232F)])!.draw(in: tile, angle: -58)
ink(0xD9ECFC).withAlphaComponent(0.55).setStroke()
tile.lineWidth = 5
tile.stroke()

let aperture = NSBezierPath(ovalIn: NSRect(x: 235, y: 235, width: 554, height: 554))
NSGradient(starting: ink(0x213446), ending: ink(0x536C82))!.draw(in: aperture, angle: -52)
ink(0xBCD3E9).withAlphaComponent(0.52).setStroke()
aperture.lineWidth = 8
aperture.stroke()

for (index, height) in [116, 218, 310, 218, 116].enumerated() {
    let bar = NSBezierPath(roundedRect: NSRect(x: 337 + 75 * index, y: 512 - height / 2,
                                               width: 50, height: height), xRadius: 25, yRadius: 25)
    NSGradient(starting: ink(0xEEF7FC), ending: ink(0xBDD7ED))!.draw(in: bar, angle: -90)
}

let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
