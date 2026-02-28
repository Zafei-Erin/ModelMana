//
//  ModelManaApp.swift
//  ModelMana
//
//  Created by Zafei on 2/1/26.
//

import SwiftUI
import AppKit

// Helper to set window level for macOS 14.6 compatibility
struct WindowLevelAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.level = .floating
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Generate ring icon from percentage using NSBitmapImageRep
func generateRingIcon(percentage: Double?) -> NSImage? {
    let size: CGFloat = 18
    let scale = NSScreen.main?.backingScaleFactor ?? 2
    let pixelSize = Int(size * scale)

    let image = NSImage(size: NSSize(width: size, height: size))

    // Create bitmap representation
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return nil
    }
    image.addRepresentation(rep)

    // Setup graphics context
    NSGraphicsContext.saveGraphicsState()
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        NSGraphicsContext.restoreGraphicsState()
        return nil
    }
    NSGraphicsContext.current = ctx

    // Scale context for retina display
    ctx.cgContext.saveGState()
    ctx.cgContext.scaleBy(x: scale, y: scale)

    // Draw content
    let center = NSPoint(x: size / 2, y: size / 2)
    let radius: CGFloat = 6  // Adjusted for lineWidth 5 (6 + 2.5 = 8.5 < 9)
    let lineWidth: CGFloat = 5

    // Background ring
    let backgroundPath = NSBezierPath(ovalIn: NSRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    ))
    backgroundPath.lineWidth = lineWidth
    NSColor.white.withAlphaComponent(0.3).setStroke()
    backgroundPath.stroke()

    // Progress ring
    if let pct = percentage, pct > 0 {
        let progress = min(pct / 100.0, 1.0)
        let startAngle: CGFloat = 90
        let endAngle = startAngle - (progress * 360)

        let progressPath = NSBezierPath()
        progressPath.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )
        progressPath.lineWidth = lineWidth
        progressPath.lineCapStyle = .round
        NSColor.white.setStroke()
        progressPath.stroke()
    }

    ctx.cgContext.restoreGState()
    NSGraphicsContext.restoreGraphicsState()

    image.isTemplate = true
    return image
}

@main
struct ModelManaApp: App {
    @State private var appState = AppState.shared

    /// Get ring icon for current usage
    private var ringIcon: NSImage? {
        _ = appState.iconUpdateTrigger
        return generateRingIcon(percentage: appState.currentUsagePercentage)
    }

    var body: some Scene {
        MenuBarExtra {
            ProviderListView()
        } label: {
            if let image = ringIcon {
                Image(nsImage: image)
            } else {
                Image(systemName: "circle")
            }
        }
        .menuBarExtraStyle(.window)

        Window("Provider Settings", id: "settings") {
            SettingsWindowView()
                .background(WindowLevelAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 420, height: 380)
    }
}
