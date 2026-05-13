import SwiftUI

struct PopoverContentView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    @EnvironmentObject var locale: LocaleManager

    var body: some View {
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
                itemList
            }

            footBar
        }
        .frame(minWidth: 340, idealWidth: 360)
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

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredItems) { item in
                    ClipboardRowView(item: item) {
                        viewModel.copyToClipboard(item)
                        closePopoverAfterCopy()
                    }
                    .environmentObject(viewModel)
                    .environmentObject(locale)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)

                    Divider()
                        .padding(.leading, 50)
                }
            }
        }
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
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func closePopoverAfterCopy() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            (NSApp.delegate as? AppDelegate)?.closePopover()
        }
    }
}
