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
    var isPinned: Bool = false

    private enum CodingKeys: String, CodingKey {
        case id, type, textContent, imageFileName, fileURL, timestamp
        case sourceAppName, sourceAppBundleID, isPinned
    }

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

    func matchesContent(of other: ClipboardItem) -> Bool {
        guard type == other.type else { return false }
        switch type {
        case .text:
            return textContent == other.textContent
        case .image:
            return imageFileName == other.imageFileName
        case .file:
            return fileURL == other.fileURL
        }
    }

    func recencyCopy(at timestamp: Date = Date()) -> ClipboardItem {
        ClipboardItem(
            id: id,
            type: type,
            textContent: textContent,
            imageFileName: imageFileName,
            fileURL: fileURL,
            timestamp: timestamp,
            sourceAppName: sourceAppName,
            sourceAppBundleID: sourceAppBundleID,
            isPinned: isPinned
        )
    }

    static func inheritingPin(from existing: [ClipboardItem], newItem: ClipboardItem) -> ClipboardItem {
        guard let duplicate = existing.first(where: { $0.matchesContent(of: newItem) }) else {
            return newItem
        }
        var merged = newItem
        merged.isPinned = newItem.isPinned || duplicate.isPinned
        return merged
    }

    /// Newest pinned items first, then the remaining history newest first.
    static func displayOrder(_ items: [ClipboardItem]) -> [ClipboardItem] {
        let newestFirst = Array(items.reversed())
        return newestFirst.filter(\.isPinned) + newestFirst.filter { !$0.isPinned }
    }

    /// Drops the oldest unpinned items once `items` is past `maxCount`. Pinned items stay.
    static func applyingRetentionLimit(_ items: [ClipboardItem], maxCount: Int) -> [ClipboardItem] {
        guard items.count > maxCount else { return items }
        let pinnedCount = items.reduce(into: 0) { count, item in
            if item.isPinned { count += 1 }
        }
        let unpinnedBudget = max(0, maxCount - pinnedCount)
        var keptUnpinnedIDs = Set<UUID>()
        var keptUnpinned = 0
        for item in items.reversed() where !item.isPinned {
            guard keptUnpinned < unpinnedBudget else { continue }
            keptUnpinnedIDs.insert(item.id)
            keptUnpinned += 1
        }
        return items.filter { $0.isPinned || keptUnpinnedIDs.contains($0.id) }
    }
}

extension ClipboardItem {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            type: try container.decode(ItemType.self, forKey: .type),
            textContent: try container.decodeIfPresent(String.self, forKey: .textContent),
            imageFileName: try container.decodeIfPresent(String.self, forKey: .imageFileName),
            fileURL: try container.decodeIfPresent(URL.self, forKey: .fileURL),
            timestamp: try container.decode(Date.self, forKey: .timestamp),
            sourceAppName: try container.decodeIfPresent(String.self, forKey: .sourceAppName),
            sourceAppBundleID: try container.decodeIfPresent(String.self, forKey: .sourceAppBundleID),
            isPinned: try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        )
    }
}

struct SourceApp: Codable, Equatable {
    let name: String
    let bundleID: String
}
