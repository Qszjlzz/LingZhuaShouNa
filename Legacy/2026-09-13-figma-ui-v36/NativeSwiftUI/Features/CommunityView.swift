import SwiftUI

struct CommunityView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var selectedCase: CommunityCase?
    @State private var selectedDetailScreen: CommunityDetailScreen?
    @State private var selectedCategory = "Recommended"
    @State private var searchText = ""
    @State private var showsSearch = false

    private let categories = ["Recommended", "Popular", "Tips", "Closet"]

    private var visibleCases: [CommunityCase] {
        let filtered: [CommunityCase]
        switch selectedCategory {
        case "Popular": filtered = viewModel.communityCases.sorted { $0.likes > $1.likes }
        case "Tips": filtered = viewModel.communityCases.filter { $0.style == .quickReset || $0.style == .professional }
        case "Closet": filtered = viewModel.communityCases.filter { $0.style == .hiddenClean }
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
                                Text(EnglishDisplay.text(category))
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
        .alert("Search community", isPresented: $showsSearch) {
            TextField("Title, author, or tag", text: $searchText)
            Button("Clear") { searchText = "" }
            Button("Done", role: .cancel) { }
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
                Text("Discover")
                    .font(FigmaFont.regular(12))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.56))
                Text("Community")
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
                Text(item.englishTitle)
                    .font(FigmaFont.medium(13))
                    .foregroundStyle(SmartPawStyle.brown)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 5) {
                    Circle().fill(SmartPawStyle.mint.opacity(0.65)).frame(width: 18, height: 18)
                    Text(item.englishAuthor).font(FigmaFont.regular(10))
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
        .accessibilityLabel("View case \(item.englishTitle)")
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
                            Text(item.englishAuthor).font(FigmaFont.medium(13))
                            Button(viewModel.followedCommunityAuthors.contains(item.author) ? "Following" : "+ Follow") {
                                viewModel.toggleCommunityFollow(author: item.author)
                            }.font(FigmaFont.medium(12)).foregroundStyle(.white)
                                .padding(.horizontal, 10).frame(height: 28).background(SmartPawStyle.orange, in: Capsule())
                        }
                        CircleIconButton(icon: "ellipsis", action: { viewModel.showMessage("Save the plan or start a remix.") })
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
                    Text(item.englishTitle + " ✨").font(FigmaFont.semibold(20)).foregroundStyle(SmartPawStyle.brown)
                    Text("I spent a weekend turning a cluttered space into a storage system that is easy to maintain. Here is the exact method I use to keep it tidy.")
                        .font(FigmaFont.regular(13)).foregroundStyle(SmartPawStyle.brown.opacity(0.7)).lineSpacing(3)
                    Text("\(planSteps.count) steps").font(FigmaFont.semibold(14)).foregroundStyle(SmartPawStyle.brown)
                    ForEach(Array(planSteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)").font(FigmaFont.medium(11)).foregroundStyle(.white).frame(width: 19, height: 19).background(SmartPawStyle.orange, in: Circle())
                            Text(step).font(FigmaFont.regular(12)).foregroundStyle(SmartPawStyle.brown.opacity(0.82))
                        }
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles").foregroundStyle(.white).frame(width: 34, height: 34).background(SmartPawStyle.blue, in: Circle())
                        VStack(alignment: .leading) { Text("Smart plan").font(FigmaFont.medium(12)); Text("Remix it for a similar space").font(FigmaFont.regular(10)) }
                        Spacer(); Button("Remix plan", action: onShowPlan).font(FigmaFont.medium(12)).foregroundStyle(.white).padding(.horizontal, 13).frame(height: 30).background(SmartPawStyle.orange, in: Capsule())
                    }
                    .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    FlowLayout(items: ["Closet makeover", "Small apartment", "Storage room", "Storage planning"])
                    Button(action: onShowComments) {
                    HStack { Text("Comments · \(viewModel.commentCount(for: item.id))").font(FigmaFont.medium(13)); Spacer(); Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)) }
                            .foregroundStyle(SmartPawStyle.brown)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 92)
            }
            HStack {
                Button("Write a comment") { onShowComments() }.font(FigmaFont.regular(13)).foregroundStyle(.secondary)
                Spacer()
                Button { viewModel.toggleCommunityLike(item.id) } label: { Image(systemName: viewModel.likedCommunityCaseIDs.contains(item.id) ? "heart.fill" : "heart") }.foregroundStyle(SmartPawStyle.orange)
                Button { viewModel.toggleCommunityFavorite(item.id) } label: { Image(systemName: viewModel.favoriteCommunityCaseIDs.contains(item.id) ? "bookmark.fill" : "bookmark") }.foregroundStyle(SmartPawStyle.brown)
                Button(action: onShowComments) { Image(systemName: "bubble.right") }.foregroundStyle(SmartPawStyle.brown)
            }
                .padding(.horizontal, 18).frame(height: 56).background(.white)
        }
    }

    private var planSteps: [String] {
        let items = item.items
        guard !items.isEmpty else { return ["Confirm the item list and clear the area", "Group items by category and keep frequent items nearby", "Place items in their recommended zones"] }
        let categories = Array(Set(items.map(\.category.englishName))).sorted()
        return [
            "Confirm \(items.count) items and clear the area",
            "Sort by \(categories.joined(separator: ", "))",
            "Place items in recommended zones and leave room for maintenance"
        ]
    }
}

struct CommunityFigmaCommentsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let item: CommunityCase
    let onDismiss: () -> Void
    @State private var commentText = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            SmartPawStyle.canvas.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack { CircleIconButton(icon: "chevron.left", action: onDismiss); Spacer(); Text("Comments").font(FigmaFont.semibold(17)).foregroundStyle(SmartPawStyle.brown); Spacer(); Color.clear.frame(width: 38, height: 38) }
                    CommunityFigmaCoverImage(item: item).frame(height: 216).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text(item.englishTitle).font(FigmaFont.semibold(18)).foregroundStyle(SmartPawStyle.brown)
                    FlowLayout(items: ["Closet makeover", "Small apartment", "Storage room", "Storage planning"])
                    Text("\(viewModel.commentCount(for: item.id)) comments").font(FigmaFont.semibold(15)).foregroundStyle(SmartPawStyle.brown)
                    if viewModel.comments(for: item.id).isEmpty {
                        Text("No comments yet. Be the first to share your experience.")
                            .font(FigmaFont.regular(13))
                            .foregroundStyle(SmartPawStyle.brown.opacity(0.5))
                    }
                    ForEach(viewModel.comments(for: item.id)) { comment in
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(SmartPawStyle.mint.opacity(0.55)).frame(width: 34, height: 34)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(comment.author).font(FigmaFont.medium(12))
                                Text(comment.body).font(FigmaFont.regular(13)).foregroundStyle(SmartPawStyle.brown.opacity(0.76))
                                Text(comment.createdAt.formatted(.relative(presentation: .named))).font(FigmaFont.regular(10)).foregroundStyle(SmartPawStyle.brown.opacity(0.46))
                            }
                            Spacer()
                            Button {
                                viewModel.toggleCommunityCommentLike(comment.id, in: item.id)
                            } label: {
                                Label("\(comment.likes)", systemImage: comment.likes > 0 ? "heart.fill" : "heart")
                                    .font(FigmaFont.regular(10))
                                    .foregroundStyle(comment.likes > 0 ? SmartPawStyle.orange : SmartPawStyle.brown.opacity(0.55))
                            }
                            .buttonStyle(.plain)
                        }
                        .foregroundStyle(SmartPawStyle.brown)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 90)
            }
            HStack(spacing: 10) {
                TextField("Write a comment...", text: $commentText)
                    .textFieldStyle(.plain)
                Button {
                    viewModel.addCommunityComment(to: item.id, body: commentText)
                    commentText = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 25))
                        .foregroundStyle(SmartPawStyle.orange)
                }
                .buttonStyle(.plain)
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
                .padding(.horizontal, 18).frame(height: 64).background(.white)
        }
    }
}

struct CommunityFigmaPlanView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let item: CommunityCase
    let onStart: () -> Void
    @State private var selectedMode = "Smart plan"

    var body: some View {
        ZStack(alignment: .bottom) {
            SmartPawStyle.canvas.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack { CircleIconButton(icon: "chevron.left", action: { dismiss() }); Spacer(); Image(systemName: "bookmark").frame(width: 38, height: 38).background(.white, in: Circle()) }
                    CommunityFigmaCoverImage(item: item).frame(height: 164).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    HStack(spacing: 0) {
                        FigmaPlanMetric(value: item.englishDuration, label: "Duration", icon: "clock")
                        FigmaPlanMetric(value: "\(areas.count)", label: "Zones", icon: "square.grid.2x2")
                        FigmaPlanMetric(value: "\(item.items.count)", label: "Items", icon: "shippingbox")
                        FigmaPlanMetric(value: "A+", label: "Match", icon: "sparkles")
                    }
                    Text("Apply to space").font(FigmaFont.medium(13)).foregroundStyle(SmartPawStyle.brown.opacity(0.64))
                    HStack(spacing: 8) { ForEach(["Existing closet", "Modular closet", "Small apartment"], id: \.self) { Text($0).font(FigmaFont.medium(12)).foregroundStyle(SmartPawStyle.brown).padding(.horizontal, 12).frame(height: 32).background(.white, in: Capsule()).overlay { Capsule().stroke(SmartPawStyle.hairline, lineWidth: 1) } } }
                    Text("Choose a plan").font(FigmaFont.medium(13)).foregroundStyle(SmartPawStyle.brown.opacity(0.64))
                    ForEach(["Quick mode", "Smart plan", "Thorough mode"], id: \.self) { mode in
                        Button { selectedMode = mode } label: {
                            HStack { Text(mode).font(FigmaFont.medium(14)); Spacer(); Image(systemName: selectedMode == mode ? "checkmark.circle.fill" : "circle").foregroundStyle(selectedMode == mode ? SmartPawStyle.orange : SmartPawStyle.hairline) }
                                .foregroundStyle(SmartPawStyle.brown).padding(14).background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }.buttonStyle(.plain)
                    }
                    HStack { Text("Zone boundaries").font(FigmaFont.semibold(16)).foregroundStyle(SmartPawStyle.brown); Spacer(); Text("Custom").font(FigmaFont.regular(12)).foregroundStyle(SmartPawStyle.orange) }
                    ForEach(Array(areas.enumerated()), id: \.element) { index, area in
                        HStack { Text("\(index + 1)").font(FigmaFont.medium(11)).foregroundStyle(.white).frame(width: 24, height: 24).background(index == 0 ? SmartPawStyle.orange : SmartPawStyle.blue, in: Circle()); VStack(alignment: .leading) { Text(EnglishDisplay.zone(area)).font(FigmaFont.medium(14)); Text("\(itemsInArea(area)) items").font(FigmaFont.regular(10)).foregroundStyle(.secondary) }; Spacer(); Text("\(areaDuration(area)) min").font(FigmaFont.regular(11)).foregroundStyle(.secondary) }
                            .foregroundStyle(SmartPawStyle.brown).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Text("Method").font(FigmaFont.semibold(16)).foregroundStyle(SmartPawStyle.brown)
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in HStack(alignment: .top, spacing: 9) { Text("\(index + 1)").font(FigmaFont.medium(11)).foregroundStyle(.white).frame(width: 22, height: 22).background(SmartPawStyle.orange, in: Circle()); Text(step).font(FigmaFont.regular(12)).foregroundStyle(SmartPawStyle.brown.opacity(0.82)); Spacer() }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous)) }
                    Text("Tools needed").font(FigmaFont.semibold(16)).foregroundStyle(SmartPawStyle.brown)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) { ForEach(["Folding box", "Hook organizer", "Label cards", "Storage box"], id: \.self) { tool in Label(tool, systemImage: "circle.dotted").font(FigmaFont.regular(11)).foregroundStyle(SmartPawStyle.brown).frame(maxWidth: .infinity, alignment: .leading).padding(10).background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous)) } }
                    Label("AI will fine-tune this plan for your space", systemImage: "sparkles").font(FigmaFont.medium(12)).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading).padding(14).background(SmartPawStyle.orange, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }.padding(16).padding(.bottom, 80)
            }
                    HStack { Button("Save") { viewModel.toggleCommunityFavorite(item.id); viewModel.showMessage("Plan saved") }.font(FigmaFont.medium(13)).foregroundStyle(SmartPawStyle.brown).frame(width: 68, height: 48).background(.white, in: Capsule()); Button { onStart(); dismiss() } label: { Label("Start this plan", systemImage: "play.fill") }.font(FigmaFont.semibold(15)).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 48).background(SmartPawStyle.orange, in: Capsule()) }.padding(.horizontal, 16).padding(.vertical, 9).background(.white)
        }
    }

    private var areas: [String] {
        let zones = Array(Set(item.items.map(\.suggestedZone))).sorted()
        return zones.isEmpty ? ["Unconfirmed storage zone"] : zones
    }

    private var steps: [String] {
        let categoryText = Array(Set(item.items.map(\.category.englishName))).sorted().joined(separator: ", ")
        return [
            "Confirm items and clear the area",
            "Sort by category: \(categoryText.isEmpty ? "Unconfirmed" : categoryText)",
            "Place items in their zones and leave room for maintenance"
        ]
    }

    private func itemsInArea(_ area: String) -> Int {
        item.items.filter { $0.suggestedZone == area }.count
    }

    private func areaDuration(_ area: String) -> Int {
        max(1, itemsInArea(area) * 2)
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

struct CommunityFigmaCoverImage: View {
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
    let categories = Array(Set(item.items.map(\.category.englishName))).sorted().joined(separator: ", ")
    let categoryLine = categories.isEmpty ? "" : "\nCategories: \(categories)"
    return "Smart Paw plan: \(item.englishTitle)\nAuthor: @\(item.englishAuthor)\nStyle: \(item.style.englishName)\nEstimated time: \(item.englishDuration)\(categoryLine)"
}
