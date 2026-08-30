import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class GuideSession: ObservableObject {
    static let shared = GuideSession()
    @Published private(set) var canSave = false
    @Published private(set) var recentURLs: [URL] = []

    func refresh() {
        canSave = GuideWindowController.canSaveHTML
    }

    func noteRecent(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        refreshRecents()
    }

    func clearRecents() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        refreshRecents()
    }

    func refreshRecents() {
        recentURLs = NSDocumentController.shared.recentDocumentURLs
    }
}

@main
struct AmigaGuideApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var session = GuideSession.shared

    var body: some Scene {
        Window(AppInfo.name, id: "main") {
            WelcomeView()
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About \(AppInfo.name)") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: AppInfo.name
                    ])
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    AppDelegate.openGuides()
                }
                .keyboardShortcut("o")
                Menu("Open Recent") {
                    ForEach(session.recentURLs, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            GuideWindowController.open(url)
                        }
                    }
                    if !session.recentURLs.isEmpty {
                        Divider()
                    }
                    Button("Clear Menu") {
                        session.clearRecents()
                    }
                    .disabled(session.recentURLs.isEmpty)
                }
                Button("Save…") {
                    GuideWindowController.saveFrontmost()
                }
                .keyboardShortcut("s")
                .disabled(!session.canSave)
            }
            CommandGroup(replacing: .help) {
                Link("\(AppInfo.name) on GitHub", destination: AmigaGuideLinks.github)
                Button("Check for Updates…") {
                    UpdateState.shared.checkForUpdates(userInitiated: true)
                }
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set when Finder (or Open With) launches us onto a document, so the
    /// SwiftUI welcome window is ordered out instead of appearing beside it.
    private var suppressWelcome = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        if suppressWelcome {
            hideWelcomeWindow()
            DispatchQueue.main.async { [weak self] in
                self?.hideWelcomeWindow()
            }
        }
        GuideSession.shared.refreshRecents()
        UpdateState.shared.checkForUpdatesInBackground()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        suppressWelcome = true
        hideWelcomeWindow()
        for url in urls {
            GuideWindowController.open(url)
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag || GuideWindowController.hasOpenDocuments {
            return true
        }
        suppressWelcome = false
        showWelcomeWindow()
        return false
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard suppressWelcome, let window = notification.object as? NSWindow else { return }
        if isWelcomeWindow(window) {
            window.orderOut(nil)
        }
    }

    private func isWelcomeWindow(_ window: NSWindow) -> Bool {
        window.identifier?.rawValue == "main"
            || (window.representedURL == nil
                && window.title == AppInfo.name
                && window.styleMask.contains(.titled))
    }

    private func welcomeWindow() -> NSWindow? {
        NSApp.windows.first { isWelcomeWindow($0) }
    }

    private func hideWelcomeWindow() {
        welcomeWindow()?.orderOut(nil)
    }

    private func showWelcomeWindow() {
        welcomeWindow()?.makeKeyAndOrderFront(nil)
    }

    static func openGuides() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = AmigaGuideDocument.readableContentTypes
        panel.message = "Choose an AmigaGuide document."
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            GuideWindowController.open(url)
        }
    }
}

@MainActor
final class GuideWindowController: NSWindowController, NSWindowDelegate {
    private static var openControllers: [GuideWindowController] = []

    static var hasOpenDocuments: Bool {
        openControllers.contains { $0.window?.isVisible == true }
    }

    static var canSaveHTML: Bool {
        !openControllers.isEmpty
    }

    static func open(_ url: URL) {
        if let existing = openControllers.first(where: { $0.fileURL.standardizedFileURL == url.standardizedFileURL }) {
            existing.showWindow(nil)
            GuideSession.shared.noteRecent(url)
            return
        }

        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            guard GuideMLConverter.looksLikeAmigaGuide(at: url) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let html = try GuideMLConverter.htmlString(fromGuideAt: url)
            let controller = GuideWindowController(html: html, fileURL: url)
            openControllers.append(controller)
            GuideSession.shared.refresh()
            GuideSession.shared.noteRecent(url)
            controller.showWindow(nil)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    static func saveFrontmost() {
        let controller = openControllers.first { $0.window?.isKeyWindow == true }
            ?? openControllers.first { $0.window?.isMainWindow == true }
            ?? openControllers.last
        guard let controller else {
            NSSound.beep()
            return
        }
        controller.saveHTML()
    }

    private let html: String
    private let fileURL: URL

    private init(html: String, fileURL: URL) {
        self.html = html
        self.fileURL = fileURL
        let hosting = NSHostingController(
            rootView: GuideViewer(html: html)
                .frame(minWidth: 480, minHeight: 320)
        )
        hosting.sizingOptions = []
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.identifier = NSUserInterfaceItemIdentifier("guide-document")
        window.title = fileURL.lastPathComponent
        window.representedURL = fileURL
        window.contentMinSize = NSSize(width: 480, height: 320)
        window.isReleasedWhenClosed = false
        let autosave = "AmigaGuide.document"
        if !window.setFrameUsingName(autosave) {
            window.setContentSize(NSSize(width: 760, height: 620))
            window.center()
        }
        window.setFrameAutosaveName(autosave)
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        window?.saveFrame(usingName: "AmigaGuide.document")
        Self.openControllers.removeAll { $0 === self }
        GuideSession.shared.refresh()
    }

    private func saveHTML() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = fileURL.deletingPathExtension().lastPathComponent
        panel.directoryURL = fileURL.deletingLastPathComponent()
        panel.message = "Save the converted HTML."
        panel.prompt = "Save"
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        do {
            let accessing = dest.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    dest.stopAccessingSecurityScopedResource()
                }
            }
            try GuideMLConverter.writeUTF8HTML(html, to: dest)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
