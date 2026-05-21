import LogdeckCore
import AppKit
import SwiftUI

@main
struct LogdeckApp: App {
    @NSApplicationDelegateAdaptor(LogdeckAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class LogdeckAppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?
    private var openedExternalFileURLs = Set<URL>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        showMainWindow(initialFileURLs: commandLineFileURLs)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        openExternalFileURLs(urls)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0).standardizedFileURL }
        openExternalFileURLs(urls)
        sender.reply(toOpenOrPrint: .success)
    }

    private var commandLineFileURLs: [URL] {
        CommandLine.arguments.dropFirst()
            .filter { !$0.hasPrefix("-") }
            .map { URL(fileURLWithPath: $0).standardizedFileURL }
    }

    private func showMainWindow(initialFileURLs: [URL] = []) {
        let initialFileURLs = uniqueExternalFileURLs(initialFileURLs)

        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            if !initialFileURLs.isEmpty {
                LogFileOpenCoordinator.shared.open(initialFileURLs)
            }

            return
        }

        let contentView = ContentView(
            initialFileURLs: initialFileURLs,
            fileOpenCoordinator: .shared
        )
        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Logdeck"
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        positionInitialWindow(window)
        window.makeKeyAndOrderFront(nil)

        mainWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openExternalFileURLs(_ urls: [URL]) {
        let urls = uniqueExternalFileURLs(urls)

        showMainWindow()

        guard !urls.isEmpty else {
            return
        }

        LogFileOpenCoordinator.shared.open(urls)
    }

    private func uniqueExternalFileURLs(_ urls: [URL]) -> [URL] {
        var uniqueURLs: [URL] = []

        for url in urls.map(\.standardizedFileURL) where openedExternalFileURLs.insert(url).inserted {
            uniqueURLs.append(url)
        }

        return uniqueURLs
    }

    private func positionInitialWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            window.center()
            return
        }

        let preferredSize = NSSize(width: 1280, height: 760)
        let visibleFrame = screen.visibleFrame
        let fullScreenFrame = screen.frame.insetBy(dx: 32, dy: 32)
        let placementFrame = visibleFrame.width >= preferredSize.width
            && visibleFrame.height >= preferredSize.height
            ? visibleFrame
            : fullScreenFrame
        let windowSize = NSSize(
            width: min(preferredSize.width, placementFrame.width),
            height: min(preferredSize.height, placementFrame.height)
        )
        let origin = NSPoint(
            x: placementFrame.midX - (windowSize.width / 2),
            y: placementFrame.midY - (windowSize.height / 2)
        )

        window.setFrame(NSRect(origin: origin, size: windowSize), display: false)
    }
}
