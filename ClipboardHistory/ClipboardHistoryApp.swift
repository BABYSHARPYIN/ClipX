import SwiftUI
import AppKit

@main
struct ClipboardHistoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hotkeyMonitor: GlobalHotkeyMonitor?
    fileprivate var popoverVisible = false

    let viewModel = ClipboardViewModel()
    let locale = LocaleManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        setupHotkey()
        viewModel.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stopMonitoring()
        hotkeyMonitor?.stop()
    }

    private var aboutWindow: NSWindow?
    private var feedbackWindow: NSWindow?
    private var hotkeySettingsWindow: NSWindow?
    private var cursorAnchorWindow: NSWindow?

    private var rightClickMenu: NSMenu {
        let menu = NSMenu()

        let langMenu = NSMenu()
        for lang in AppLanguage.allCases {
            let item = NSMenuItem(title: lang.label, action: #selector(switchLanguage(_:)), keyEquivalent: "")
            item.representedObject = lang.rawValue
            item.state = locale.language == lang ? .on : .off
            langMenu.addItem(item)
        }
        let langItem = NSMenuItem(title: "Language / 语言", action: nil, keyEquivalent: "")
        langItem.submenu = langMenu
        menu.addItem(langItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: locale.tr("app.hotkey"), action: #selector(showHotkeySettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: locale.tr("app.about"), action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: locale.tr("app.feedback"), action: #selector(showFeedback), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: locale.tr("app.quit"), action: #selector(quitApp), keyEquivalent: "q"))
        return menu
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let icon = NSImage(
                systemSymbolName: "doc.on.clipboard",
                accessibilityDescription: "ClipX"
            )
            icon?.isTemplate = true
            icon?.size = NSSize(width: 18, height: 18)
            button.image = icon
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        let contentView = PopoverContentView()
            .environmentObject(viewModel)
            .environmentObject(locale)
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.contentSize = NSSize(width: 380, height: 520)
    }

    private func setupHotkey() {
        hotkeyMonitor = GlobalHotkeyMonitor { [weak self] in
            self?.showPopover()
        }
        hotkeyMonitor?.start()
    }

    @objc func handleClick() {
        guard let button = statusItem.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            rightClickMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY), in: button)
            return
        }
        if popoverVisible {
            popover.performClose(nil)
            popoverVisible = false
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            popoverVisible = true
        }
    }

    func showPopover() {
        // Hotkey: use cursor position
        if popoverVisible {
            popover.performClose(nil)
            popoverVisible = false
            cursorAnchorWindow?.orderOut(nil)
            return
        }
        showPopoverAtCursor()
    }

    private func showPopoverAtCursor() {
        let mouse = NSEvent.mouseLocation

        // Try cursor position
        if NSScreen.screens.contains(where: { NSMouseInRect(mouse, $0.frame, false) }) {
            let rect = NSRect(x: mouse.x - 1, y: mouse.y - 1, width: 2, height: 2)

            if cursorAnchorWindow == nil {
                let w = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
                w.isOpaque = false
                w.backgroundColor = .clear
                w.ignoresMouseEvents = true
                w.level = .floating
                cursorAnchorWindow = w
            }
            cursorAnchorWindow?.setFrame(rect, display: false)
            cursorAnchorWindow?.orderFront(nil)

            NSApp.activate(ignoringOtherApps: true)
            let anchor = cursorAnchorWindow!.contentView!
            popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            popoverVisible = true
            return
        }

        // Fallback: menu bar
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        popoverVisible = true
    }

    func closePopover() {
        if popoverVisible {
            popover.performClose(nil)
            popoverVisible = false
        }
        cursorAnchorWindow?.orderOut(nil)
    }

    @objc private func showAbout() {
        if aboutWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 280),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false
            )
            window.title = "关于 ClipX"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: AboutView().environmentObject(locale))
            aboutWindow = window
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showFeedback() {
        if feedbackWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false
            )
            window.title = "反馈"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: FeedbackView().environmentObject(locale))
            feedbackWindow = window
        }
        feedbackWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showHotkeySettings() {
        if hotkeySettingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 260),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false
            )
            window.title = "快捷键"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: HotkeySettingsView().environmentObject(locale))
            hotkeySettingsWindow = window
        }
        hotkeySettingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func switchLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let lang = AppLanguage(rawValue: raw) else { return }
        locale.language = lang
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        popoverVisible = false
    }
}
