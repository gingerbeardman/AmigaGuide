import AppKit
import Combine
import SwiftUI

/// Shared GitHub Releases check — Help menu, quiet launch, and the update banner.
@MainActor
final class UpdateState: ObservableObject {
    static let shared = UpdateState()

    /// Non-nil when a newer GitHub release is available (banner until dismissed).
    @Published var availableUpdate: UpdateChecker.AvailableUpdate?

    /// Manual Help → Check for Updates… (always reports result).
    func checkForUpdates(userInitiated: Bool = true) {
        Task {
            await performUpdateCheck(userInitiated: userInitiated)
        }
    }

    /// Launch-time check (quiet unless a newer release exists).
    func checkForUpdatesInBackground() {
        Task {
            // Don’t block first paint; wait until the window is up.
            try? await Task.sleep(for: .seconds(2))
            await performUpdateCheck(userInitiated: false)
        }
    }

    func dismissAvailableUpdate() {
        availableUpdate = nil
    }

    func openAvailableUpdate() {
        guard let availableUpdate else { return }
        NSWorkspace.shared.open(availableUpdate.htmlURL)
    }

    private func performUpdateCheck(userInitiated: Bool) async {
        #if DEBUG
        if let fake = ProcessInfo.processInfo.environment["AMIGAGUIDE_FAKE_UPDATE"],
           !fake.isEmpty
        {
            availableUpdate = UpdateChecker.AvailableUpdate(
                version: fake,
                htmlURL: AmigaGuideLinks.githubReleases,
                publishedAt: nil
            )
            return
        }
        #endif
        do {
            let result = try await UpdateChecker.check()
            if result.isNewer {
                availableUpdate = result.update
            } else if userInitiated {
                availableUpdate = nil
                presentUserResult(
                    title: "You’re up to date",
                    text: "\(AppInfo.name) \(UpdateChecker.currentVersion) is currently the newest version available.",
                    style: .informational
                )
            }
        } catch {
            if userInitiated {
                presentUserResult(
                    title: "Couldn’t check for updates",
                    text: error.localizedDescription,
                    style: .warning
                )
            }
        }
    }

    private func presentUserResult(title: String, text: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.alertStyle = style
        alert.runModal()
    }
}
