import UniformTypeIdentifiers

extension UTType {
    static let amigaGuide = UTType(exportedAs: "com.gingerbeardman.amigaguide")

    /// Xcode owns `.guide` as this UTI, so Finder never assigns ours. We still
    /// open and preview those files as an Alternate handler, sniffing `@database`.
    static var appleDocumentationGuide: UTType? {
        UTType("com.apple.documentation.guide")
    }
}
