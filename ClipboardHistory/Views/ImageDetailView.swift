import SwiftUI
import AppKit

struct ImageDetailView: View {
    @EnvironmentObject var locale: LocaleManager

    let item: ClipboardItem
    let onBack: () -> Void

    @State private var ocrText: String?
    @State private var isRecognizing = false
    @State private var errorMessage: String?

    private let storage = StorageManager()
    private let ocr = OCRService.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onAppear(perform: startOCR)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                Text(locale.tr("detail.back"))
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                copyImage()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                Text(locale.tr("detail.copyImage"))
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(spacing: 12) {
                imagePreview
                Divider()
                    .padding(.horizontal, 10)
                ocrSection
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: - Image Preview

    private var imagePreview: some View {
        Group {
            if let url = resolvedImageURL,
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 300, maxHeight: 180)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 200, height: 120)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                    )
            }
        }
        .padding(.horizontal, 10)
    }

    // MARK: - OCR Section

    private var ocrSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(locale.tr("detail.ocrTitle"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                if isRecognizing {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 10)

            if isRecognizing {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(locale.tr("detail.ocrRecognizing"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else if let text = ocrText {
                textEditor(for: text)
                copyTextButton
            } else {
                Text(locale.tr("detail.ocrNoText"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
    }

    private func textEditor(for text: String) -> some View {
        TextEditor(text: .constant(text))
            .font(.system(size: 12))
            .frame(minHeight: 120)
            .padding(8)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(6)
            .padding(.horizontal, 10)
    }

    private var copyTextButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(ocrText ?? "", forType: .string)
        } label: {
            Label(locale.tr("detail.copyText"), systemImage: "doc.on.doc")
                .font(.system(size: 12))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .padding(.horizontal, 20)
        .disabled(ocrText == nil || ocrText!.isEmpty)
    }

    // MARK: - Helpers

    private var resolvedImageURL: URL? {
        switch item.type {
        case .image:
            guard let fn = item.imageFileName else { return nil }
            return storage.imageURL(for: fn)
        case .file:
            return item.fileURL
        default:
            return nil
        }
    }

    private func startOCR() {
        guard let url = resolvedImageURL else {
            errorMessage = locale.tr("detail.ocrNoText")
            return
        }
        isRecognizing = true
        ocr.recognizeText(from: url) { text in
            isRecognizing = false
            if let text = text {
                ocrText = text
            } else {
                errorMessage = locale.tr("detail.ocrNoText")
            }
        }
    }

    private func copyImage() {
        guard let url = resolvedImageURL,
              let image = NSImage(contentsOf: url),
              let tiffData = image.tiffRepresentation
        else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(tiffData, forType: .tiff)
        if let pngRep = NSBitmapImageRep(data: tiffData),
           let pngData = pngRep.representation(using: .png, properties: [:]) {
            pasteboard.setData(pngData, forType: .png)
        }
    }
}
