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
            "删除这个物品？",
            isPresented: Binding(
                get: { itemPendingDeletion != nil },
                set: { if !$0 { itemPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                guard let itemPendingDeletion else { return }
                viewModel.removeCatalogItem(itemPendingDeletion.id)
                self.itemPendingDeletion = nil
            }
            Button("取消", role: .cancel) { itemPendingDeletion = nil }
        } message: {
            Text("删除后，物品会从所属空间和分类库中移除。")
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
                    Text("分类库")
                        .font(FigmaFont.semibold(25))
                        .foregroundStyle(SmartPawStyle.brown)
                    Text("把每件物品放回它该在的位置")
                        .font(FigmaFont.regular(13))
                        .foregroundStyle(SmartPawStyle.brown.opacity(0.58))
                }
                Spacer()
                Button {
                    isEditing.toggle()
                } label: {
                    Text(isEditing ? "完成" : "编辑")
                        .font(FigmaFont.medium(14))
                        .foregroundStyle(SmartPawStyle.orange)
                }
                .accessibilityLabel(isEditing ? "完成分类编辑" : "编辑分类物品")
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.48))
                TextField("搜索物品或分类", text: $searchText)
                    .font(FigmaFont.regular(15))
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(SmartPawStyle.brown.opacity(0.34))
                    }
                    .accessibilityLabel("清除搜索")
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
                        Text("AI 智能识别")
                            .font(FigmaFont.semibold(16))
                        Text("拍一张照片，自动整理你的物品分类")
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
            .accessibilityLabel("拍照识别并添加物品")

            HStack {
                Text("物品分类")
                    .font(FigmaFont.semibold(18))
                    .foregroundStyle(SmartPawStyle.brown)
                Spacer()
                Text("\(items.count) 件")
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
                            Text(category.rawValue)
                                .font(FigmaFont.medium(15))
                                .foregroundStyle(SmartPawStyle.brown)
                            Text("\(categoryItems.count) 件")
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
                    .accessibilityLabel("查看\(category.rawValue)分类")
                }
            }

            HStack {
                Text("最近添加")
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
                .accessibilityLabel("添加物品")
            }

            if items.isEmpty {
                Text("还没有匹配的物品，先拍照或手动添加一件吧。")
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
                    Text(item.name)
                        .font(FigmaFont.medium(15))
                        .foregroundStyle(SmartPawStyle.brown)
                    Text("\(item.category.rawValue) · \(item.suggestedZone)")
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
                    .accessibilityLabel("删除\(item.name)")
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
            Button(action: onEdit) { Label("编辑", systemImage: "pencil") }
            Button(role: .destructive, action: onDelete) { Label("删除", systemImage: "trash") }
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
                Text("添加新项目")
                    .font(FigmaFont.semibold(24))
                    .foregroundStyle(SmartPawStyle.brown)
                Text(mode == .choice ? "选择一种方式把物品放进分类库" : "填写物品信息并选择分类")
                    .font(FigmaFont.regular(14))
                    .foregroundStyle(.secondary)
                if mode == .choice {
                    HStack(spacing: 12) {
                        AddItemChoiceCard(
                            title: "拍照",
                            subtitle: "AI智能识别",
                            icon: "camera.fill",
                            tint: SmartPawStyle.orange
                        ) {
                            viewModel.selectedTab = .capture
                            dismiss()
                        }
                        AddItemChoiceCard(
                            title: "手动输入",
                            subtitle: "输入物品信息",
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
                        Label("返回添加方式", systemImage: "chevron.left")
                            .font(FigmaFont.medium(14))
                            .foregroundStyle(SmartPawStyle.orange)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("物品名称", text: $name)
                            .padding(13)
                            .background(SmartPawStyle.softPanel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Picker("分类", selection: $category) {
                            ForEach(ItemCategory.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    Button("保存物品", action: onSave)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.45)
                }
                Spacer()
            }
            .padding(20)
            .background(SmartPawStyle.canvas.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
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
                    AdvicePanel(title: "推荐收纳位置", icon: "mappin.and.ellipse", text: category.suggestedZone)
                    AdvicePanel(title: "使用建议", icon: "lightbulb.fill", text: usageAdvice(for: category))
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("分类物品 · \(items.count) 件")
                                .font(FigmaFont.semibold(17))
                                .foregroundStyle(SmartPawStyle.brown)
                            if items.isEmpty {
                                Text("这个分类还没有物品。")
                                    .font(FigmaFont.regular(14))
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(items) { item in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name).font(FigmaFont.semibold(14))
                                        Text(sourceSpaceName(for: item, in: viewModel.spaces))
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
            .navigationTitle(category.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("完成") { dismiss() } }
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
                                Text(item.name).font(FigmaFont.semibold(17)).foregroundStyle(SmartPawStyle.brown)
                                Text(item.category.rawValue).font(FigmaFont.regular(12)).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    AdvicePanel(title: "来源空间", icon: "house.fill", text: sourceSpaceName(for: item, in: viewModel.spaces))
                    AdvicePanel(title: "收纳位置", icon: "mappin.and.ellipse", text: item.suggestedZone)
                    AdvicePanel(title: "使用建议", icon: "lightbulb.fill", text: usageAdvice(for: item.category))
                }
                .padding(18)
            }
            .background(SmartPawStyle.canvas.ignoresSafeArea())
            .navigationTitle("物品详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showsEditor = true } label: { Label("编辑", systemImage: "pencil") }
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
                Section("物品") {
                    TextField("名称", text: $draft.name)
                    Picker("分类", selection: $draft.category) {
                        ForEach(ItemCategory.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .onChange(of: draft.category) { _, category in draft.suggestedZone = category.suggestedZone }
                }
                Section("收纳位置") { TextField("建议位置", text: $draft.suggestedZone, axis: .vertical) }
                Section("来源空间") { Text(sourceSpaceName(for: draft, in: viewModel.spaces)) }
            }
            .navigationTitle("编辑物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
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
    spaces.first(where: { $0.detectedItems.contains(where: { $0.id == item.id }) })?.name ?? "未关联空间"
}

private func usageAdvice(for category: ItemCategory) -> String {
    switch category {
    case .books: "按使用频率竖放，常用书保持一伸手可取；每周归位一次。"
    case .electronics: "线材与设备配对收纳，充电区保留散热空间，并定期检查闲置设备。"
    case .stationery: "按书写、裁切和粘贴用途分格，桌面只保留当天需要的工具。"
    case .clothes: "当季衣物按类别折叠，待洗与可再次穿着的衣物分开放置。"
    case .toys: "展示品与低频物品分层，使用透明容器或标签减少翻找。"
    case .trash: "及时移出生活区，可回收物保持干燥并单独归集。"
    case .tools: "按任务成套收纳，常用工具靠近操作区，使用后立即归位。"
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
