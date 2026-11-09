import SwiftUI
import Charts

// MARK: - Results tab
// Averages are weighted: a result with weight 2 counts twice as
// much as one with weight 1. The range picker limits everything
// on this screen to recent results.
enum ResultsRange: String, CaseIterable, Identifiable {
    case all = "All time"
    case ninetyDays = "Last 90 days"
    case thisYear = "This year"

    var id: String { rawValue }

    // The earliest due date included, or nil for no limit.
    var cutoff: Date? {
        let calendar = Calendar.current
        switch self {
        case .all:
            return nil
        case .ninetyDays:
            return calendar.date(byAdding: .day, value: -90, to: Date())
        case .thisYear:
            return calendar.dateInterval(of: .year, for: Date())?.start
        }
    }
}

struct ResultsView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var editingItem: Assessment? = nil
    @State private var range: ResultsRange = .all

    // Marked or graded results inside the chosen range.
    private var scoped: [Assessment] {
        let cutoff = range.cutoff
        return store.items.filter { item in
            item.hasResult && (cutoff == nil || item.dueDate >= cutoff!)
        }
    }

    private var results: [Assessment] {
        scoped.sorted { $0.dueDate > $1.dueDate }
    }

    // Results that have a percentage, oldest first.
    private var markedResults: [Assessment] {
        scoped.filter { $0.percentage != nil }.sorted { $0.dueDate < $1.dueDate }
    }

    private struct SubjectAverage: Identifiable {
        let subject: Subject
        let average: Double
        let count: Int
        var id: String { subject.id }
    }

    private var subjectAverages: [SubjectAverage] {
        store.subjects.compactMap { subject in
            let items = scoped.filter { $0.subjectID == subject.id }
            guard let average = items.weightedAveragePercentage else { return nil }
            return SubjectAverage(subject: subject, average: average,
                                  count: items.filter { $0.percentage != nil }.count)
        }
    }

    private var overallAverage: Double? {
        scoped.weightedAveragePercentage
    }

    private var totalStudyMinutes: Int {
        store.items.reduce(0) { $0 + $1.studyMinutes }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Range", selection: $range) {
                        ForEach(ResultsRange.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if results.isEmpty {
                    Section {
                        EmptyStateView(icon: "chart.bar.xaxis",
                                       title: "No results yet",
                                       message: range == .all
                                       ? "Open an assessment and add your mark or grade once it's been marked."
                                       : "No results in this time range. Try \"All time\".")
                    }
                    .listRowBackground(Theme.surface)
                } else {
                    Section {
                        HStack(spacing: 10) {
                            StatTile(value: overallAverage.map { "\(Int($0.rounded()))%" } ?? "–",
                                     label: "Average", color: .indigo, icon: "chart.line.uptrend.xyaxis")
                            StatTile(value: "\(results.count)", label: "Results", color: .blue, icon: "doc.text.fill")
                            StatTile(value: formatMinutes(totalStudyMinutes), label: "Studied", color: .green, icon: "timer")
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    if !subjectAverages.isEmpty {
                        Section {
                            ForEach(subjectAverages) { row in
                                subjectRow(row)
                            }
                            if let overallAverage {
                                HStack {
                                    Text("Overall")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(formatNumber(overallAverage))%")
                                        .font(.headline)
                                }
                            }
                        } header: {
                            Text("Grades by subject")
                        } footer: {
                            Text("Weighted averages. Set a weight on each assessment to make bigger tasks count more.")
                        }
                        .listRowBackground(Theme.surface)

                        Section("Average by subject") {
                            averagesChart
                        }
                        .listRowBackground(Theme.surface)
                    }

                    if markedResults.count >= 2 {
                        Section("Marks over time") {
                            trendChart
                        }
                        .listRowBackground(Theme.surface)
                    }

                    Section("All results") {
                        ForEach(results) { item in
                            resultRow(item)
                                .contentShape(Rectangle())
                                .onTapGesture { editingItem = item }
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .listStyle(.insetGrouped)
            .themedList()
            .navigationTitle("Results")
            .sheet(item: $editingItem) { item in
                AssessmentEditor(existing: item)
                    .environmentObject(store)
            }
        }
    }

    private func subjectRow(_ row: SubjectAverage) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.subject.icon)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(row.subject.color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(row.subject.name)
                Text(row.count == 1 ? "1 result" : "\(row.count) results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let target = row.subject.targetPercentage {
                    Text(GradeTarget.advice(items: scoped.filter { $0.subjectID == row.subject.id },
                                            target: target))
                        .font(.caption)
                        .foregroundStyle(Theme.gold)
                }
            }
            Spacer()
            Text("\(formatNumber(row.average))%")
                .font(.headline)
                .foregroundStyle(color(forAverage: row.average))
        }
    }

    private func color(forAverage average: Double) -> Color {
        if average >= 85 { return .green }
        if average >= 70 { return .blue }
        if average >= 50 { return .orange }
        return .red
    }

    // Swift Charts: one coloured bar per subject.
    private var averagesChart: some View {
        Chart(subjectAverages) { row in
            BarMark(
                x: .value("Average", min(row.average, 100)),
                y: .value("Subject", row.subject.name)
            )
            .foregroundStyle(row.subject.color.gradient)
            .cornerRadius(6)
            .annotation(position: .trailing) {
                Text("\(Int(row.average.rounded()))%")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.secondary)
            }
        }
        .chartXScale(domain: 0...110)
        .chartXAxis(.hidden)
        .frame(height: CGFloat(subjectAverages.count) * 40 + 10)
        .padding(.vertical, 8)
    }

    // Each dot is one result, coloured by subject.
    private var trendChart: some View {
        Chart(markedResults) { item in
            LineMark(
                x: .value("Date", item.dueDate),
                y: .value("Mark", item.percentage ?? 0)
            )
            .foregroundStyle(Color.secondary.opacity(0.4))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Date", item.dueDate),
                y: .value("Mark", item.percentage ?? 0)
            )
            .foregroundStyle(store.subject(for: item).color)
            .symbolSize(80)
        }
        .chartYScale(domain: 0...100)
        .frame(height: 200)
        .padding(.vertical, 8)
    }

    private func resultRow(_ item: Assessment) -> some View {
        let subject = store.subject(for: item)
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                HStack(spacing: 6) {
                    SubjectTag(subject: subject)
                    Text(item.dueDate.formatted(.dateTime.day().month(.abbreviated).year()))
                    if let score = item.score, let outOf = item.outOf {
                        Text("•")
                        Text("\(formatNumber(score))/\(formatNumber(outOf))")
                    }
                    if item.weight != 1 {
                        Text("•")
                        Text("×\(formatNumber(item.weight))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            ResultBadge(item: item)
        }
        .padding(.vertical, 4)
    }
}
