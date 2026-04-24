import AppKit
import SwiftUI
import Observation

@Observable
final class VisualizerViewModel {
    private let audio: AudioCaptureManager
    private let nowPlaying: NowPlayingManager

    var barMagnitudes: [Float] { audio.barMagnitudes }
    var artwork: NSImage?      { nowPlaying.artwork }

    var accentColor: Color? {
        guard let c = nowPlaying.accentNSColor else { return nil }
        return Color(nsColor: c)
    }

    // Paleta de 4 colores del artwork para el MeshGradient
    var meshPalette: [Color] {
        nowPlaying.paletteNSColors.map { Color(nsColor: $0) }
    }

    var barColor: Color {
        guard let c = nowPlaying.accentNSColor else { return .white }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        // Saturación mínima 0.7 y brightness fijo en 0.95 — siempre vibrante y visible
        let vivid = NSColor(hue: h,
                            saturation: max(0.70, s),
                            brightness: 0.95,
                            alpha: 1.0)
        return Color(nsColor: vivid)
    }

    init(audio: AudioCaptureManager, nowPlaying: NowPlayingManager) {
        self.audio = audio
        self.nowPlaying = nowPlaying
    }
}
