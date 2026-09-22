import SwiftUI

enum SmartPawStyle {
    // Shared tokens mirror the warm neutral / orange system in the Figma file.
    static let orange = Color(red: 250.0 / 255.0, green: 136.0 / 255.0, blue: 58.0 / 255.0)
    static let scanRed = Color(red: 0.94, green: 0.35, blue: 0.37)
    static let brown = Color(red: 123.0 / 255.0, green: 92.0 / 255.0, blue: 72.0 / 255.0)
    static let tan = Color(red: 239.0 / 255.0, green: 230.0 / 255.0, blue: 220.0 / 255.0)
    static let canvas = Color(red: 246.0 / 255.0, green: 241.0 / 255.0, blue: 235.0 / 255.0)
    static let softPanel = Color(red: 239.0 / 255.0, green: 230.0 / 255.0, blue: 220.0 / 255.0)
    static let linen = canvas
    static let soft = softPanel
    static let mint = Color(red: 123.0 / 255.0, green: 178.0 / 255.0, blue: 143.0 / 255.0)
    static let blue = Color(red: 180.0 / 255.0, green: 199.0 / 255.0, blue: 220.0 / 255.0)
    static let hairline = brown.opacity(0.14)

    static let cardShape = RoundedRectangle(cornerRadius: 16, style: .continuous)
}

/// Figma records PingFang SC for the Chinese UI. Use the system text styles so
/// iOS resolves the installed PingFang family instead of relying on a fragile
/// custom PostScript name.
enum FigmaFont {
    static func regular(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func medium(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    static func semibold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static func bold(_ size: CGFloat) -> Font {
        .custom("PingFangSC-Semibold", size: size)
    }
}

struct BrandBadge: View {
    var size: CGFloat = 48

    var body: some View {
        Image("Frame1Logo")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .shadow(color: SmartPawStyle.brown.opacity(0.12), radius: 12, y: 6)
        .accessibilityHidden(true)
    }
}

struct Card<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(.white.opacity(0.88), in: SmartPawStyle.cardShape)
            .overlay {
                SmartPawStyle.cardShape.stroke(SmartPawStyle.hairline, lineWidth: 1)
            }
            .shadow(color: SmartPawStyle.brown.opacity(0.07), radius: 10, y: 5)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FigmaFont.semibold(17))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                SmartPawStyle.orange.opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct FigmaBottomBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            tab(.space, "house", "空间")
            tab(.catalog, "square.grid.2x2", "分类")
            Button { selection = .capture } label: {
                Image(systemName: "camera")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(SmartPawStyle.orange, in: Circle())
                    .shadow(color: SmartPawStyle.orange.opacity(0.32), radius: 14, y: 7)
            }
            .offset(y: -22)
            tab(.community, "person.2", "社区")
            tab(.profile, "person", "我的")
        }
        .padding(.horizontal, 12)
        .frame(height: 78)
        .background(.white, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    private func tab(_ value: AppTab, _ icon: String, _ title: String) -> some View {
        Button { selection = value } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 21)).frame(height: 24)
                Text(title).font(FigmaFont.regular(12))
            }
            .foregroundStyle(selection == value ? SmartPawStyle.orange : Color(red: 0.64, green: 0.59, blue: 0.54))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct Chip: View {
    let title: String
    var isSelected = false

    var body: some View {
        Text(title)
            .font(FigmaFont.semibold(15))
            .foregroundStyle(isSelected ? .white : SmartPawStyle.brown)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(isSelected ? SmartPawStyle.orange : .white, in: Capsule())
            .overlay {
                Capsule().stroke(isSelected ? .clear : SmartPawStyle.hairline, lineWidth: 1)
            }
}
}
