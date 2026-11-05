import SwiftUI
import UIKit

// MARK: - Colour helpers
extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    // A colour that changes between light and dark mode.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension Color {
    // True for light colours (e.g. gold), which need dark text on top.
    var prefersDarkText: Bool {
        let resolved = UIColor(self).resolvedColor(with: UITraitCollection.current)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return 0.299 * red + 0.587 * green + 0.114 * blue > 0.62
    }
}

// MARK: - Swotty's look: deep navy, warm gold and emerald
enum Theme {
    // Screens and cards
    static let background = Color.adaptive(light: 0xF5F2EA, dark: 0x0A1524)
    static let surface = Color.adaptive(light: 0xFFFFFF, dark: 0x122338)
    static let surfaceRaised = Color.adaptive(light: 0xECE7DB, dark: 0x1B3050)
    static let hairline = Color.adaptive(light: 0xE2DCCD, dark: 0x23395A)

    // Brand colours
    static let gold = Color.adaptive(light: 0xA97B1F, dark: 0xE3B25A)
    static let emerald = Color.adaptive(light: 0x0E8A63, dark: 0x2DC48D)
    static let navy = Color(hex: 0x0A1524)

    // Text that sits on top of a gold or emerald fill.
    static let onAccent = Color(hex: 0x0A1524)

    // ---- UIKit appearance (navigation bar, tab bar, controls) ----
    static func configureAppearance() {
        let titleFont = serifFont(size: 17, weight: .semibold)
        let largeTitleFont = serifFont(size: 34, weight: .bold)

        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        standard.backgroundColor = UIColor(Theme.background).withAlphaComponent(0.92)
        standard.titleTextAttributes = [.font: titleFont]
        standard.largeTitleTextAttributes = [.font: largeTitleFont]

        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        scrollEdge.titleTextAttributes = [.font: titleFont]
        scrollEdge.largeTitleTextAttributes = [.font: largeTitleFont]

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = standard
        navBar.compactAppearance = standard
        navBar.scrollEdgeAppearance = scrollEdge

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        tab.backgroundColor = UIColor(Theme.surface).withAlphaComponent(0.96)
        tab.shadowColor = UIColor(Theme.hairline)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        // Segmented controls: gold when selected.
        let segmented = UISegmentedControl.appearance()
        segmented.selectedSegmentTintColor = UIColor(Theme.gold)
        segmented.setTitleTextAttributes([.foregroundColor: UIColor(Theme.onAccent)], for: .selected)

        // Page dots on the setup screens.
        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(Theme.gold)
        UIPageControl.appearance().pageIndicatorTintColor = UIColor(Theme.gold).withAlphaComponent(0.3)
    }

    private static func serifFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = base.fontDescriptor.withDesign(.serif) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
    }
}

// MARK: - Typography
extension Font {
    // Elegant serif for headings and big numbers.
    static func display(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .serif).weight(weight)
    }
}

// MARK: - Reusable styling
extension View {
    // Navy (or ivory) background for List and Form screens.
    func themedList() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
    }

    // Navy (or ivory) background for ScrollView screens.
    func themedScreen() -> some View {
        self.background(Theme.background.ignoresSafeArea())
    }
}

// The main call-to-action button: a gold capsule with dark text.
struct BrandButtonStyle: ButtonStyle {
    var color: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                if let color {
                    Capsule().fill(color)
                } else {
                    Capsule().fill(TintShapeStyle())
                }
            }
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// A quieter button: outlined capsule.
struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.tint)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Capsule().strokeBorder(Theme.hairline, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
