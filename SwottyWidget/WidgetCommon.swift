import SwiftUI
import WidgetKit

// MARK: - Look (navy and gold, matching the app)
enum WidgetPalette {
    static let navy = Color(hex: 0x0A1524)
    static let navyLight = Color(hex: 0x1B3050)
    static let gold = Color(hex: 0xE3B25A)
    static let emerald = Color(hex: 0x2DC48D)
    static let alert = Color(hex: 0xD1495B)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    // True for light colours (like gold), which need dark text on top.
    static func prefersDarkText(_ hex: UInt32) -> Bool {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        return 0.299 * red + 0.587 * green + 0.114 * blue > 0.62
    }
}

func serif(_ style: Font.TextStyle) -> Font {
    .system(style, design: .serif).weight(.semibold)
}

extension View {
    // iOS 17 needs containerBackground; earlier versions use a plain background.
    @ViewBuilder
    func widgetBackground<Background: View>(_ background: Background) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) { background }
        } else {
            self.background(background)
        }
    }
}

struct WidgetBackground: View {
    var body: some View {
        LinearGradient(colors: [WidgetPalette.navyLight, WidgetPalette.navy],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// A gold capsule used as the widget's title.
struct TitlePill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(.footnote, design: .serif).weight(.bold))
            .foregroundStyle(WidgetPalette.navy)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(WidgetPalette.gold))
    }
}

struct WeekPill: View {
    let type: Int
    var body: some View {
        Text(type == 2 ? "Week B" : "Week A")
            .font(.caption2.weight(.bold))
            .foregroundStyle(WidgetPalette.navy)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(type == 2 ? WidgetPalette.emerald : WidgetPalette.gold))
    }
}

struct SetupMessage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "calendar.badge.plus")
                .font(.title3)
                .foregroundStyle(WidgetPalette.gold)
            Text("Open Swotty")
                .font(serif(.subheadline))
                .foregroundStyle(.white)
            Text("Add your lessons and this widget fills in by itself.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
