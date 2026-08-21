import SwiftUI

struct CommunityView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var selectedCase: CommunityCase?
    @State private var selectedDetailScreen: CommunityDetailScreen?
    @State private var selectedCategory = "推荐"
    @State private var searchText = ""
    @State private var showsSearch = false

    private let categories = ["推荐", "热门", "技巧", "衣柜"]

    private var visibleCases: [CommunityCase] {
        let filtered: [CommunityCase]
        switch selectedCategory {
        case "热门": filtered = viewModel.communityCases.sorted { $0.likes > $1.likes }
        case "技巧": filtered = viewModel.communityCases.filter { $0.tags.contains(where: { $0.contains("收") || $0.contains("整理") }) }
        case "衣柜": filtered = viewModel.communityCases.filter { $0.tags.contains(where: { $0.contains("租") || $0.contains("衣") }) }
        default: filtered = viewModel.communityCases
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return filtered }
        return filtered.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.author.localizedCaseInsensitiveContains(query) || $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) }) }
    }

    var body: some View {
        ZStack {
            SmartPawStyle.canvas.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
            CommunityHeader { showsSearch = true }
                    HStack(spacing: 10) {
                        ForEach(categories, id: \.self) { category in
                            Button { selectedCategory = category } label: {
                                Text(category)
                                    .font(FigmaFont.medium(13))
                                    .foregroundStyle(selectedCategory == category ? .white : SmartPawStyle.brown)
                                    .frame(height: 32)
                                    .padding(.horizontal, 14)
                                    .background(selectedCategory == category ? SmartPawStyle.brown : .white, in: Capsule())
                                    .overlay { Capsule().stroke(SmartPawStyle.hairline, lineWidth: 1) }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                        alignment: .leading,
                        spacing: 14
                    ) {
                        ForEach(visibleCases) { item in
                            CommunityWaterfallCard(item: item) { selectedCase = item }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 118)
            }
        }
        .fullScreenCover(item: $selectedCase) { item in
            CommunityFigmaCaseDetail(
                item: item,
                onDismiss: { selectedCase = nil },
                onShowComments: { selectedDetailScreen = .comments(item) },
                onShowPlan: { selectedDetailScreen = .plan(item) }
            )
        }
        .fullScreenCover(item: $selectedDetailScreen) { screen in
            switch screen {
            case let .comments(item):
                CommunityFigmaCommentsView(item: item, onDismiss: { selectedDetailScreen = nil })
            case let .plan(item):
                CommunityFigmaPlanView(item: item, onStart: {
                    viewModel.replicate(item)
                    selectedDetailScreen = nil
                    selectedCase = nil
                })
            }
        }
        .alert("搜索社区", isPresented: $showsSearch) {
            TextField("标题、作者或标签", text: $searchText)
            Button("清除") { searchText = "" }
            Button("完成", role: .cancel) { }
        }
    }
}

private enum CommunityDetailScreen: Identifiable {
    case comments(CommunityCase)
    case plan(CommunityCase)

    var id: String {
        switch self {
        case let .comments(item): "comments-\(item.id.uuidString)"
        case let .plan(item): "plan-\(item.id.uuidString)"
        }
    }
}

private struct CommunityHeader: View {
    let onSearch: () -> Void
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("发现")
                    .font(FigmaFont.regular(12))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.56))
                Text("社区")
                    .font(FigmaFont.semibold(30))
                    .foregroundStyle(SmartPawStyle.brown)
            }
            Spacer()
            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(SmartPawStyle.brown)
                    .frame(width: 44, height: 44)
                    .background(.white, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct CommunityWaterfallCard: View {
    let item: CommunityCase
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                CommunityFigmaCoverImage(item: item)
                    .frame(height: item.likes.isMultiple(of: 2) ? 206 : 154)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(item.title)
                    .font(FigmaFont.medium(13))
                    .foregroundStyle(SmartPawStyle.brown)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 5) {
                    Circle().fill(SmartPawStyle.mint.opacity(0.65)).frame(width: 18, height: 18)
                    Text(item.author).font(FigmaFont.regular(10))
                    Spacer(minLength: 0)
                    Image(systemName: "heart.fill").font(.system(size: 10)).foregroundStyle(SmartPawStyle.orange)
                    Text("\(item.likes)").font(FigmaFont.regular(10))
                }
                .foregroundStyle(SmartPawStyle.brown.opacity(0.62))
            }
            .padding(8)
            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("查看案例 \(item.title)")
    }
}

struct CommunityFigmaCaseDetail: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let item: CommunityCase
    let onDismiss: () -> Void
    let onShowComments: () -> Void
    let onShowPlan: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            SmartPawStyle.canvas.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        CircleIconButton(icon: "chevron.left", action: onDismiss)
                        Spacer()
                        HStack(spacing: 7) {
                            Circle().fill(SmartPawStyle.tan).frame(width: 28, height: 28)
                            Text("Mira").font(FigmaFont.medium(13))
                            Button("+ 关注") { viewModel.showMessage("已关注 @\(item.author)") }.font(FigmaFont.medium(12)).foregroundStyle(.white)
                                .padding(.horizontal, 10).frame(height: 28).background(SmartPawStyle.orange, in: Capsule())
                        }
                        CircleIconButton(icon: "ellipsis", action: { viewModel.showMessage("更多操作已打开") })
                    }
                    CommunityFigmaCoverImage(item: item)
                        .frame(height: 276)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(SmartPawStyle.brown.opacity(0.7), in: Circle())
                                .padding(12)
                        }
                    Text(item.title + " ✨").font(FigmaFont.semibold(20)).foregroundStyle(SmartPawStyle.brown)
                    Text("花了一个周末，把杂乱空间改成了一套好维护的收纳系统。分享我使用的确切方法，之后也能轻松保持整洁。")
                        .font(FigmaFont.regular(13)).foregroundStyle(SmartPawStyle.brown.opacity(0.7)).lineSpacing(3)
                    Text("5个步骤 👇").font(FigmaFont.semibold(14)).foregroundStyle(SmartPawStyle.brown)
                    ForEach(["把所有东西都拿出来，不要跳过", "按类别分类，而不是按地点", "明确每个角内没用的任何衣物", "使用开放式收纳架，节省40%空间", "把针织衫垂直叠放在这些抽屉里"], id: \.self) { step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(stepIndex(step))").font(FigmaFont.medium(11)).foregroundStyle(.white).frame(width: 19, height: 19).background(SmartPawStyle.orange, in: Circle())
                            Text(step).font(FigmaFont.regular(12)).foregroundStyle(SmartPawStyle.brown.opacity(0.82))
                        }
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles").foregroundStyle(.white).frame(width: 34, height: 34).background(SmartPawStyle.blue, in: Circle())
                        VStack(alignment: .leading) { Text("智能方案").font(FigmaFont.medium(12)); Text("相似空间可直接复刻").font(FigmaFont.regular(10)) }
                        Spacer(); Button("一键复刻", action: onShowPlan).font(FigmaFont.medium(12)).foregroundStyle(.white).padding(.horizontal, 13).frame(height: 30).background(SmartPawStyle.orange, in: Capsule())
                    }
                    .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    FlowLayout(items: ["衣柜改造", "小公寓", "储物室", "收纳规划"])
                    Button(action: onShowComments) {
                    HStack { Text("评论 · 0").font(FigmaFont.medium(13)); Spacer(); Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)) }
                            .foregroundStyle(SmartPawStyle.brown)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 92)
            }
            HStack {
                Button("说点什么...") { viewModel.showMessage("评论编辑器将在下一步打开") }.font(FigmaFont.regular(13)).foregroundStyle(.secondary)
                Spacer()
                Button { viewModel.toggleCommunityLike(item.id) } label: { Image(systemName: viewModel.likedCommunityCaseIDs.contains(item.id) ? "heart.fill" : "heart") }.foregroundStyle(SmartPawStyle.orange)
                Button { viewModel.toggleCommunityFavorite(item.id) } label: { Image(systemName: viewModel.favoriteCommunityCaseIDs.contains(item.id) ? "bookmark.fill" : "bookmark") }.foregroundStyle(SmartPawStyle.brown)
                Button(action: onShowComments) { Image(systemName: "bubble.right") }.foregroundStyle(SmartPawStyle.brown)
            }
                .padding(.horizontal, 18).frame(height: 56).background(.white)
        }
    }

    private func stepIndex(_ step: String) -> Int { ["把所有", "按类别", "明确", "使用", "把针"].firstIndex(where: { step.hasPrefix($0) })! + 1 }
}

struct CommunityFigmaCommentsView: View {
    let item: CommunityCase
    let onDismiss: () -> Void

    private let comments = [
        ("Yuuki", "大衣这收纳的建议改变了我的生活"),
        ("Mei", "你布局图里的标签好清楚了"),
        ("Mira", "买日常收纳盒，材质也很好"),
        ("Daisy", "已保存，周末就试试")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            SmartPawStyle.canvas.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack { CircleIconButton(icon: "chevron.left", action: onDismiss); Spacer(); Text("评论").font(FigmaFont.semibold(17)).foregroundStyle(SmartPawStyle.brown); Spacer(); Color.clear.frame(width: 38, height: 38) }
                    CommunityFigmaCoverImage(item: item).frame(height: 216).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text(item.title).font(FigmaFont.semibold(18)).foregroundStyle(SmartPawStyle.brown)
                    FlowLayout(items: ["衣柜改造", "小公寓", "储物室", "收纳规划"])
                    Text("87 条评论").font(FigmaFont.semibold(15)).foregroundStyle(SmartPawStyle.brown)
                    ForEach(comments, id: \.0) { author, body in
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(SmartPawStyle.mint.opacity(0.55)).frame(width: 34, height: 34)
                            VStack(alignment: .leading, spacing: 5) { Text(author).font(FigmaFont.medium(12)); Text(body).font(FigmaFont.regular(13)).foregroundStyle(SmartPawStyle.brown.opacity(0.76)); Text("刚刚").font(FigmaFont.regular(10)).foregroundStyle(SmartPawStyle.brown.opacity(0.46)) }
                            Spacer()
                            Image(systemName: "heart").font(.system(size: 13)).foregroundStyle(SmartPawStyle.brown.opacity(0.55))
                        }
                        .foregroundStyle(SmartPawStyle.brown)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 90)
            }
            HStack(spacing: 12) { Text("写下你的评论...").font(FigmaFont.regular(13)).foregroundStyle(SmartPawStyle.brown.opacity(0.48)); Spacer(); Image(systemName: "face.smiling").foregroundStyle(SmartPawStyle.brown.opacity(0.68)); Image(systemName: "arrow.up.circle.fill").font(.system(size: 25)).foregroundStyle(SmartPawStyle.orange) }
                .padding(.horizontal, 18).frame(height: 64).background(.white)
        }
    }
}

struct CommunityFigmaPlanView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let item: CommunityCase
    let onStart: () -> Void
    @State private var selectedMode = "智能方案"

    private let steps = ["把所有东西都拿出来，不要跳过", "按类别分类，而不是按地点", "明确每个角内没用的任何衣物", "使用开放式收纳架，节省40%空间", "把针织衫垂直叠放在这些抽屉里"]
    private let areas = ["书柜区", "折叠整理区", "配饰抽屉", "补货柜"]

    var body: some View {
        ZStack(alignment: .bottom) {
            SmartPawStyle.canvas.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack { CircleIconButton(icon: "chevron.left", action: { dismiss() }); Spacer(); Image(systemName: "bookmark").frame(width: 38, height: 38).background(.white, in: Circle()) }
                    CommunityFigmaCoverImage(item: item).frame(height: 164).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    HStack(spacing: 0) {
                        FigmaPlanMetric(value: item.durationText, label: "用时", icon: "clock")
                        FigmaPlanMetric(value: "4", label: "区域", icon: "square.grid.2x2")
                        FigmaPlanMetric(value: "19", label: "物品", icon: "shippingbox")
                        FigmaPlanMetric(value: "A+", label: "匹配度", icon: "sparkles")
                    }
                    Text("应用到空间").font(FigmaFont.medium(13)).foregroundStyle(SmartPawStyle.brown.opacity(0.64))
                    HStack(spacing: 8) { ForEach(["现有衣柜", "组合衣柜", "小户型"], id: \.self) { Text($0).font(FigmaFont.medium(12)).foregroundStyle(SmartPawStyle.brown).padding(.horizontal, 12).frame(height: 32).background(.white, in: Capsule()).overlay { Capsule().stroke(SmartPawStyle.hairline, lineWidth: 1) } } }
                    Text("选择方案").font(FigmaFont.medium(13)).foregroundStyle(SmartPawStyle.brown.opacity(0.64))
                    ForEach(["快速模式", "智能方案", "严谨整理"], id: \.self) { mode in
                        Button { selectedMode = mode } label: {
                            HStack { Text(mode).font(FigmaFont.medium(14)); Spacer(); Image(systemName: selectedMode == mode ? "checkmark.circle.fill" : "circle").foregroundStyle(selectedMode == mode ? SmartPawStyle.orange : SmartPawStyle.hairline) }
                                .foregroundStyle(SmartPawStyle.brown).padding(14).background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }.buttonStyle(.plain)
                    }
                    HStack { Text("区域分界").font(FigmaFont.semibold(16)).foregroundStyle(SmartPawStyle.brown); Spacer(); Text("自定义").font(FigmaFont.regular(12)).foregroundStyle(SmartPawStyle.orange) }
                    ForEach(Array(areas.enumerated()), id: \.element) { index, area in
                        HStack { Text("\(index + 1)").font(FigmaFont.medium(11)).foregroundStyle(.white).frame(width: 24, height: 24).background(index == 0 ? SmartPawStyle.orange : SmartPawStyle.blue, in: Circle()); VStack(alignment: .leading) { Text(area).font(FigmaFont.medium(14)); Text("\(index + 1) 个子任务").font(FigmaFont.regular(10)).foregroundStyle(.secondary) }; Spacer(); Text(["12分钟", "18分钟", "8分钟", "10分钟"][index]).font(FigmaFont.regular(11)).foregroundStyle(.secondary) }
                            .foregroundStyle(SmartPawStyle.brown).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Text("整理方法").font(FigmaFont.semibold(16)).foregroundStyle(SmartPawStyle.brown)
                    ForEach(Array(steps.enumerated()), id: \.element) { index, step in HStack(alignment: .top, spacing: 9) { Text("\(index + 1)").font(FigmaFont.medium(11)).foregroundStyle(.white).frame(width: 22, height: 22).background(SmartPawStyle.orange, in: Circle()); Text(step).font(FigmaFont.regular(12)).foregroundStyle(SmartPawStyle.brown.opacity(0.82)); Spacer() }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous)) }
                    Text("所需工具").font(FigmaFont.semibold(16)).foregroundStyle(SmartPawStyle.brown)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) { ForEach(["折叠收纳盒", "挂钩收纳器", "标签分类纸", "整理盒"], id: \.self) { tool in Label(tool, systemImage: "circle.dotted").font(FigmaFont.regular(11)).foregroundStyle(SmartPawStyle.brown).frame(maxWidth: .infinity, alignment: .leading).padding(10).background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous)) } }
                    Label("AI 将根据你的空间做微调", systemImage: "sparkles").font(FigmaFont.medium(12)).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading).padding(14).background(SmartPawStyle.orange, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }.padding(16).padding(.bottom, 80)
            }
                    HStack { Button("保存") { viewModel.toggleCommunityFavorite(item.id); viewModel.showMessage("方案已保存") }.font(FigmaFont.medium(13)).foregroundStyle(SmartPawStyle.brown).frame(width: 68, height: 48).background(.white, in: Capsule()); Button { onStart(); dismiss() } label: { Label("开始此方案", systemImage: "play.fill") }.font(FigmaFont.semibold(15)).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 48).background(SmartPawStyle.orange, in: Capsule()) }.padding(.horizontal, 16).padding(.vertical, 9).background(.white)
        }
    }
}

private struct FigmaPlanMetric: View {
    let value: String; let label: String; let icon: String
    var body: some View { VStack(spacing: 4) { Image(systemName: icon).font(.system(size: 12)).foregroundStyle(SmartPawStyle.orange); Text(value).font(FigmaFont.semibold(13)); Text(label).font(FigmaFont.regular(10)).foregroundStyle(.secondary) }.foregroundStyle(SmartPawStyle.brown).frame(maxWidth: .infinity) }
}

private struct CircleIconButton: View {
    let icon: String
    let action: () -> Void
    var body: some View { Button(action: action) { Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(SmartPawStyle.brown).frame(width: 38, height: 38).background(.white, in: Circle()) }.buttonStyle(.plain) }
}

private struct CommunityFigmaCoverImage: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let item: CommunityCase

    var body: some View {
        if let name = item.afterImageName, let url = viewModel.imageURL(for: name) {
            StoredImageView(url: url, fallbackProgress: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            StorageImageView(url: nil, assetName: item.afterAssetName ?? item.beforeAssetName, fallbackProgress: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private func shareText(for item: CommunityCase) -> String {
    let categories = Array(Set(item.items.map(\.category.rawValue))).sorted().joined(separator: "、")
    let categoryLine = categories.isEmpty ? "" : "\n物品分类：\(categories)"
    return "灵爪收纳方案：\(item.title)\n作者：@\(item.author)\n风格：\(item.style.rawValue)\n预计耗时：\(item.durationText)\(categoryLine)"
}
