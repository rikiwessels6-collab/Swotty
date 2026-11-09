import SwiftUI

// Shows 17.5 as "17.5" and 17.0 as "17".
func formatNumber(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...1)))
}

func formatMinutes(_ minutes: Int) -> String {
    if minutes < 60 { return "\(minutes) min" }
    let hours = minutes / 60
    let mins = minutes % 60
    return mins == 0 ? "\(hours) h" : "\(hours) h \(mins) min"
}

// A rounded "card" look used on the Calendar and Focus tabs.
extension View {
    func card() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }
}
