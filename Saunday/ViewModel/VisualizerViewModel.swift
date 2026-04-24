import AppKit
import Observation

@Observable
final class VisualizerViewModel {
    private let audio: AudioCaptureManager
    private let nowPlaying: NowPlayingManager

    var barMagnitudes: [Float] { audio.barMagnitudes }
    var artwork: NSImage?      { nowPlaying.artwork }

    init(audio: AudioCaptureManager, nowPlaying: NowPlayingManager) {
        self.audio = audio
        self.nowPlaying = nowPlaying
    }
}
