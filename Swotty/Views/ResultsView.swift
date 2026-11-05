import SwiftUI
import Charts

// MARK: - Results tab
struct ResultsView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var editingItem: Assessment? = nil

    private var results: [Assessment] {
        store.items.filter { $0.hasResult }.sorted { $0.dueDate > $1.dueDate }
    }

    private var subjectsWithMarks: [Subject] {
        store.subjects.filter { store.averagePercentage(subjectID: $0.id) != nil }
    }

    private var totalStudyMinutes: Int {
        store.items.reduce(0) { $0 + $1.studyMinutes }
    }

    var body: some View {
        NavigationStack {
            List {
                if results.isEmpty {
                    Section {
                        EmptyStateView(icon: "chart.bar.xaxis",
                                       title: "No results yet",
                                       message: "Open an assessment and add your mark or grade once it's been marked.")
                    }
                } else {
                    Section {
                        HStack(spacing: 10) {
                            StatTile(value: store.averagePercentage().map { "\(Int($0.rounded()))%" } ?? "–",
                                     label: "Average", color: .indigo, icon: "chart.line.uptrend.xyaxis")
                            StatTile(value: "\(results.count)", label: "Results", color: .blue, icon: "doc.text.fill")
                            StatTile(value: formatMinutes(totalStudyMinutes), label: "Studied", color: .green, icon: "timer")
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    if !subjectsWithMarks.isEmpty {
                        Section("Average by subject") {
                            averagesChart
                        }
                    }

                    if markedResults.count >= 2 {
                        Section("Marks over time") {
                            trendChart
                        }
                    }

                    Section("All results") {
                        ForEach(results) { item in
                            resultRow(item)
                                .contentShape(Rectangle())
                                .onTapGesture { editingItem = item }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Results")
            .sheet(item: $editingItem) { item in
                AssessmentEditor(existing: item)
                    .environmentObject(store)
            }
        }
    }

    // Results that have a percentage, oldest first.
    private var markedResults: [Assessment] {
        store.items.filter { $0.percentage != nil }.sorted { $0.dueDate < $1.dueDate }
    }

    // Swift Charts: one coloured bar per subject.
    private var averagesChart: some View {
        Chart(subjectsWithMarks) { subject in
            let average = store.averagePercentage(subjectID: subject.id) ?? 0
            BarMark(
                x: .value("Average", min(average, 100)),
                y: .value("Subject", subject.name)
            )
            .foregroundStyle(subject.color.gradient)
            .cornerRadius(6)
            .annotation(position: .trailing) {
                Text("\(Int(average.rounded()))%")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.secondary)
            }
        }
        .chartXScale(domain: 0...110)
        .chartXAxis(.hidden)
        .frame(height: CGFloat(subjectsWithMarks.count) * 40 + 10)
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
