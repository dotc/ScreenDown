import AppKit

// Draw directly at the requested display scale; alerts never upscale a cached icon.
enum ScreenDownIcon {
    static func image(size: CGFloat = 64) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            let transform = NSAffineTransform()
            transform.translateX(by: rect.minX, yBy: rect.minY)
            transform.scaleX(by: rect.width / 1024, yBy: rect.height / 1024)
            transform.concat()
    let tile = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 198, yRadius: 198)
    NSColor.white.setFill()
    tile.fill()
    NSColor(calibratedWhite: 0.88, alpha: 1).setStroke()
    tile.lineWidth = 2
    tile.stroke()
    NSColor.black.setStroke()
    let screen = NSBezierPath(roundedRect: NSRect(x: 220, y: 350, width: 584, height: 400), xRadius: 45, yRadius: 45)
    screen.lineWidth = 44; screen.stroke()
    let stand = NSBezierPath(); stand.lineWidth = 42; stand.lineCapStyle = .round
    stand.move(to: NSPoint(x: 512, y: 350)); stand.line(to: NSPoint(x: 512, y: 255))
    stand.move(to: NSPoint(x: 390, y: 255)); stand.line(to: NSPoint(x: 634, y: 255)); stand.stroke()
    let arrow = NSBezierPath(); arrow.lineWidth = 42; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: 512, y: 654)); arrow.line(to: NSPoint(x: 512, y: 460))
    arrow.move(to: NSPoint(x: 430, y: 536)); arrow.line(to: NSPoint(x: 512, y: 454)); arrow.line(to: NSPoint(x: 594, y: 536)); arrow.stroke()
            return true
        }
        image.isTemplate = false
        return image
    }
}
