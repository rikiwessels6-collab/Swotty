import SwiftUI

// MARK: - Colours and icons for subjects
enum SubjectColour: String, CaseIterable, Identifiable, Codable {
    case gold, emerald
    case red, orange, yellow, green, mint, teal, blue, indigo, purple, pink, brown, grey

    var id: String { rawValue }

    // A refined palette: deeper, slightly muted tones that sit well on navy and ivory.
    var color: Color {
        switch self {
        case .gold: return Theme.gold
        case .emerald: return Theme.emerald
        default: return Color(hex: hex)
        }
    }

    // The colour as a plain number, so the widget can draw the same colours.
    var hex: UInt32 {
        switch self {
        case .gold: return 0xE3B25A
        case .emerald: return 0x2DC48D
        case .red: return 0xD1495B
        case .orange: return 0xE08E45
        case .yellow: return 0xE3B23C
        case .green: return 0x2FA77B
        case .mint: return 0x6CC4A1
        case .teal: return 0x2A9DA8
        case .blue: return 0x4C7DDB
        case .indigo: return 0x6B63D6
        case .purple: return 0x9A5FC0
        case .pink: return 0xD86BA0
        case .brown: return 0x9B7653
        case .grey: return 0x8591A5
        }
    }
}

// Icons come from Apple's SF Symbols collection.
let subjectIcons = [
    "function", "book.fill", "atom", "globe.asia.australia.fill",
    "character.bubble.fill", "paintpalette.fill", "figure.run", "star.fill",
    "music.note", "laptopcomputer", "leaf.fill", "testtube.2",
    "building.columns.fill", "theatermasks.fill", "hammer.fill", "heart.fill",
    "cross.fill", "fork.knife", "brain.head.profile", "lightbulb.fill",
    "pencil", "graduationcap.fill"
]

// MARK: - Subjects
// Subjects are data, so they can be added, renamed and
// recoloured in Settings.
struct Subject: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var colour: SubjectColour
    var icon: String
    var targetPercentage: Double? = nil   // optional goal for this subject's average

    var color: Color { colour.color }

    static let otherID = "other"

    static let fallback = Subject(id: otherID, name: "Other", colour: .grey, icon: "star.fill")

    // ---- Subject library ----
    // Based on a Queensland Years 7–10 program: core subjects,
    // languages, The Arts and Technologies electives.
    // The ids "hass" and "health" are kept from earlier
    // versions so saved assessments still match.
    static let english = Subject(id: "english", name: "English", colour: .blue, icon: "book.fill")
    static let maths = Subject(id: "maths", name: "Maths", colour: .red, icon: "function")
    static let science = Subject(id: "science", name: "Science", colour: .green, icon: "atom")
    static let religion = Subject(id: "religion", name: "Religion", colour: .indigo, icon: "cross.fill")
    static let humanities = Subject(id: "hass", name: "Humanities", colour: .orange, icon: "globe.asia.australia.fill")
    static let hpe = Subject(id: "health", name: "HPE", colour: .teal, icon: "figure.run")
    static let pde = Subject(id: "pde", name: "PDE", colour: .mint, icon: "heart.fill")

    static let italian = Subject(id: "italian", name: "Italian", colour: .green, icon: "character.bubble.fill")
    static let japanese = Subject(id: "japanese", name: "Japanese", colour: .red, icon: "character.bubble.fill")
    static let languages = Subject(id: "languages", name: "Languages", colour: .purple, icon: "character.bubble.fill")

    static let drama = Subject(id: "drama", name: "Drama", colour: .purple, icon: "theatermasks.fill")
    static let music = Subject(id: "music", name: "Music", colour: .pink, icon: "music.note")
    static let visualArt = Subject(id: "visualart", name: "Visual Art", colour: .yellow, icon: "paintpalette.fill")
    static let arts = Subject(id: "arts", name: "The Arts", colour: .pink, icon: "paintpalette.fill")

    static let designTech = Subject(id: "designtech", name: "Design & Technologies", colour: .brown, icon: "hammer.fill")
    static let digitalTech = Subject(id: "digitech", name: "Digital Technologies", colour: .blue, icon: "laptopcomputer")
    static let foodTech = Subject(id: "foodtech", name: "Food & Fibre", colour: .orange, icon: "fork.knife")

    static let philosophy = Subject(id: "philosophy", name: "Philosophy", colour: .brown, icon: "brain.head.profile")

    static let library: [SubjectGroup] = [
        SubjectGroup(name: "Core", subjects: [english, maths, science, religion, humanities, hpe, pde]),
        SubjectGroup(name: "Languages", subjects: [italian, japanese, languages]),
        SubjectGroup(name: "The Arts", subjects: [drama, music, visualArt, arts]),
        SubjectGroup(name: "Technologies", subjects: [designTech, digitalTech, foodTech]),
        SubjectGroup(name: "Extras", subjects: [philosophy, fallback])
    ]

    // The list a brand-new install starts with.
    static let defaults: [Subject] = [
        english, maths, science, religion, humanities, hpe, pde,
        languages, arts, designTech, fallback
    ]
}

struct SubjectGroup: Identifiable {
    let name: String
    let subjects: [Subject]
    var id: String { name }
}
