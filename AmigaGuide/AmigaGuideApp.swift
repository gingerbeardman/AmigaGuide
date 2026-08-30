import SwiftUI

@main
struct AmigaGuideApp: App {
    var body: some Scene {
        Window("AmigaGuide", id: "main") {
            WelcomeView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.presented)

        DocumentGroup(viewing: AmigaGuideDocument.self) { file in
            GuideViewer(html: file.document.html)
        }
        .defaultLaunchBehavior(.suppressed)
    }
}
