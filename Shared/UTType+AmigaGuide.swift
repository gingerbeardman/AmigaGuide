import UniformTypeIdentifiers

extension UTType {
    static let amigaGuide = UTType(exportedAs: "com.gingerbeardman.amigaguide")

    /// Xcode owns the `.guide` extension as this UTI, so Finder never assigns ours.
    static var appleDocumentationGuide: UTType? {
        UTType("com.apple.documentation.guide")
    }
}
