import AppKit
let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let p = CGFloat(pixels)
        NSColor(calibratedRed: 0.10, green: 0.20, blue: 0.29, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: p*0.05, y: p*0.05, width: p*0.9, height: p*0.9), xRadius: p*0.20, yRadius: p*0.20).fill()
        for row in 0..<4 {
            for column in 0..<4 {
                let red = row == column
                (red ? NSColor(calibratedRed: 0.98, green: 0.34, blue: 0.32, alpha: 1) : NSColor(calibratedRed: 1, green: 0.76, blue: 0.24, alpha: row + column < 3 ? 1 : 0.16)).setFill()
                NSBezierPath(ovalIn: NSRect(x: p*(0.15 + Double(column)*0.18), y: p*(0.15 + Double(row)*0.18), width: p*0.15, height: p*0.15)).fill()
            }
        }
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(destination)/icon_\(size)x\(size)\(suffix).png"))
    }
}
