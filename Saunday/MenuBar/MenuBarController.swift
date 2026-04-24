import AppKit
import SwiftUI
import ServiceManagement

final class MenuBarController: NSObject {
    private let viewModel: VisualizerViewModel
    private(set) var statusItem: NSStatusItem?
    private let menuBarWidth: CGFloat = 100
    var dynamicIslandController: DynamicIslandController?
    private weak var dynamicIslandMenuItem: NSMenuItem?

    init(viewModel: VisualizerViewModel) {
        self.viewModel = viewModel
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: menuBarWidth)
        statusItem?.isVisible = true

        guard let button = statusItem?.button else { return }

        let hosting = NSHostingView(rootView: MenuBarView()
            .environment(viewModel)
        )
        hosting.frame = NSRect(x: 0, y: 0, width: menuBarWidth, height: 22)
        hosting.sizingOptions = []

        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(hosting)
        button.frame = hosting.frame

        let menu = NSMenu()

        let launchItem = NSMenuItem(
            title: "Abrir al iniciar sesión",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off

        let islandItem = NSMenuItem(
            title: "Dynamic Island",
            action: #selector(toggleDynamicIsland),
            keyEquivalent: ""
        )
        islandItem.target = self
        dynamicIslandMenuItem = islandItem

        menu.addItem(launchItem)
        menu.addItem(islandItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Salir",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem?.menu = menu
    }

    func configureDynamicIsland(_ controller: DynamicIslandController) {
        dynamicIslandController = controller
        controller.onStateChanged = { [weak self] isActive in
            self?.dynamicIslandMenuItem?.state = isActive ? .on : .off
        }
    }

    @objc private func toggleDynamicIsland() {
        dynamicIslandController?.toggle(statusItem: statusItem)
        dynamicIslandMenuItem?.state = (dynamicIslandController?.isActive == true) ? .on : .off
    }

    @objc private func toggleLaunchAtLogin(sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                sender.state = .off
            } else {
                try service.register()
                sender.state = .on
            }
        } catch {
            print("Error toggling launch at login: \(error.localizedDescription)")
            sender.state = (service.status == .enabled) ? .on : .off
        }
    }
}
