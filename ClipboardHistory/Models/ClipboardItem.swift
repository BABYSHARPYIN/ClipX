import Foundation

enum ItemType: String, Codable {
    case text
    case image
    case file
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ItemType
    var textContent: String?
    var imageFileName: String?
    var fileURL: URL?
    let timestamp: Date
    var sourceAppName: String?
    var sourceAppBundleID: String?

    static func textItem(_ content: String, source: SourceApp? = nil) -> ClipboardItem {
        ClipboardItem(
            id: UUID(), type: .text,
            textContent: content,
            imageFileName: nil, fileURL: nil,
            timestamp: Date(),
            sourceAppName: source?.name, sourceAppBundleID: source?.bundleID
        )
    }

    static func imageItem(fileName: String, source: SourceApp? = nil) -> ClipboardItem {
        ClipboardItem(
            id: UUID(), type: .image,
            textContent: nil,
            imageFileName: fileName, fileURL: nil,
            timestamp: Date(),
            sourceAppName: source?.name, sourceAppBundleID: source?.bundleID
        )
    }

    static func fileItem(url: URL, source: SourceApp? = nil) -> ClipboardItem {
        ClipboardItem(
            id: UUID(), type: .file,
            textContent: nil,
            imageFileName: nil, fileURL: url,
            timestamp: Date(),
            sourceAppName: source?.name, sourceAppBundleID: source?.bundleID
        )
    }
}

struct SourceApp: Codable, Equatable {
    let name: String
    let bundleID: String
}
