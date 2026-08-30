import SwiftUI
import UniformTypeIdentifiers

struct AmigaGuideDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.amigaGuide] + [UTType.appleDocumentationGuide].compactMap { $0 }
    }
    static var writableContentTypes: [UTType] { [] }

    let html: String

    init(html: String) {
        self.html = html
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).guide")
        try data.write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }
        html = try GuideMLConverter.htmlString(fromGuideAt: temp)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.fileWriteUnknown)
    }
}
