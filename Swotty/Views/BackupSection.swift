import SwiftUI
import UniformTypeIdentifiers

// MARK: - Backup section (used inside Settings)
struct BackupSection: View {
    @EnvironmentObject private var store: StudyStore

    @State private var exportDocument = BackupDocument(file: BackupFile())
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingBackup: BackupFile? = nil
    @State private var confirmingRestore = false
    @State private var message: String? = nil

    private var filename: String {
        let day = Date().formatted(.iso8601.year().month().day())
        return "Swotty-Backup-\(day)"
    }

    var body: some View {
        Section {
            Button {
                exportDocument = BackupDocument(file: store.makeBackup())
                showingExporter = true
            } label: {
                Label("Export Backup", systemImage: "square.and.arrow.up")
            }
            .fileExporter(isPresented: $showingExporter,
                          document: exportDocument,
                          contentType: .json,
                          defaultFilename: filename) { result in
                if case .failure(let error) = result {
                    message = error.localizedDescription
                }
            }

            Button {
                showingImporter = true
            } label: {
                Label("Restore from Backup…", systemImage: "square.and.arrow.down")
            }
            .fileImporter(isPresented: $showingImporter,
                          allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .confirmationDialog("Replace all current data?",
                                isPresented: $confirmingRestore,
                                titleVisibility: .visible) {
                Button("Replace with Backup", role: .destructive) {
                    if let pendingBackup {
                        withAnimation { store.restore(from: pendingBackup) }
                    }
                    pendingBackup = nil
                }
                Button("Cancel", role: .cancel) { pendingBackup = nil }
            } message: {
                if let pendingBackup {
                    Text("This backup has \(pendingBackup.items.count) assessments and \(pendingBackup.lessons.count) lessons. Your current assessments, lessons and subjects will be replaced.")
                }
            }
            .alert("Backup", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
        } header: {
            Text("Backup")
        } footer: {
            Text("Save a copy of your assessments, results, subjects and timetable to Files, then restore it on this or another device.")
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            message = error.localizedDescription
        case .success(let url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                pendingBackup = try BackupFile.decode(from: data)
                confirmingRestore = true
            } catch {
                message = error.localizedDescription
            }
        }
    }
}
