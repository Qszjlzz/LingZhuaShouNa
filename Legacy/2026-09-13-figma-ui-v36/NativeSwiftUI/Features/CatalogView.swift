import SwiftUI

struct CatalogView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var searchText = ""
    @State private var newItemName = ""
    @State private var newItemCategory: ItemCategory = .stationery
    @State private var selectedCategory: ItemCategory?
    @State private var selectedItem: DetectedItem?
    @State private var editingItem: DetectedItem?
    @State private var itemPendingDeletion: DetectedItem?
    @State private var isShowingAddItem = false
    @State private var isEditingCatalog = false

    private var filteredItems: [DetectedItem] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return viewModel.catalogItems }
        return viewModel.catalogItems.filter {
            $0.name.localizedCaseInsensitiveContains(keyword)
            || $0.category.rawValue.localizedCaseInsensitiveContains(keyword)
            || $0.suggestedZone.localizedCaseInsensitiveContains(keyword)
        }
    }

    var body: some View {
        ZStack {
            SmartPawStyle.canvas.ignoresSafeArea()
            ScrollView {
                FigmaCatalogHome(
                    searchText: $searchText,
                    isEditing: $isEditingCatalog,
                    items: filteredItems,
                    onSelectCategory: { selectedCategory = $0 },
                    onOpenItem: { selectedItem = $0 },
                    onEditItem: { editingItem = $0 },
                    onDeleteItem: { itemPendingDeletion = $0 },
                    onAddItem: { isShowingAddItem = true }
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 112)
            }
        }
        .sheet(isPresented: $isShowingAddItem) {
            CatalogAddItemSheet(
                name: $newItemName,
                category: $newItemCategory,
                onSave: {
                    viewModel.addManualItem(name: newItemName, category: newItemCategory)
                    newItemName = ""
                    isShowingAddItem = false
                }
            )
        }
        .sheet(item: $selectedCategory) { category in
            CategoryDetailSheet(category: category)
        }
        .sheet(item: $selectedItem) { item in
            CatalogItemDetailSheet(item: item)
        }
        .sheet(item: $editingItem) { item in
            CatalogItemEditor(item: item)
        }
        .confirmationDialog(
            "Delete this item?",
            isPresented: Binding(
                get: { itemPendingDeletion != nil },
                set: { if !$0 { itemPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let itemPendingDeletion else { return }
                viewModel.removeCatalogItem(itemPendingDeletion.id)
                self.itemPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { itemPendingDeletion = nil }
        } message: {
            Text("This item will be removed from its space and the catalog.")
        }
    }
}

private struct FigmaCatalogHome: View {
    @Binding var searchText: String
    @Binding var isEditing: Bool
    let items: [DetectedItem]
    let onSelectCategory: (ItemCategory) -> Void
    let onOpenItem: (DetectedItem) -> Void
    let onEditItem: (DetectedItem) -> Void
    let onDeleteItem: (DetectedItem) -> Void
    let onAddItem: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Catalog")
                        .font(FigmaFont.semibold(25))
                        .foregroundStyle(SmartPawStyle.brown)
                    Text("Put every item back where it belongs")
                        .font(FigmaFont.regular(13))
                        .foregroundStyle(SmartPawStyle.brown.opacity(0.58))
                }
                Spacer()
                Button {
                    isEditing.toggle()
                } label: {
                    Text(isEditing ? "Done" : "Edit")
                        .font(FigmaFont.medium(14))
                        .foregroundStyle(SmartPawStyle.orange)
                }
                .accessibilityLabel(isEditing ? "Finish catalog editing" : "Edit catalog items")
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.48))
                TextField("Search items or categories", text: $searchText)
                    .font(FigmaFont.regular(15))
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(SmartPawStyle.brown.opacity(0.34))
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(SmartPawStyle.hairline, lineWidth: 1)
            }

            Button(action: onAddItem) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(FigmaFont.semibold(20))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.18), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("AI recognition")
                            .font(FigmaFont.semibold(16))
                        Text("Take a photo to automatically classify your items")
                            .font(FigmaFont.regular(12))
                            .opacity(0.82)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(FigmaFont.semibold(12))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(minHeight: 72)
                .background(SmartPawStyle.orange, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Capture and add an item")

            HStack {
                Text("Item categories")
                    .font(FigmaFont.semibold(18))
                    .foregroundStyle(SmartPawStyle.brown)
                Spacer()
                Text("\(items.count) items")
                    .font(FigmaFont.regular(13))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.52))
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(ItemCategory.allCases) { category in
                    let categoryItems = items.filter { $0.category == category }
                    Button { onSelectCategory(category) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: categoryIcon(category))
                                    .font(FigmaFont.regular(20))
                                    .foregroundStyle(SmartPawStyle.orange)
                                    .frame(width: 34, height: 34)
                                    .background(SmartPawStyle.tan.opacity(0.6), in: Circle())
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(FigmaFont.semibold(12))
                                    .foregroundStyle(SmartPawStyle.brown.opacity(0.35))
                            }
                            Text(category.englishName)
                                .font(FigmaFont.medium(15))
                                .foregroundStyle(SmartPawStyle.brown)
                            Text("\(categoryItems.count) items")
                                .font(FigmaFont.regular(12))
                                .foregroundStyle(SmartPawStyle.brown.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(SmartPawStyle.hairline, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View \(category.englishName) category")
                }
            }

            HStack {
                Text("Recently added")
                    .font(FigmaFont.semibold(18))
                    .foregroundStyle(SmartPawStyle.brown)
                Spacer()
                Button(action: onAddItem) {
                    Image(systemName: "plus")
                        .font(FigmaFont.semibold(17))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(SmartPawStyle.orange, in: Circle())
                }
                .accessibilityLabel("Add item")
            }

            if items.isEmpty {
                Text("No matching items yet. Capture a photo or add one manually.")
                    .font(FigmaFont.regular(14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
            } else {
                ForEach(items.prefix(5)) { item in
                    FigmaCatalogItemRow(
                        item: item,
                        isEditing: isEditing,
                        onOpen: { onOpenItem(item) },
                        onEdit: { onEditItem(item) },
                        onDelete: { onDeleteItem(item) }
                    )
                }
            }
        }
    }
}

private struct FigmaCatalogItemRow: View {
    let item: DetectedItem
    let isEditing: Bool
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image(systemName: categoryIcon(item.category))
                    .foregroundStyle(SmartPawStyle.orange)
                    .frame(width: 42, height: 42)
                    .background(SmartPawStyle.tan.opacity(0.48), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.englishName)
                        .font(FigmaFont.medium(15))
                        .foregroundStyle(SmartPawStyle.brown)
                    Text("\(item.englishCategory) · \(item.englishZone)")
                        .font(FigmaFont.regular(12))
                        .foregroundStyle(SmartPawStyle.brown.opacity(0.52))
                        .lineLimit(1)
                }
                Spacer()
                if isEditing {
                    Button(action: onDelete) {
                        Image(systemName: "minus.circle.fill")
                            .font(FigmaFont.regular(20))
                            .foregroundStyle(.red.opacity(0.78))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete \(item.englishName)")
                } else {
                    Image(systemName: "chevron.right")
                        .font(FigmaFont.semibold(12))
                        .foregroundStyle(SmartPawStyle.brown.opacity(0.35))
                }
            }
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
    }
}

private struct CatalogAddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AppViewModel
    @Binding var name: String
    @Binding var category: ItemCategory
    let onSave: () -> Void
    @State private var mode: AddItemMode = .choice

    private enum AddItemMode {
        case choice
        case manual
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Add new item")
                    .font(FigmaFont.semibold(24))
                    .foregroundStyle(SmartPawStyle.brown)
                Text(mode == .choice ? "Choose how to add an item to the catalog" : "Enter item details and choose a category")
                    .font(FigmaFont.regular(14))
                    .foregroundStyle(.secondary)
                if mode == .choice {
                    HStack(spacing: 12) {
                        AddItemChoiceCard(
                            title: "Capture",
                            subtitle: "AI recognition",
                            icon: "camera.fill",
                            tint: SmartPawStyle.orange
                        ) {
                            viewModel.selectedTab = .capture
                            dismiss()
                        }
                        AddItemChoiceCard(
                            title: "Manual",
                            subtitle: "Enter item details",
                            icon: "textformat",
                            tint: SmartPawStyle.blue
                        ) {
                            withAnimation(.easeOut(duration: 0.18)) { mode = .manual }
                        }
                    }
                } else {
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { mode = .choice }
                    } label: {
                        Label("Back to add options", systemImage: "chevron.left")
                            .font(FigmaFont.medium(14))
                            .foregroundStyle(SmartPawStyle.orange)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Item name", text: $name)
                            .padding(13)
                            .background(SmartPawStyle.softPanel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Picker("Category", selection: $category) {
                            ForEach(ItemCategory.allCases) { Text($0.englishName).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    Button("Save item", action: onSave)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.45)
                }
                Spacer()
            }
            .padding(20)
            .background(SmartPawStyle.canvas.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct AddItemChoiceCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: icon)
                    .font(FigmaFont.semibold(18))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(FigmaFont.medium(15))
                    .foregroundStyle(SmartPawStyle.brown)
                Text(subtitle)
                    .font(FigmaFont.regular(11))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.52))
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .padding(14)
            .background(SmartPawStyle.canvas, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title + subtitle)
    }
}

private struct CategoryDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AppViewModel
    let category: ItemCategory

    private var items: [DetectedItem] { viewModel.catalogItems.filter { $0.category == category } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AdvicePanel(title: "Recommended location", icon: "mappin.and.ellipse", text: category.suggestedZone)
                    AdvicePanel(title: "Usage tips", icon: "lightbulb.fill", text: usageAdvice(for: category))
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Items in category · \(items.count)")
                                .font(FigmaFont.semibold(17))
                                .foregroundStyle(SmartPawStyle.brown)
                            if items.isEmpty {
                                Text("This category has no items yet.")
                                    .font(FigmaFont.regular(14))
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(items) { item in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.englishName).font(FigmaFont.semibold(14))
                                        Text(EnglishDisplay.space(sourceSpaceName(for: item, in: viewModel.spaces)))
                                            .font(FigmaFont.regular(12))
                                            .foregroundStyle(.secondary)
                                    }
                                    .accessibilityElement(children: .combine)
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }
            .background(SmartPawStyle.canvas.ignoresSafeArea())
            .navigationTitle(category.englishName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}

private struct CatalogItemDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AppViewModel
    let item: DetectedItem
    @State private var showsEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Card {
                        HStack(spacing: 14) {
                            Image(systemName: categoryIcon(item.category))
                                .font(FigmaFont.regular(22))
                                .foregroundStyle(SmartPawStyle.orange)
                                .frame(width: 44, height: 44)
                                .background(SmartPawStyle.softPanel, in: SmartPawStyle.cardShape)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.englishName).font(FigmaFont.semibold(17)).foregroundStyle(SmartPawStyle.brown)
                                Text(item.englishCategory).font(FigmaFont.regular(12)).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    AdvicePanel(title: "Source space", icon: "house.fill", text: EnglishDisplay.space(sourceSpaceName(for: item, in: viewModel.spaces)))
                    AdvicePanel(title: "Storage location", icon: "mappin.and.ellipse", text: item.englishZone)
                    AdvicePanel(title: "Usage tips", icon: "lightbulb.fill", text: usageAdvice(for: item.category))
                }
                .padding(18)
            }
            .background(SmartPawStyle.canvas.ignoresSafeArea())
            .navigationTitle("Item details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showsEditor = true } label: { Label("Edit", systemImage: "pencil") }
                }
            }
            .sheet(isPresented: $showsEditor) {
                CatalogItemEditor(item: viewModel.catalogItems.first(where: { $0.id == item.id }) ?? item)
            }
        }
    }
}

private struct CatalogItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var draft: DetectedItem

    init(item: DetectedItem) { _draft = State(initialValue: item) }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !draft.suggestedZone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $draft.name)
                    Picker("Category", selection: $draft.category) {
                        ForEach(ItemCategory.allCases) { Text($0.englishName).tag($0) }
                    }
                    .onChange(of: draft.category) { _, category in draft.suggestedZone = category.suggestedZone }
                }
                Section("Storage location") { TextField("Suggested location", text: $draft.suggestedZone, axis: .vertical) }
                Section("Source space") { Text(EnglishDisplay.space(sourceSpaceName(for: draft, in: viewModel.spaces))) }
            }
            .navigationTitle("Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        draft.suggestedZone = draft.suggestedZone.trimmingCharacters(in: .whitespacesAndNewlines)
                        viewModel.updateCatalogItem(draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

private struct AdvicePanel: View {
    let title: String
    let icon: String
    let text: String

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon).foregroundStyle(SmartPawStyle.orange).frame(width: 24)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(FigmaFont.semibold(17)).foregroundStyle(SmartPawStyle.brown)
                    Text(text).font(FigmaFont.regular(14)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)
        }
    }
}

private func sourceSpaceName(for item: DetectedItem, in spaces: [StorageSpace]) -> String {
    EnglishDisplay.space(spaces.first(where: { $0.detectedItems.contains(where: { $0.id == item.id }) })?.name ?? "Unlinked space")
}

private func usageAdvice(for category: ItemCategory) -> String {
    switch category {
    case .books: "Store books vertically by frequency; keep daily reads within reach and reset them weekly."
    case .electronics: "Pair cables with devices, leave airflow around the charging zone, and review unused devices regularly."
    case .stationery: "Sort by writing, cutting, and sticking; keep only today's tools on the desk."
    case .clothes: "Fold seasonal clothes by type and separate worn items from laundry."
    case .toys: "Layer display pieces and low-frequency items; use clear containers or labels."
    case .trash: "Move waste out of the living area promptly and keep recycling dry and separate."
    case .tools: "Store tools as task sets, keep frequent tools nearby, and return them after use."
    }
}

private func categoryIcon(_ category: ItemCategory) -> String {
    switch category {
    case .books: "books.vertical.fill"
    case .electronics: "ipad.and.iphone"
    case .stationery: "pencil.and.ruler.fill"
    case .clothes: "tshirt.fill"
    case .toys: "gift.fill"
    case .trash: "trash.fill"
    case .tools: "shippingbox.fill"
    }
}
