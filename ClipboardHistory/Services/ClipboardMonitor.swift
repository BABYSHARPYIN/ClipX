import Foundation
import AppKit

final class ClipboardMonitor {
    private let onNewItem: (ClipboardItem, Data?) -> Void
    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastTextContent: String?

    init(onNewItem: @escaping (ClipboardItem, Data?) -> Void) {
        self.onNewItem = onNewItem
    }

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(
            withTimeInterval: 0.5, repeats: true
        ) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func skipNextChange() {
        lastChangeCount = NSPasteboard.general.changeCount
        lastTextContent = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    deinit {
        stop()
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // 1. File URLs first — Finder copy of any file (image, video, doc, etc.)
        if let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self], options: [
                .urlReadingFileURLsOnly: true
            ]
        ) as? [URL], let url = fileURLs.first {
            lastTextContent = nil
            onNewItem(ClipboardItem.fileItem(url: url), nil)
            return
        }

        // 2. Image — screenshot or browser copy (no file URL, just image data)
        if let tiffData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: tiffData),
           let pngData = pngData(from: image)
        {
            lastTextContent = nil
            let fileName = UUID().uuidString + ".png"
            onNewItem(ClipboardItem.imageItem(fileName: fileName), pngData)
            return
        }

        // 3. Text last — only when no file URL and no image data
        if let text = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty,
           text != lastTextContent
        {
            lastTextContent = text
            onNewItem(ClipboardItem.textItem(text), nil)
            return
        }

        if pasteboard.string(forType: .string) == nil {
            lastTextContent = nil
        }
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData)
        else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
