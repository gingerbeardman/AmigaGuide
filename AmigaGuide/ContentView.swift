import AppKit
import SwiftUI
import WebKit

enum AppInfo {
    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "AmigaGuide"
    }
}

enum AmigaGuideLinks {
    /// System Settings Extensions pane — closest public URL to the Quick Look list.
    static let quickLookSettings = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!
    static let guideML = URL(string: "https://www.unsatisfactorysoftware.co.uk/index.php?pg=guideml")!
    /// Vendored, patched GuideML lives in this project.
    static let guideMLSource = URL(string: "https://github.com/gingerbeardman/AmigaGuide")!
}

struct WelcomeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppInfo.name)
                        .font(.title2.weight(.semibold))
                    Text("Preview AmigaGuide documents in Finder.")
                        .foregroundStyle(.secondary)
                }
            }

            Text("Select a .guide file and press Space. If no preview appears, enable the Quick Look extension.")
                .fixedSize(horizontal: false, vertical: true)

            Link("Open System Settings…", destination: AmigaGuideLinks.quickLookSettings)

            Text("Turn on \(AppInfo.name) under Quick Look.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                Text("Converted with ")
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
        .frame(width: 440, alignment: .leading)
    }
}

struct GuideViewer: View {
    let html: String

    var body: some View {
        GuideWebView(html: html)
            .frame(minWidth: 480, minHeight: 320)
    }
}

private struct GuideWebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}

#Preview("Welcome") {
    WelcomeView()
}

#Preview("Guide") {
    GuideViewer(html: "<html><body><tt>AmigaGuide</tt></body></html>")
}
