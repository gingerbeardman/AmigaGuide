import AppKit
import SwiftUI

@main
struct AmigaGuideApp: App {
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
        }

        DocumentGroup(viewing: AmigaGuideDocument.self) { file in
            GuideViewer(html: file.document.html)
        }
    }
}
