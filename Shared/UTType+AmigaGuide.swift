import UniformTypeIdentifiers

extension UTType {
    static let amigaGuide = UTType(exportedAs: "com.gingerbeardman.amigaguide")

    /// Xcode owns `.guide` as `com.apple.documentation.guide`, so Finder often
    /// assigns that UTI. We still open and preview those files as an Alternate
    /// handler, sniffing `@database`. `public.image` is declared so Quick Look
    /// will ask our thumbnail extension for an icon.
    static var appleDocumentationGuide: UTType? {
        UTType("com.apple.documentation.guide")
    }
}
