import Foundation
import AppKit

class StorageManager {
    static let maxItems = 200
    let baseURL: URL

    private var itemsURL: URL {
        baseURL.appendingPathComponent("items.json")
    }

    private var imagesURL: URL {
        baseURL.appendingPathComponent("Images")
    }

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!

        baseURL = appSupport.appendingPathComponent("ClipboardHistory")

        try? FileManager.default.createDirectory(
            at: baseURL, withIntermediateDirectories: true
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
        return items
    }

    func saveItems(_ items: [ClipboardItem]) {
        let trimmed = Array(items.suffix(StorageManager.maxItems))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        try? data.write(to: itemsURL, options: .atomic)
    }

    func addItem(_ item: ClipboardItem) {
        var items = loadItems()
        items.append(item)

        if items.count > StorageManager.maxItems {
            let removed = items.prefix(items.count - StorageManager.maxItems)
            for r in removed where r.type == .image {
                deleteImage(fileName: r.imageFileName ?? "")
            }
        }

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

    func clearAll() {
        let items = loadItems()
        for item in items where item.type == .image {
            deleteImage(fileName: item.imageFileName ?? "")
        }
        try? FileManager.default.removeItem(at: itemsURL)
    }
}
