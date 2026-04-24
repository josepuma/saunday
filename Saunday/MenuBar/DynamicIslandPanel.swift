import AppKit
import SwiftUI

final class DynamicIslandPanel: NSPanel {
    private static let capsuleWidth: CGFloat = 100
    private static let capsuleHeight: CGFloat = 19

    // Set by DynamicIslandController after init so right-click can trigger disable
    var onDisable: (() -> Void)?

    init(viewModel: VisualizerViewModel) {
        let initialFrame = DynamicIslandPanel.frameForTopCenter()
        super.init(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = false
        ignoresMouseEvents = false

        let hosting = NSHostingView(rootView:
            MenuBarView()
                .environment(viewModel)
        )
        hosting.frame = NSRect(origin: .zero, size: initialFrame.size)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting

        setFrame(initialFrame, display: false)
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let item = NSMenuItem(title: "Volver al menú bar", action: #selector(handleDisable), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        NSMenu.popUpContextMenu(menu, with: event, for: contentView!)
    }

    @objc private func handleDisable() {
        onDisable?()
    }

    static func frameForTopCenter() -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 0, y: 0, width: capsuleWidth, height: capsuleHeight)
        }
        let sf = screen.frame
        let menuBarHeight = NSStatusBar.system.thickness
        let x = sf.minX + (sf.width - capsuleWidth) / 2
        let y = sf.maxY - menuBarHeight
        return NSRect(x: x, y: y, width: capsuleWidth, height: capsuleHeight)
    }
}

final class DynamicIslandController {
    private var panel: DynamicIslandPanel?
    private let viewModel: VisualizerViewModel
    private(set) var isActive = false
    var onStateChanged: ((Bool) -> Void)?

    init(viewModel: VisualizerViewModel) {
        self.viewModel = viewModel
    }

    func enable(hidingStatusItem statusItem: NSStatusItem?) {
        guard !isActive else { return }
        isActive = true
        statusItem?.isVisible = false

        let p = DynamicIslandPanel(viewModel: viewModel)
        p.onDisable = { [weak self] in
            self?.disable(showingStatusItem: statusItem)
        }
        p.orderFrontRegardless()
        panel = p
    }

    func disable(showingStatusItem statusItem: NSStatusItem?) {
        guard isActive else { return }
        isActive = false
        panel?.close()
        panel = nil
        statusItem?.isVisible = true
        onStateChanged?(false)
    }

    func toggle(statusItem: NSStatusItem?) {
        if isActive {
            disable(showingStatusItem: statusItem)
        } else {
            enable(hidingStatusItem: statusItem)
        }
    }
}
