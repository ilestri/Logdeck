import LogdeckCore
import AppKit
import SwiftUI

@main
struct LogdeckApp: App {
    @NSApplicationDelegateAdaptor(LogdeckAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(initialFileURLs: initialFileURLs)
        }
        .windowStyle(.titleBar)
    }

    private var initialFileURLs: [URL] {
        CommandLine.arguments.dropFirst()
            .filter { !$0.hasPrefix("-") }
            .map { URL(fileURLWithPath: $0).standardizedFileURL }
    }
}

@MainActor
final class LogdeckAppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        LogFileOpenCoordinator.shared.open(urls)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0).standardizedFileURL }
        LogFileOpenCoordinator.shared.open(urls)
        sender.reply(toOpenOrPrint: .success)
    }
}
