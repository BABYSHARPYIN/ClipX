import SwiftUI
import AppKit

struct ClipboardRowView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    @EnvironmentObject var locale: LocaleManager

    let item: ClipboardItem
    let onCopy: () -> Void

    @State private var justCopied = false
    @State private var fileIcon: NSImage?

    var body: some View {
        Button {
            onCopy()
            justCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                justCopied = false
            }
        } label: {
            HStack(spacing: 10) {
                typeIcon

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        itemTitle
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)

                        typeBadge
                    }

                    Text(relativeTime(from: item.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if justCopied {
                    Text(locale.tr("row.copied"))
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(itemFullText)
        .onAppear {
            if item.type == .file, let url = item.fileURL {
                fileIcon = NSWorkspace.shared.icon(forFile: url.path)
            }
        }
    }

    private var typeIcon: some View {
        Group {
            switch item.type {
            case .text:
                Image(systemName: "text.alignleft")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 40, height: 40)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)

            case .image:
                ImageThumbnailView(fileName: item.imageFileName)

            case .file:
                if let icon = fileIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "doc")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
    }

    private var itemFullText: String {
        item.textContent ?? item.fileURL?.lastPathComponent ?? ""
    }

    private var itemTitle: Text {
        switch item.type {
        case .text:
            Text(item.textContent ?? "")
        case .image:
            Text(locale.tr("type.image"))
        case .file:
            Text(item.fileURL?.lastPathComponent ?? "")
        }
    }

    private var typeBadge: some View {
        Text(typeLabel)
            .font(.system(size: 9))
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(3)
    }

    private var typeLabel: String {
        switch item.type {
        case .text:
            return locale.tr("type.text")
        case .image:
            return locale.tr("type.image")
        case .file:
            let ext = item.fileURL?.pathExtension.uppercased() ?? ""
            return ext.isEmpty ? "" : ext
        }
    }

    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        switch interval {
        case ..<60:
            return locale.tr("row.justNow")
        case ..<3600:
            return "\(Int(interval / 60))\(locale.tr("row.minAgo"))"
        case ..<86400:
            return "\(Int(interval / 3600))\(locale.tr("row.hrAgo"))"
        case ..<604800:
            return "\(Int(interval / 86400))\(locale.tr("row.dayAgo"))"
        default:
            let fmt = DateFormatter()
            fmt.dateFormat = "MM/dd"
            return fmt.string(from: date)
        }
    }
}

private struct ImageThumbnailView: View {
    let fileName: String?

    var body: some View {
        if let fileName,
           let url = imageFileURL(for: fileName),
           let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .cornerRadius(4)
                .clipped()
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "photo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                )
        }
    }

    private func imageFileURL(for fileName: String) -> URL? {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let url = appSupport
            .appendingPathComponent("ClipboardHistory")
            .appendingPathComponent("Images")
            .appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
