import AppKit

enum ColorExtractor {

    // Devuelve hasta `count` colores dominantes y distintos del artwork
    static func extractPalette(from image: NSImage, count: Int = 4) -> [NSColor] {
        guard let pixels = rasterize(image, size: CGSize(width: 40, height: 40)) else { return [] }

        // Recolectar todos los candidatos con su score
        struct Candidate {
            let color: NSColor
            let h: CGFloat
            let score: CGFloat
        }

        var candidates: [Candidate] = []

        for row in 0..<10 {
            for col in 0..<10 {
                let x = col * 4
                let y = row * 4
                let idx = (y * 40 + x) * 4

                let r = CGFloat(pixels[idx])     / 255.0
                let g = CGFloat(pixels[idx + 1]) / 255.0
                let b = CGFloat(pixels[idx + 2]) / 255.0

                let color = NSColor(red: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &br, alpha: &a)

                guard s > 0.20, br > 0.10, br < 0.97 else { continue }

                candidates.append(Candidate(color: color, h: h, score: s * br))
            }
        }

        candidates.sort { $0.score > $1.score }

        // Elegir colores suficientemente distintos en hue (mínimo 0.10 de distancia)
        var palette: [NSColor] = []
        for candidate in candidates {
            let tooClose = palette.contains { existing in
                var eh: CGFloat = 0, es: CGFloat = 0, eb: CGFloat = 0, ea: CGFloat = 0
                existing.getHue(&eh, saturation: &es, brightness: &eb, alpha: &ea)
                let diff = abs(candidate.h - eh)
                return min(diff, 1 - diff) < 0.10
            }
            if !tooClose {
                palette.append(candidate.color)
            }
            if palette.count == count { break }
        }

        // Si no hay suficientes colores distintos, rellenar con variaciones del primero
        if let first = palette.first {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            first.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            while palette.count < count {
                let shifted = NSColor(hue: (h + CGFloat(palette.count) * 0.12).truncatingRemainder(dividingBy: 1),
                                     saturation: max(0.3, s - 0.1),
                                     brightness: min(0.9, b + CGFloat(palette.count) * 0.1),
                                     alpha: 1.0)
                palette.append(shifted)
            }
        }

        return palette
    }

    // Mantener compatibilidad: devuelve el color más vibrante
    static func extractAccent(from image: NSImage) -> NSColor? {
        extractPalette(from: image, count: 1).first
    }

    private static func rasterize(_ image: NSImage, size: CGSize) -> [UInt8]? {
        let w = Int(size.width), h = Int(size.height)
        var pixels = [UInt8](repeating: 0, count: h * w * 4)

        guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: &pixels, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        image.draw(in: CGRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()

        return pixels
    }
}
