// Draws the YouTube play-button glyph (red rounded rect + white triangle)
// as a 1024px PNG for the app icon. Run: swift gen_icon.swift
import AppKit

let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()

// Full-icon red background (macOS rounded-square, standard ~185px radius at 1024)
NSColor(red: 1.0, green: 0, blue: 0, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: S, height: S),
             xRadius: 185, yRadius: 185).fill()

// enlarged white play triangle, centered, pointing right
let tri = NSBezierPath()
let cx = S / 2, cy = S / 2
tri.move(to: NSPoint(x: cx - 180, y: cy - 250))
tri.line(to: NSPoint(x: cx - 180, y: cy + 250))
tri.line(to: NSPoint(x: cx + 256, y: cy))
tri.close()
NSColor.white.setFill()
tri.fill()

img.unlockFocus()

let tiff = img.tiffRepresentation!
let png = NSBitmapImageRep(data: tiff)!.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "icon_1024.png"))
print("wrote icon_1024.png")
