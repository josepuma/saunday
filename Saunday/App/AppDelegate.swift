import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let audio = AudioCaptureManager()
    private let nowPlaying = NowPlayingManager()
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let viewModel = VisualizerViewModel(audio: audio, nowPlaying: nowPlaying)
        menuBarController = MenuBarController(viewModel: viewModel)
        menuBarController?.setup()
        menuBarController?.configureDynamicIsland(DynamicIslandController(viewModel: viewModel))

        Task {
            await audio.checkCurrentPermission()
            if audio.permissionState == .granted {
                try? await audio.startCapture()
            }
        }
    }
}
