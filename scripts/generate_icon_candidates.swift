#!/usr/bin/env swift

import AppKit
import Foundation

struct Palette {
    let top: NSColor
    let bottom: NSColor
    let accent: NSColor
    let foreground: NSColor
    let secondary: NSColor
}

struct Candidate {
    let name: String
    let palette: Palette
    let draw: (_ bounds: NSRect, _ palette: Palette) -> Void
}

let defaultOutputDirectory = URL(fileURLWithPath: "assets/icon-candidates", isDirectory: true)

func parseArguments() -> (outDir: URL, size: Int) {
    var outDir = defaultOutputDirectory
    var size = 1024

    var index = 1
    let args = CommandLine.arguments
    while index < args.count {
        let arg = args[index]
        switch arg {
        case "--out-dir":
            index += 1
            if index < args.count {
                outDir = URL(fileURLWithPath: args[index], isDirectory: true)
            }
        case "--size":
            index += 1
            if index < args.count, let parsed = Int(args[index]), parsed > 0 {
                size = parsed
            }
        default:
            break
        }
        index += 1
    }

    return (outDir, size)
}

func makeBitmap(size: Int) -> NSBitmapImageRep? {
    NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )
}

func roundedRect(in bounds: NSRect, inset: CGFloat, radius: CGFloat) -> NSBezierPath {
    let rect = bounds.insetBy(dx: inset, dy: inset)
    return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawBackground(bounds: NSRect, palette: Palette) {
    let gradient = NSGradient(starting: palette.top, ending: palette.bottom)
    let path = roundedRect(in: bounds, inset: bounds.width * 0.05, radius: bounds.width * 0.23)
    gradient?.draw(in: path, angle: -90)
}

func drawShadow(_ path: NSBezierPath, opacity: CGFloat, blur: CGFloat, y: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = blur
    shadow.shadowColor = NSColor.black.withAlphaComponent(opacity)
    shadow.shadowOffset = NSSize(width: 0, height: y)
    shadow.set()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
}

func drawFoldedSheet(bounds: NSRect, palette: Palette) {
    let w = bounds.width
    let sheetRect = NSRect(x: w * 0.26, y: w * 0.18, width: w * 0.48, height: w * 0.62)
    let sheet = NSBezierPath(roundedRect: sheetRect, xRadius: w * 0.04, yRadius: w * 0.04)

    palette.foreground.withAlphaComponent(0.95).setFill()
    drawShadow(sheet, opacity: 0.3, blur: w * 0.02, y: -w * 0.01)
    sheet.fill()

    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: sheetRect.maxX - w * 0.12, y: sheetRect.maxY))
    fold.line(to: NSPoint(x: sheetRect.maxX, y: sheetRect.maxY - w * 0.12))
    fold.line(to: NSPoint(x: sheetRect.maxX - w * 0.12, y: sheetRect.maxY - w * 0.12))
    fold.close()
    palette.secondary.setFill()
    fold.fill()

    let m = NSBezierPath()
    m.lineWidth = w * 0.04
    m.lineCapStyle = .round
    m.lineJoinStyle = .round
    m.move(to: NSPoint(x: w * 0.35, y: w * 0.48))
    m.line(to: NSPoint(x: w * 0.42, y: w * 0.35))
    m.line(to: NSPoint(x: w * 0.5, y: w * 0.5))
    m.line(to: NSPoint(x: w * 0.58, y: w * 0.35))
    m.line(to: NSPoint(x: w * 0.65, y: w * 0.48))
    palette.accent.setStroke()
    m.stroke()
}

func drawSplitPane(bounds: NSRect, palette: Palette) {
    let w = bounds.width
    let card = roundedRect(in: bounds, inset: w * 0.17, radius: w * 0.06)
    palette.foreground.withAlphaComponent(0.96).setFill()
    drawShadow(card, opacity: 0.25, blur: w * 0.02, y: -w * 0.01)
    card.fill()

    let divider = NSBezierPath()
    divider.move(to: NSPoint(x: w * 0.5, y: w * 0.23))
    divider.line(to: NSPoint(x: w * 0.5, y: w * 0.77))
    divider.lineWidth = w * 0.018
    divider.lineCapStyle = .round
    palette.secondary.setStroke()
    divider.stroke()

    let lines = [0.7, 0.63, 0.56, 0.49]
    for line in lines {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: w * 0.26, y: w * line))
        path.line(to: NSPoint(x: w * 0.45, y: w * line))
        path.lineWidth = w * 0.014
        path.lineCapStyle = .round
        palette.secondary.withAlphaComponent(0.8).setStroke()
        path.stroke()
    }

    let eye = NSBezierPath()
    eye.move(to: NSPoint(x: w * 0.58, y: w * 0.5))
    eye.curve(to: NSPoint(x: w * 0.79, y: w * 0.5), controlPoint1: NSPoint(x: w * 0.64, y: w * 0.6), controlPoint2: NSPoint(x: w * 0.73, y: w * 0.6))
    eye.curve(to: NSPoint(x: w * 0.58, y: w * 0.5), controlPoint1: NSPoint(x: w * 0.73, y: w * 0.4), controlPoint2: NSPoint(x: w * 0.64, y: w * 0.4))
    eye.close()
    palette.accent.setFill()
    eye.fill()

    let pupil = NSBezierPath(ovalIn: NSRect(x: w * 0.665, y: w * 0.465, width: w * 0.04, height: w * 0.04))
    palette.top.setFill()
    pupil.fill()
}

func drawMonogram(bounds: NSRect, palette: Palette) {
    let w = bounds.width
    let ringRect = NSRect(x: w * 0.17, y: w * 0.17, width: w * 0.66, height: w * 0.66)
    let ring = NSBezierPath(ovalIn: ringRect)
    palette.foreground.withAlphaComponent(0.92).setFill()
    drawShadow(ring, opacity: 0.22, blur: w * 0.02, y: -w * 0.01)
    ring.fill()

    let baseFontSize = w * 0.28
    let mFont = NSFont.systemFont(ofSize: baseFontSize, weight: .black)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: mFont,
        .foregroundColor: palette.accent
    ]
    let m = NSAttributedString(string: "M", attributes: attrs)
    let mSize = m.size()

    let arrowProbe = NSAttributedString(
        string: "⬇︎",
        attributes: [.font: mFont]
    )
    let probeHeight = max(arrowProbe.size().height, 1)
    let arrowFontSize = baseFontSize * (mSize.height / probeHeight)
    let arrowFont = NSFont.systemFont(ofSize: arrowFontSize, weight: .black)
    let downArrowAttrs: [NSAttributedString.Key: Any] = [
        .font: arrowFont,
        .foregroundColor: palette.secondary
    ]
    let downArrow = NSAttributedString(string: "⬇︎", attributes: downArrowAttrs)
    let arrowSize = downArrow.size()

    let spacing = w * 0.03
    let groupWidth = mSize.width + spacing + arrowSize.width
    let groupHeight = max(mSize.height, arrowSize.height)

    let groupOriginX = ringRect.midX - groupWidth * 0.5
    let groupOriginY = ringRect.midY - groupHeight * 0.5

    let mOrigin = NSPoint(x: groupOriginX, y: groupOriginY + (groupHeight - mSize.height) * 0.5)
    let arrowOrigin = NSPoint(
        x: mOrigin.x + mSize.width + spacing,
        y: groupOriginY + (groupHeight - arrowSize.height) * 0.5
    )

    let mNudgeX = w * 0.04
    m.draw(at: NSPoint(x: mOrigin.x + mNudgeX, y: mOrigin.y))
    downArrow.draw(at: arrowOrigin)
}

func drawTableIcon(bounds: NSRect, palette: Palette) {
    let w = bounds.width
    let tableRect = NSRect(x: w * 0.2, y: w * 0.24, width: w * 0.6, height: w * 0.52)
    let outer = NSBezierPath(roundedRect: tableRect, xRadius: w * 0.03, yRadius: w * 0.03)
    palette.foreground.withAlphaComponent(0.95).setFill()
    drawShadow(outer, opacity: 0.25, blur: w * 0.02, y: -w * 0.01)
    outer.fill()

    palette.secondary.setStroke()
    outer.lineWidth = w * 0.012
    outer.stroke()

    let rowY = [0.62, 0.5, 0.38]
    for y in rowY {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: tableRect.minX, y: w * y))
        path.line(to: NSPoint(x: tableRect.maxX, y: w * y))
        path.lineWidth = w * 0.01
        palette.secondary.withAlphaComponent(0.9).setStroke()
        path.stroke()
    }

    let colX = [0.4, 0.6]
    for x in colX {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: w * x, y: tableRect.minY))
        path.line(to: NSPoint(x: w * x, y: tableRect.maxY))
        path.lineWidth = w * 0.01
        palette.secondary.withAlphaComponent(0.9).setStroke()
        path.stroke()
    }

    let check = NSBezierPath()
    check.lineWidth = w * 0.03
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    check.move(to: NSPoint(x: w * 0.29, y: w * 0.31))
    check.line(to: NSPoint(x: w * 0.35, y: w * 0.27))
    check.line(to: NSPoint(x: w * 0.45, y: w * 0.37))
    palette.accent.setStroke()
    check.stroke()
}

func drawPreviewLens(bounds: NSRect, palette: Palette) {
    let w = bounds.width
    let body = roundedRect(in: bounds, inset: w * 0.18, radius: w * 0.09)
    palette.foreground.withAlphaComponent(0.95).setFill()
    drawShadow(body, opacity: 0.24, blur: w * 0.02, y: -w * 0.01)
    body.fill()

    let hash = NSBezierPath()
    hash.lineWidth = w * 0.022
    hash.lineCapStyle = .round
    hash.move(to: NSPoint(x: w * 0.3, y: w * 0.62))
    hash.line(to: NSPoint(x: w * 0.5, y: w * 0.62))
    hash.move(to: NSPoint(x: w * 0.28, y: w * 0.52))
    hash.line(to: NSPoint(x: w * 0.48, y: w * 0.52))
    hash.move(to: NSPoint(x: w * 0.35, y: w * 0.68))
    hash.line(to: NSPoint(x: w * 0.31, y: w * 0.46))
    hash.move(to: NSPoint(x: w * 0.45, y: w * 0.68))
    hash.line(to: NSPoint(x: w * 0.41, y: w * 0.46))
    palette.secondary.setStroke()
    hash.stroke()

    let lens = NSBezierPath(ovalIn: NSRect(x: w * 0.52, y: w * 0.42, width: w * 0.23, height: w * 0.23))
    palette.accent.setFill()
    lens.fill()

    let center = NSBezierPath(ovalIn: NSRect(x: w * 0.605, y: w * 0.505, width: w * 0.06, height: w * 0.06))
    palette.top.setFill()
    center.fill()
}

func candidates() -> [Candidate] {
    [
        Candidate(
            name: "icon-candidate-01-sheet",
            palette: Palette(
                top: NSColor(calibratedRed: 0.29, green: 0.42, blue: 0.93, alpha: 1),
                bottom: NSColor(calibratedRed: 0.14, green: 0.19, blue: 0.47, alpha: 1),
                accent: NSColor(calibratedRed: 0.29, green: 0.95, blue: 0.73, alpha: 1),
                foreground: NSColor(calibratedWhite: 1, alpha: 1),
                secondary: NSColor(calibratedRed: 0.30, green: 0.36, blue: 0.50, alpha: 1)
            ),
            draw: drawFoldedSheet
        ),
        Candidate(
            name: "icon-candidate-02-split",
            palette: Palette(
                top: NSColor(calibratedRed: 0.97, green: 0.53, blue: 0.26, alpha: 1),
                bottom: NSColor(calibratedRed: 0.59, green: 0.24, blue: 0.12, alpha: 1),
                accent: NSColor(calibratedRed: 0.97, green: 0.85, blue: 0.27, alpha: 1),
                foreground: NSColor(calibratedWhite: 0.97, alpha: 1),
                secondary: NSColor(calibratedRed: 0.34, green: 0.25, blue: 0.19, alpha: 1)
            ),
            draw: drawSplitPane
        ),
        Candidate(
            name: "icon-candidate-03-monogram",
            palette: Palette(
                top: NSColor(calibratedRed: 0.18, green: 0.84, blue: 0.75, alpha: 1),
                bottom: NSColor(calibratedRed: 0.05, green: 0.35, blue: 0.37, alpha: 1),
                accent: NSColor(calibratedRed: 1.0, green: 0.99, blue: 0.95, alpha: 1),
                foreground: NSColor(calibratedRed: 0.08, green: 0.18, blue: 0.23, alpha: 1),
                secondary: NSColor(calibratedRed: 0.65, green: 0.99, blue: 0.89, alpha: 1)
            ),
            draw: drawMonogram
        ),
        Candidate(
            name: "icon-candidate-04-table",
            palette: Palette(
                top: NSColor(calibratedRed: 0.61, green: 0.39, blue: 0.94, alpha: 1),
                bottom: NSColor(calibratedRed: 0.21, green: 0.14, blue: 0.46, alpha: 1),
                accent: NSColor(calibratedRed: 0.93, green: 0.79, blue: 1.0, alpha: 1),
                foreground: NSColor(calibratedWhite: 0.97, alpha: 1),
                secondary: NSColor(calibratedRed: 0.39, green: 0.29, blue: 0.64, alpha: 1)
            ),
            draw: drawTableIcon
        ),
        Candidate(
            name: "icon-candidate-05-lens",
            palette: Palette(
                top: NSColor(calibratedRed: 0.18, green: 0.79, blue: 0.34, alpha: 1),
                bottom: NSColor(calibratedRed: 0.08, green: 0.33, blue: 0.12, alpha: 1),
                accent: NSColor(calibratedRed: 0.84, green: 0.98, blue: 0.52, alpha: 1),
                foreground: NSColor(calibratedWhite: 0.95, alpha: 1),
                secondary: NSColor(calibratedRed: 0.24, green: 0.45, blue: 0.24, alpha: 1)
            ),
            draw: drawPreviewLens
        )
    ]
}

func renderCandidate(_ candidate: Candidate, size: Int) -> NSBitmapImageRep? {
    guard let bitmap = makeBitmap(size: size),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        return nil
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    bounds.fill()

    drawBackground(bounds: bounds, palette: candidate.palette)
    candidate.draw(bounds, candidate.palette)

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icongen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG for \(url.path)"])
    }
    try data.write(to: url)
}

let options = parseArguments()
let manager = FileManager.default
try manager.createDirectory(at: options.outDir, withIntermediateDirectories: true)

var written: [URL] = []
for candidate in candidates() {
    guard let bitmap = renderCandidate(candidate, size: options.size) else {
        fputs("Failed to render \(candidate.name)\n", stderr)
        continue
    }

    let outputURL = options.outDir.appendingPathComponent("\(candidate.name).png")
    do {
        try writePNG(bitmap, to: outputURL)
        written.append(outputURL)
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
    }
}

if written.isEmpty {
    fputs("No icons were generated.\n", stderr)
    exit(1)
}

print("Generated \(written.count) icon candidates:")
for url in written {
    print(url.path)
}
