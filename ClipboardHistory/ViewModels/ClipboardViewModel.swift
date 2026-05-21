import Foundation
import SwiftUI
import AppKit

@MainActor
final class ClipboardViewModel: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var searchText: String = ""
    @Published var filterTab: FilterTab = .all

    enum FilterTab: String, CaseIterable {
        case all, text, image, video, file

        var localeKey: String {
            switch self {
            case .all: return "filter.all"
            case .text: return "filter.text"
            case .image: return "filter.image"
            case .video: return "filter.video"
            case .file: return "filter.file"
            }
        }
    }

    private let storage = StorageManager()
    private var monitor: ClipboardMonitor?

    var filteredItems: [ClipboardItem] {
        let reversed = Array(items.reversed())
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let byType: [ClipboardItem] = {
            switch filterTab {
            case .all:
                return reversed
            case .text:
                return reversed.filter { $0.type == .text }
            case .image:
                return reversed.filter {
                    $0.type == .image || ($0.type == .file && isImageFile($0.fileURL))
                }
            case .video:
                return reversed.filter {
                    $0.type == .file && isVideoFile($0.fileURL)
                }
            case .file:
                return reversed.filter {
                    $0.type == .file && !isImageFile($0.fileURL) && !isVideoFile($0.fileURL)
                }
            }
        }()

        guard !query.isEmpty else { return byType }

        return byType.filter { item in
            let searchable: String = {
                switch item.type {
                case .text:
                    return item.textContent ?? ""
                case .image:
                    return "图片"
                case .file:
                    return item.fileURL?.lastPathComponent ?? ""
                }
            }()
            return searchable.lowercased().contains(query)
        }
    }

    private func isImageFile(_ url: URL?) -> Bool {
        guard let ext = url?.pathExtension.lowercased() else { return false }
        return ["jpg", "jpeg", "png", "gif", "bmp", "webp", "heic", "tiff", "tif", "ico"].contains(ext)
    }

    private func isVideoFile(_ url: URL?) -> Bool {
        guard let ext = url?.pathExtension.lowercased() else { return false }
        return ["mp4", "mov", "avi", "mkv", "webm", "m4v"].contains(ext)
    }

    func startMonitoring() {
        items = storage.loadItems()

        monitor = ClipboardMonitor { [weak self] item, imageData in
            self?.handleNewItem(item, imageData: imageData)
        }
        monitor?.start()
    }

    func stopMonitoring() {
        monitor?.stop()
    }

    private func handleNewItem(_ item: ClipboardItem, imageData: Data?) {
        // Remove old duplicate so timestamp updates
        if let dup = items.first(where: { isSameContent($0, item) }) {
            if dup.type == .image, let fn = dup.imageFileName {
                storage.deleteImage(fileName: fn)
            }
            items.removeAll { $0.id == dup.id }
            storage.saveItems(items)
        }

        if item.type == .image, let data = imageData, let fileName = item.imageFileName {
            storage.saveImage(data, fileName: fileName)
        }
        storage.addItem(item)
        items = storage.loadItems()
    }

    private func isSameContent(_ a: ClipboardItem, _ b: ClipboardItem) -> Bool {
        guard a.type == b.type else { return false }
        switch a.type {
        case .text:
            return a.textContent == b.textContent
        case .image:
            return a.imageFileName == b.imageFileName
        case .file:
            return a.fileURL == b.fileURL
        }
    }

    private func isDuplicate(_ item: ClipboardItem) -> Bool {
        items.first { isSameContent($0, item) } != nil
    }

    func copyToClipboard(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()

        switch item.type {
        case .text:
            NSPasteboard.general.setString(
                item.textContent ?? "", forType: .string
            )

        case .image:
            guard let fileName = item.imageFileName,
                  let url = storage.imageURL(for: fileName),
                  let image = NSImage(contentsOf: url),
                  let tiffData = image.tiffRepresentation
            else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.setData(tiffData, forType: .tiff)
            if let pngRep = NSBitmapImageRep(data: tiffData),
               let pngData = pngRep.representation(using: .png, properties: [:]) {
                pasteboard.setData(pngData, forType: .png)
            }

        case .file:
            guard let url = item.fileURL,
                  FileManager.default.fileExists(atPath: url.path)
            else { return }
            NSPasteboard.general.writeObjects([url as NSURL])
        }

        // Skip the monitor's next poll — we just wrote to pasteboard ourselves
        monitor?.skipNextChange()

        // Remove old entry, re-add with fresh timestamp
        items.removeAll { $0.id == item.id }
        let refreshed = ClipboardItem(
            id: item.id, type: item.type,
            textContent: item.textContent,
            imageFileName: item.imageFileName,
            fileURL: item.fileURL,
            timestamp: Date()
        )
        storage.saveItems(items)
        storage.addItem(refreshed)
        items = storage.loadItems()
    }

    func clearAll() {
        storage.clearAll()
        items = []
    }
}
