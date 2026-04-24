import SwiftUI
import Observation

@Observable
final class NowPlayingManager {
    var artwork: NSImage?
    var title: String?
    var accentNSColor: NSColor?
    var paletteNSColors: [NSColor] = []
    
    init() {
        setupObservers()
        updateInfo()
    }

    private func setupObservers() {
        // Notificación oficial de la App Música en macOS
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Un pequeño delay ayuda a que el archivo de imagen esté disponible
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self?.updateInfo()
            }
        }
    }

    func updateInfo() {
        // Este script le pide a Música que nos de la info.
        // Si no puede dar los bytes, devuelve "RETRY"
        let scriptSource = """
        if application "Music" is running then
            tell application "Music"
                if player state is playing then
                    set tName to name of current track
                    set tArtist to artist of current track
                    try
                        set artData to raw data of artwork 1 of current track
                        return {tName, tArtist, artData}
                    on error
                        return {tName, tArtist, "ERR"}
                    end try
                end if
            end tell
        end if
        return "NONE"
        """
        
        guard let script = NSAppleScript(source: scriptSource) else { return }
        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)

        if descriptor.numberOfItems >= 2 {
            let songTitle = descriptor.atIndex(1)?.stringValue ?? ""
            
            // Usamos .data para obtener el contenido binario del descriptor
            if let artDescriptor = descriptor.atIndex(3) {
                let rawData = artDescriptor.data
                
                if rawData.count > 100 {
                    if let image = NSImage(data: rawData) {
                        DispatchQueue.global(qos: .userInitiated).async {
                            let palette = ColorExtractor.extractPalette(from: image, count: 4)
                            DispatchQueue.main.async {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    self.title = songTitle
                                    self.artwork = image
                                    self.accentNSColor = palette.first
                                    self.paletteNSColors = palette
                                }
                            }
                        }
                        return // Salimos con éxito
                    }
                }
            }
            
            // Si llegamos aquí, no hubo imagen o fue inválida
            DispatchQueue.main.async {
                self.title = songTitle
                self.artwork = nil
                self.accentNSColor = nil
                self.paletteNSColors = []
            }
        }
    }
}
