import Foundation

enum GuideMLConverter: Sendable {
    enum ConversionError: LocalizedError {
        case notAFile
        case conversionFailed(String)
        case missingHTML

        var errorDescription: String? {
            switch self {
            case .notAFile:
                return "The selected item is not a file."
            case .conversionFailed(let message):
                return message.isEmpty ? "GuideML could not convert this AmigaGuide." : message
            case .missingHTML:
                return "GuideML did not produce an HTML file."
            }
        }
    }

    /// True when the file starts with AmigaGuide's `@database` command.
    nonisolated static func looksLikeAmigaGuide(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let prefix = handle.readData(ofLength: 512)
        guard var text = String(data: prefix, encoding: .isoLatin1) else { return false }
        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        return firstLine.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("@database")
    }

    /// Converts an AmigaGuide file to a single HTML document using GuideML.
    nonisolated static func html(fromGuideAt url: URL) throws -> Data {
        let resolved = url.resolvingSymlinksInPath()
        guard resolved.isFileURL else { throw ConversionError.notAFile }

        let accessing = resolved.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                resolved.stopAccessingSecurityScopedResource()
            }
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            throw ConversionError.notAFile
        }

        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GuideML-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory) }

        var errorMessage = [CChar](repeating: 0, count: 1024)
        let ran = GuideMLConvertToDirectory(resolved.path, outputDirectory.path, &errorMessage, errorMessage.count)
        let message = String(cString: errorMessage)
        guard ran else { throw ConversionError.conversionFailed(message) }

        let htmlURL = try findHTML(in: outputDirectory) ?? {
            throw ConversionError.missingHTML
        }()
        let data = try Data(contentsOf: htmlURL)
        guard !data.isEmpty else { throw ConversionError.missingHTML }
        return data
    }

    nonisolated static func htmlString(fromGuideAt url: URL) throws -> String {
        let data = try html(fromGuideAt: url)
        let raw = String(data: data, encoding: .isoLatin1)
            ?? String(decoding: data, as: UTF8.self)
        return GuideHTML.paginatedDocument(from: raw)
    }

    /// Default name for a saved HTML copy of `guideURL`.
    nonisolated static func suggestedHTMLFilename(for guideURL: URL) -> String {
        guideURL.deletingPathExtension().lastPathComponent + ".html"
    }

    /// Default name for a saved EPUB copy of `guideURL`.
    nonisolated static func suggestedEPUBFilename(for guideURL: URL) -> String {
        guideURL.deletingPathExtension().lastPathComponent + ".epub"
    }

    /// Writes a node-per-file EPUB to `url`.
    nonisolated static func writeEPUB(_ html: String, title: String, author: String? = nil, to url: URL) throws {
        try GuideEPUB.write(html: html, title: title, author: author, to: url)
    }

    /// Rewrites GuideML's charset-less meta so the file is valid UTF-8 HTML.
    nonisolated static func utf8HTML(from html: String) -> String {
        html.replacingOccurrences(
            of: "<meta http-equiv=\"Content-Type\" content=\"text/html\">",
            with: "<meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
            options: .caseInsensitive
        )
    }

    /// Writes UTF-8 HTML to `url`.
    nonisolated static func writeUTF8HTML(_ html: String, to url: URL) throws {
        try utf8HTML(from: html).write(to: url, atomically: true, encoding: .utf8)
    }

    /// Writes UTF-8 HTML to a temp file.
    nonisolated static func htmlFile(fromGuideAt url: URL) throws -> URL {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("GuideML-\(UUID().uuidString).html")
        try writeUTF8HTML(try htmlString(fromGuideAt: url), to: dest)
        return dest
    }

    private nonisolated static func findHTML(in directory: URL) throws -> URL? {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        return contents.first { url in
            let ext = url.pathExtension.lowercased()
            return ext == "html" || ext == "htm"
        }
    }
}
