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

    static func textItem(_ content: String) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            type: .text,
            textContent: content,
            imageFileName: nil,
            fileURL: nil,
            timestamp: Date()
        )
    }

    static func imageItem(fileName: String) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            type: .image,
            textContent: nil,
            imageFileName: fileName,
            fileURL: nil,
            timestamp: Date()
        )
    }

    static func fileItem(url: URL) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            type: .file,
            textContent: nil,
            imageFileName: nil,
            fileURL: url,
            timestamp: Date()
        )
    }
}
