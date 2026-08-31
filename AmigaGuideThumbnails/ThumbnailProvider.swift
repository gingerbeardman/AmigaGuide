import AppKit
import QuickLookThumbnailing

final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        let fileURL = request.fileURL
        guard GuideMLConverter.looksLikeAmigaGuide(at: fileURL) else {
            handler(nil, CocoaError(.fileReadCorruptFile))
            return
        }
        let side = min(request.maximumSize.width, request.maximumSize.height, 512)
        let size = CGSize(width: max(16, side), height: max(16, side))
        let preview = GuideThumbnail.preview(fromGuideAt: fileURL)
        handler(QLThumbnailReply(contextSize: size, currentContextDrawing: {
            GuideThumbnail.draw(preview, in: size)
            return true
        }), nil)
    }
}
