import SwiftUI

struct PopoverContentView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    @EnvironmentObject var locale: LocaleManager

    @State private var selectedImageItem: ClipboardItem?

    var body: some View {
        Group {
            if let imageItem = selectedImageItem {
                ImageDetailView(item: imageItem) {
                    selectedImageItem = nil
                }
                .environmentObject(locale)
            } else {
                mainContent
            }
        }
        .frame(minWidth: 340, idealWidth: 360)
        .onReceive(NotificationCenter.default.publisher(for: .popoverWillShow)) { _ in
            selectedImageItem = nil
            TTSService.shared.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: .popoverDidClose)) { _ in
            TTSService.shared.stop()
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            titleBar
            SearchBarView(searchText: $viewModel.searchText)
                .environmentObject(locale)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)

            typeFilter
                .padding(.horizontal, 10)
                .padding(.bottom, 8)

            if viewModel.filteredItems.isEmpty {
                emptyView
            } else {
                listSection
            }

            footBar
        }
    }

    private var titleBar: some View {
        HStack {
            Text(locale.tr("app.title"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var typeFilter: some View {
        Picker("", selection: $viewModel.filterTab) {
            ForEach(ClipboardViewModel.FilterTab.allCases, id: \.self) { tab in
                Text(locale.tr(tab.localeKey)).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var pinnedItems: [ClipboardItem] {
        viewModel.filteredItems.filter(\.isPinned)
    }

    private var scrollItems: [ClipboardItem] {
        viewModel.filteredItems.filter { !$0.isPinned }
    }

    private var listSection: some View {
        VStack(spacing: 0) {
            if viewModel.showsPinLimitNotice {
                Text(locale.tr("pin.limit"))
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }
            itemList
        }
        .animation(.easeInOut(duration: 0.15), value: viewModel.showsPinLimitNotice)
    }

    private var itemList: some View {
        VStack(spacing: 0) {
            if !pinnedItems.isEmpty {
                pinnedLayer
            }
            ScrollView {
                if scrollItems.isEmpty {
                    Color.clear.frame(height: 1)
                } else {
                    LazyVStack(spacing: 0) {
                        historyRows(scrollItems, showsTrailingDivider: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Pinned rows stay fixed above the scrolling history and share its surface.
    /// A separate opaque fill reads as a white card on the translucent popover.
    private var pinnedLayer: some View {
        VStack(spacing: 0) {
            historyRows(pinnedItems, showsTrailingDivider: false)
            Divider()
            LinearGradient(
                colors: [Color.primary.opacity(0.10), Color.primary.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 8)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func historyRows(_ items: [ClipboardItem], showsTrailingDivider: Bool) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            row(for: item)
            if showsTrailingDivider || index < items.count - 1 {
                Divider()
                    .padding(.leading, 50)
            }
        }
    }

    private func row(for item: ClipboardItem) -> some View {
        ClipboardRowView(item: item) {
            if item.type == .image || isImageFileItem(item) {
                selectedImageItem = item
            } else {
                viewModel.copyToClipboard(item)
            }
        }
        .environmentObject(viewModel)
        .environmentObject(locale)
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
    }

    private func isImageFileItem(_ item: ClipboardItem) -> Bool {
        guard item.type == .file, let ext = item.fileURL?.pathExtension.lowercased() else { return false }
        return ["jpg", "jpeg", "png", "gif", "bmp", "webp", "heic", "tiff", "tif", "ico"].contains(ext)
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text(viewModel.searchText.isEmpty
                ? locale.tr("search.empty")
                : locale.tr("search.noMatch"))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    private var footBar: some View {
        HStack {
            Text("\(viewModel.filteredItems.count)/\(viewModel.items.count)\(locale.tr("footer.items"))")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Spacer()

            Button {
                viewModel.clearAll()
            } label: {
                Text(locale.tr("footer.clearAll"))
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help(locale.tr("footer.clearAll.help"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

}
