import SwiftUI
import UniformTypeIdentifiers

// MARK: - Backup file
// Everything the user has entered, saved as a readable JSON file
// they can keep in Files, iCloud Drive, email, AirDrop, etc.
struct BackupFile: Codable {
    var version = BackupFile.currentVersion
    var exportedAt = Date()
    var studentName = ""
    var subjects: [Subject] = []
    var items: [Assessment] = []
    var lessons: [Lesson] = []

    static let currentVersion = 1

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file: BackupFile
        do {
            file = try decoder.decode(BackupFile.self, from: data)
        } catch {
            throw BackupError.notABackup
        }
        guard file.version <= currentVersion else { throw BackupError.newerVersion }
        return file
    }
}

enum BackupError: LocalizedError {
    case notABackup
    case newerVersion

    var errorDescription: String? {
        switch self {
        case .notABackup:
            return "That file isn't a Swotty backup."
        case .newerVersion:
            return "That backup was made by a newer version of Swotty. Update the app and try again."
        }
    }
}

// Lets SwiftUI's file exporter write a backup to Files.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var file: BackupFile

    init(file: BackupFile) {
        self.file = file
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw BackupError.notABackup
        }
        file = try BackupFile.decode(from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try file.encoded())
    }
}
