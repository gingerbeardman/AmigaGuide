import UniformTypeIdentifiers

enum AmigaGuideDocument {
    static var readableContentTypes: [UTType] {
        [.amigaGuide] + [UTType.appleDocumentationGuide].compactMap { $0 }
    }
}
