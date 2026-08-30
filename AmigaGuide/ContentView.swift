import AppKit
import SwiftUI
import WebKit

enum AppInfo {
    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Amiga Guide"
    }
}

enum AmigaGuideLinks {
    /// System Settings Extensions pane — closest public URL to the Quick Look list.
    static let quickLookSettings = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!
    static let guideML = URL(string: "https://www.unsatisfactorysoftware.co.uk/index.php?pg=guideml")!
    static let github = URL(string: "https://github.com/gingerbeardman/AmigaGuide")!
    static let githubReleases = URL(string: "https://github.com/gingerbeardman/AmigaGuide/releases/latest")!
    /// Vendored, patched GuideML lives in this project.
    static let guideMLSource = github
}

struct WelcomeView: View {
    @ObservedObject private var updates = UpdateState.shared

    var body: some View {
        VStack(spacing: 0) {
            if updates.availableUpdate != nil {
                UpdateBanner()
            }
            welcomeBody
        }
        .frame(width: 440, alignment: .leading)
    }

    private var welcomeBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppInfo.name)
                        .font(.title2.weight(.semibold))
                    Text("Open and preview AmigaGuide documents.")
                        .foregroundStyle(.secondary)
                }
            }

            Text("Open a .guide file, or select one in Finder and press Space. If no preview appears, enable the Quick Look extension.")
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button("Open…") {
                    AppDelegate.openGuides()
                }
                Link("Open System Settings…", destination: AmigaGuideLinks.quickLookSettings)
            }

            Text("Turn on \(AppInfo.name) under Quick Look.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                Text("Powered by ")
                    .foregroundStyle(.secondary)
                Link("GuideML", destination: AmigaGuideLinks.guideML)
                Text(" · ")
                    .foregroundStyle(.secondary)
                Link("source", destination: AmigaGuideLinks.guideMLSource)
            }
            .font(.callout)
            .padding(.top, 6)
        }
        .padding(20)
    }
}

struct GuideViewer: View {
    let html: String
    @ObservedObject private var updates = UpdateState.shared

    var body: some View {
        VStack(spacing: 0) {
            if updates.availableUpdate != nil {
                UpdateBanner()
            }
            GuideWebView(html: html)
        }
        .frame(minWidth: 480, minHeight: 320)
    }
}

struct UpdateBanner: View {
    @ObservedObject private var updates = UpdateState.shared

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.tint)
                .imageScale(.medium)
            if let update = updates.availableUpdate {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(AppInfo.name) \(update.version) is available")
                        .font(.callout.weight(.semibold))
                    Text("You have \(UpdateChecker.currentVersion)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 8)
            Button("View Release") {
                updates.openAvailableUpdate()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Button("Dismiss") {
                updates.dismissAvailableUpdate()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle().fill(Color(nsColor: .controlBackgroundColor))
            Rectangle().fill(Color.accentColor.opacity(0.10))
        }
        .overlay(alignment: .bottom) { Divider() }
    }
}

private struct GuideWebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.lastHTML = html
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard html != context.coordinator.lastHTML else { return }
        context.coordinator.lastHTML = html
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastHTML: String?
    }
}

#Preview("Welcome") {
    WelcomeView()
}

#Preview("Guide") {
    GuideViewer(html: "<html><body><tt>AmigaGuide</tt></body></html>")
}
