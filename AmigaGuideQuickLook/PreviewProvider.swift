import Cocoa
import Quartz
import UniformTypeIdentifiers

class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        if GuideMLConverter.looksLikeAmigaGuide(at: request.fileURL) {
            let html = try GuideMLConverter.htmlString(fromGuideAt: request.fileURL)
            return QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 760, height: 620)) { reply in
                reply.stringEncoding = .utf8
                return Data(html.utf8)
            }
        }

        // Xcode also uses `.guide` for markdown educational guides.
        let data = try Data(contentsOf: request.fileURL)
        return QLPreviewReply(dataOfContentType: .plainText, contentSize: CGSize(width: 760, height: 620)) { reply in
            reply.stringEncoding = .utf8
            return data
        }
    }
}
