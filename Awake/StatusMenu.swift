import AppKit
import SwiftUI

/// Menu bar icon + native NSMenu.
///
/// Every duration in the menu starts immediately (one click). While active,
/// the icon is filled and shows the remaining time ("1:42") or "∞".
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let controller: AwakeController
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var structureKey = ""
    private var currentSymbol = ""

    init(controller: AwakeController) {
        self.controller = controller
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize,
                                                                   weight: .regular)

        controller.onChange = { [weak self] in self?.refresh() }
        refresh()
    }

    // MARK: - Updating

    private func refresh() {
        updateButton()
        // Rebuild items only when something structural changes, not every second.
        let key = [
            "\(controller.isActive)", "\(controller.isIndefinite)",
            "\(controller.selectedMinutes ?? -1)", "\(controller.keepDisplayOn)",
            "\(controller.lastMinutes)",
        ].joined(separator: "|")
        if key != structureKey {
            structureKey = key
            rebuildMenu()
        }
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }

        let symbol = controller.isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
        if symbol != currentSymbol {
            currentSymbol = symbol
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Awake")
            image?.isTemplate = true // follows menu bar Light/Dark automatically
            button.image = image
        }

        let title = controller.menuBarTitle
        button.title = title.isEmpty ? "" : " " + title
        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
        button.toolTip = "\(controller.headline)\n\(controller.detail)"
        button.setAccessibilityLabel("Awake: \(controller.headline), \(controller.detail)")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        // Status header (SwiftUI, live)
        let header = NSMenuItem()
        let host = NSHostingView(rootView: StatusHeaderView(controller: controller))
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        header.view = host
        menu.addItem(header)
        menu.addItem(.separator())

        // Primary actions
        if controller.isActive {
            menu.addItem(item("Vypnout", key: ".", action: #selector(stopTapped)))
            if !controller.isIndefinite {
                menu.addItem(item("Prodloužit o 1 hodinu", action: #selector(extendTapped)))
            }
        } else {
            menu.addItem(item("Spustit na \(Format.duration(controller.lastMinutes))",
                              key: "\r", action: #selector(startLastTapped)))
        }

        // Durations — each one starts right away
        menu.addItem(.separator())
        menu.addItem(sectionHeader(controller.isActive ? "Změnit délku" : "Nechat vzhůru na"))
        for minutes in AwakeController.presetMinutes {
            let entry = item(Format.duration(minutes), action: #selector(durationTapped(_:)))
            entry.tag = minutes
            entry.state = (controller.isActive && controller.selectedMinutes == minutes) ? .on : .off
            menu.addItem(entry)
        }
        let indefinite = item("Dokud nevypnu", action: #selector(indefiniteTapped))
        indefinite.state = controller.isIndefinite ? .on : .off
        menu.addItem(indefinite)

        // Display option
        menu.addItem(.separator())
        let display = item("Nechat rozsvícený displej", action: #selector(toggleDisplayTapped))
        display.state = controller.keepDisplayOn ? .on : .off
        menu.addItem(display)

        menu.addItem(.separator())
        menu.addItem(item("Ukončit Awake", key: "q", action: #selector(quitTapped)))
    }

    private func item(_ title: String, key: String = "", action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func sectionHeader(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) {
            return NSMenuItem.sectionHeader(title: title)
        }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // MARK: - Actions

    @objc private func stopTapped() { controller.stop() }
    @objc private func extendTapped() { controller.extend(minutes: 60) }
    @objc private func startLastTapped() { controller.start(minutes: controller.lastMinutes) }
    @objc private func durationTapped(_ sender: NSMenuItem) { controller.start(minutes: sender.tag) }
    @objc private func indefiniteTapped() { controller.start(minutes: nil) }
    @objc private func toggleDisplayTapped() { controller.setKeepDisplayOn(!controller.keepDisplayOn) }
    @objc private func quitTapped() { NSApp.terminate(nil) }
}
