import Foundation
#if !PIN_RETENTION_STANDALONE
@testable import ClipboardHistory
#endif

struct PinCheckFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw PinCheckFailure(description: message)
    }
}

func runPinRetentionChecks() throws {
    try checkLegacyJSONDefaultsToUnpinned()
    try checkPinPersistsAcrossReload()
    try checkClearKeepsPinnedItemsAndImageFiles()
    try checkEvictionDropsOldestUnpinnedAndItsImage()
    try checkPinsBeyondLimitAreKeptAndUnpinnedAreNot()
    try checkUnpinReturnsItemToEvictionAndClear()
    try checkAddItemPersistsRetention()
    try checkClearRemovesUnpinnedHistoryEntirely()
    try checkUnpinnedHistoryKeepsNewestItems()
    try checkStoredOrderStaysChronological()
    try checkDisplayOrderLeadsWithNewestPins()
    try checkRecopyInheritsPinWithoutChangingOtherContent()
    try checkReuseKeepsPinAndSource()
}

func checkLegacyJSONDefaultsToUnpinned() throws {
    try withTempStore(maxItemCount: 10) { storage, directory in
        storage.addItem(ClipboardItem.textItem("alpha"))
        let url = directory.appendingPathComponent("items.json")
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        guard var rows = object as? [[String: Any]], !rows.isEmpty else {
            throw PinCheckFailure(description: "stored history is not a list")
        }
        rows[0].removeValue(forKey: "isPinned")
        try JSONSerialization.data(withJSONObject: rows).write(to: url)

        let loaded = StorageManager(baseURL: directory, maxItemCount: 10).loadItems()
        try expect(loaded.count == 1, "legacy history still loads")
        try expect(loaded[0].isPinned == false, "missing pin flag defaults to unpinned")
    }
}

func checkPinPersistsAcrossReload() throws {
    try withTempStore(maxItemCount: 10) { storage, directory in
        var pinned = ClipboardItem.textItem("alpha")
        pinned.isPinned = true
        storage.saveItems([pinned])

        let loaded = StorageManager(baseURL: directory, maxItemCount: 10).loadItems()
        try expect(loaded.count == 1, "pinned item reloads")
        try expect(loaded[0].id == pinned.id, "reloaded item keeps its id")
        try expect(loaded[0].isPinned, "pin survives a new storage session")
    }
}

func checkClearKeepsPinnedItemsAndImageFiles() throws {
    try withTempStore(maxItemCount: 10) { storage, _ in
        var first = ClipboardItem.textItem("alpha")
        first.isPinned = true
        var pinnedImage = ClipboardItem.imageItem(fileName: "keep.png")
        pinnedImage.isPinned = true
        let loose = ClipboardItem.textItem("beta")
        var looseImage = ClipboardItem.imageItem(fileName: "drop.png")
        looseImage.isPinned = false
        storage.saveImage(Data([1]), fileName: "keep.png")
        storage.saveImage(Data([2]), fileName: "drop.png")
        storage.saveItems([first, loose, pinnedImage, looseImage])

        storage.clearAll()
        let loaded = storage.loadItems()
        try expect(loaded.map(\.id) == [first.id, pinnedImage.id], "clear keeps pinned items in place")
        try expect(loaded.allSatisfy(\.isPinned), "items left after clear are pinned")
        try expect(storage.imageURL(for: "keep.png") != nil, "pinned image file stays")
        try expect(storage.imageURL(for: "drop.png") == nil, "unpinned image file is removed")
    }
}

func checkEvictionDropsOldestUnpinnedAndItsImage() throws {
    let limited = ClipboardItem.applyingRetentionLimit(
        [
            named("u-old"),
            pinned("p-old", fileName: nil),
            named("u-mid"),
            pinned("p-new", fileName: nil),
            named("u-new")
        ],
        maxCount: 3
    )
    try expect(
        limited.map(\.textContent) == ["p-old", "p-new", "u-new"],
        "retention keeps every pin and the newest unpinned items"
    )

    try withTempStore(maxItemCount: 2) { storage, _ in
        var pinnedImage = ClipboardItem.imageItem(fileName: "keep.png")
        pinnedImage.isPinned = true
        let dropImage = ClipboardItem.imageItem(fileName: "drop.png")
        let newest = ClipboardItem.textItem("newest")
        storage.saveImage(Data([1]), fileName: "keep.png")
        storage.saveImage(Data([2]), fileName: "drop.png")
        storage.saveItems([dropImage, pinnedImage, newest])

        let loaded = storage.loadItems()
        try expect(loaded.map(\.id) == [pinnedImage.id, newest.id], "save evicts the oldest unpinned item")
        try expect(storage.imageURL(for: "keep.png") != nil, "older pinned image file stays")
        try expect(storage.imageURL(for: "drop.png") == nil, "evicted image file is removed")
    }
}

func checkPinsBeyondLimitAreKeptAndUnpinnedAreNot() throws {
    let pins = [pinned("p1", fileName: nil), pinned("p2", fileName: nil), pinned("p3", fileName: nil)]
    let kept = ClipboardItem.applyingRetentionLimit(pins, maxCount: 2)
    try expect(kept.map(\.id) == pins.map(\.id), "pins are kept even when they exceed the limit")

    var overflow = pins
    overflow.append(named("loose"))
    let trimmed = ClipboardItem.applyingRetentionLimit(overflow, maxCount: 2)
    try expect(trimmed.map(\.id) == pins.map(\.id), "unpinned items are dropped when pins already fill the limit")
}

func checkUnpinReturnsItemToEvictionAndClear() throws {
    try withTempStore(maxItemCount: 2) { storage, _ in
        var oldest = pinned("p-old", fileName: nil)
        let middle = pinned("p-mid", fileName: nil)
        let newest = pinned("p-new", fileName: nil)
        storage.saveItems([oldest, middle, newest])
        try expect(storage.loadItems().count == 3, "pinned items above the limit stay stored")

        oldest.isPinned = false
        storage.saveItems([oldest, middle, newest])
        let afterEviction = storage.loadItems()
        try expect(afterEviction.map(\.id) == [middle.id, newest.id], "an unpinned item can be evicted")

        var survivor = afterEviction[0]
        survivor.isPinned = false
        storage.saveItems([survivor, afterEviction[1]])
        storage.clearAll()
        let left = storage.loadItems()
        try expect(left.map(\.id) == [afterEviction[1].id], "clear removes an item after it is unpinned")
        try expect(left[0].isPinned, "a pin that was not unpinned stays")
    }
}

func checkAddItemPersistsRetention() throws {
    try withTempStore(maxItemCount: 2) { storage, directory in
        var pinnedItem = ClipboardItem.textItem("alpha")
        pinnedItem.isPinned = true
        let oldestLoose = ClipboardItem.textItem("beta")
        let newestLoose = ClipboardItem.textItem("gamma")
        storage.addItem(pinnedItem)
        storage.addItem(oldestLoose)
        storage.addItem(newestLoose)

        let loaded = StorageManager(baseURL: directory, maxItemCount: 2).loadItems()
        try expect(loaded.map(\.id) == [pinnedItem.id, newestLoose.id], "add keeps the pin and the newest unpinned item")
        try expect(loaded.contains(where: { $0.id == oldestLoose.id }) == false, "oldest unpinned item is evicted on add")
        try expect(loaded[0].isPinned, "added pin is still pinned after reload")
    }
}

func checkClearRemovesUnpinnedHistoryEntirely() throws {
    try withTempStore(maxItemCount: 10) { storage, directory in
        let loose = ClipboardItem.textItem("alpha")
        let image = ClipboardItem.imageItem(fileName: "drop.png")
        storage.saveImage(Data([2]), fileName: "drop.png")
        storage.saveItems([loose, image])
        storage.clearAll()
        try expect(storage.loadItems().isEmpty, "clear removes unpinned history")
        try expect(storage.imageURL(for: "drop.png") == nil, "clear removes unpinned image files")
        let url = directory.appendingPathComponent("items.json")
        try expect(!FileManager.default.fileExists(atPath: url.path), "clear deletes the history file when nothing is pinned")
    }
}

func checkUnpinnedHistoryKeepsNewestItems() throws {
    let kept = ClipboardItem.applyingRetentionLimit(
        [named("a"), named("b"), named("c"), named("d")],
        maxCount: 2
    )
    try expect(kept.map(\.textContent) == ["c", "d"], "unpinned history still keeps the newest items")
}

func checkStoredOrderStaysChronological() throws {
    try withTempStore(maxItemCount: 5) { storage, _ in
        let older = ClipboardItem.textItem("alpha")
        var pinnedItem = ClipboardItem.textItem("beta")
        pinnedItem.isPinned = true
        storage.saveItems([older, pinnedItem])
        try expect(storage.loadItems().map(\.id) == [older.id, pinnedItem.id], "saving does not reorder pins ahead of newer history")
    }
}

func checkDisplayOrderLeadsWithNewestPins() throws {
    let stored = [named("u-old"), pinned("p-old", fileName: nil), named("u-new"), pinned("p-new", fileName: nil)]
    let shown = ClipboardItem.displayOrder(stored)
    try expect(
        shown.map(\.textContent) == ["p-new", "p-old", "u-new", "u-old"],
        "display lists newest pins before the rest"
    )
}

func checkRecopyInheritsPinWithoutChangingOtherContent() throws {
    var existing = ClipboardItem.textItem("same")
    existing.isPinned = true
    let incoming = ClipboardItem.textItem("same")
    let merged = ClipboardItem.inheritingPin(from: [existing], newItem: incoming)
    try expect(merged.isPinned, "copying the same content again keeps the pin")
    try expect(merged.id == incoming.id, "the new copy keeps its own id")
    try expect(incoming.isPinned == false, "pin inheritance does not mutate the incoming value")

    let different = ClipboardItem.textItem("other")
    let separate = ClipboardItem.inheritingPin(from: [existing], newItem: different)
    try expect(separate.isPinned == false, "different content does not inherit a pin")

    let unpinned = ClipboardItem.textItem("same")
    let stillLoose = ClipboardItem.inheritingPin(from: [unpinned], newItem: ClipboardItem.textItem("same"))
    try expect(stillLoose.isPinned == false, "an unpinned duplicate stays unpinned")

    var alreadyPinned = ClipboardItem.textItem("same")
    alreadyPinned.isPinned = true
    let kept = ClipboardItem.inheritingPin(from: [unpinned], newItem: alreadyPinned)
    try expect(kept.isPinned, "an incoming pin is not cleared by an older unpinned copy")
}

func checkReuseKeepsPinAndSource() throws {
    let source = SourceApp(name: "Editor", bundleID: "example.editor")
    var item = ClipboardItem.textItem("alpha", source: source)
    item.isPinned = true
    let later = item.timestamp.addingTimeInterval(5)
    let copy = item.recencyCopy(at: later)
    try expect(copy.id == item.id, "reusing an item keeps its id")
    try expect(copy.isPinned, "reusing an item keeps its pin")
    try expect(copy.sourceAppName == source.name, "reusing an item keeps the source app")
    try expect(copy.sourceAppBundleID == source.bundleID, "reusing an item keeps the source id")
    try expect(copy.timestamp == later, "reusing an item refreshes the timestamp")
    try expect(copy.textContent == item.textContent, "reusing an item keeps its text")
}

private func named(_ name: String) -> ClipboardItem {
    ClipboardItem.textItem(name)
}

private func pinned(_ name: String, fileName: String?) -> ClipboardItem {
    if let fileName {
        var item = ClipboardItem.imageItem(fileName: fileName)
        item.textContent = name
        item.isPinned = true
        return item
    }
    var item = ClipboardItem.textItem(name)
    item.isPinned = true
    return item
}

private func withTempStore(
    maxItemCount: Int,
    _ body: (StorageManager, URL) throws -> Void
) throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("clipx-pin-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = StorageManager(baseURL: directory, maxItemCount: maxItemCount)
    try body(storage, directory)
}

#if PIN_RETENTION_STANDALONE
@main
enum PinRetentionCheckMain {
    static func main() {
        do {
            try runPinRetentionChecks()
            print("ok")
        } catch {
            fputs("FAIL: \(error)\n", stderr)
            exit(1)
        }
    }
}
#endif
