import Foundation

class StorageManager {
    static let maxItems = 200
    let baseURL: URL
    let maxItemCount: Int

    private var itemsURL: URL {
        baseURL.appendingPathComponent("items.json")
    }

    private var imagesURL: URL {
        baseURL.appendingPathComponent("Images")
    }

    init(baseURL: URL? = nil, maxItemCount: Int = StorageManager.maxItems) {
        if let baseURL {
            self.baseURL = baseURL
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first!

            self.baseURL = appSupport.appendingPathComponent("ClipboardHistory")
        }
        self.maxItemCount = maxItemCount

        try? FileManager.default.createDirectory(
            at: self.baseURL, withIntermediateDirectories: true
        )
        try? FileManager.default.createDirectory(
            at: imagesURL, withIntermediateDirectories: true
        )
    }

    func loadItems() -> [ClipboardItem] {
        guard let data = try? Data(contentsOf: itemsURL),
              let items = try? JSONDecoder().decode(
                [ClipboardItem].self, from: data)
        else {
            return []
        }
        let capped = ClipboardItem.applyingPinLimit(items)
        if capped != items, let encoded = try? JSONEncoder().encode(capped) {
            try? encoded.write(to: itemsURL, options: .atomic)
        }
        return capped
    }

    func saveItems(_ items: [ClipboardItem]) {
        let capped = ClipboardItem.applyingPinLimit(items)
        let trimmed = ClipboardItem.applyingRetentionLimit(capped, maxCount: maxItemCount)
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        do {
            try data.write(to: itemsURL, options: .atomic)
        } catch {
            return
        }

        let keptIDs = Set(trimmed.map(\.id))
        for item in items where item.type == .image && !keptIDs.contains(item.id) {
            deleteImage(fileName: item.imageFileName ?? "")
        }
    }

    func addItem(_ item: ClipboardItem) {
        var items = loadItems()
        items.append(item)
        saveItems(items)
    }

    func saveImage(_ data: Data, fileName: String) {
        let url = imagesURL.appendingPathComponent(fileName)
        try? data.write(to: url)
    }

    func deleteImage(fileName: String) {
        guard !fileName.isEmpty else { return }
        let url = imagesURL.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    func imageURL(for fileName: String) -> URL? {
        guard !fileName.isEmpty else { return nil }
        let url = imagesURL.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Removes unpinned history. Pinned items and their image files stay.
    func clearAll() {
        let items = loadItems()
        for item in items where !item.isPinned && item.type == .image {
            deleteImage(fileName: item.imageFileName ?? "")
        }

        let kept = items.filter(\.isPinned)
        if kept.isEmpty {
            try? FileManager.default.removeItem(at: itemsURL)
            return
        }
        guard let data = try? JSONEncoder().encode(kept) else { return }
        try? data.write(to: itemsURL, options: .atomic)
    }
}
