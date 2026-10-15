import SwiftUI
import TuringCore

struct ExecutionTraceView: View {
    let records: [StepRecord]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    WorkbenchHeading(
                        eyebrow: "Execution trace",
                        title: "Every committed transition.",
                        detail: "Newest first. Each record contains the symbol read and written, the head movement, and both control states. The instrument retains the latest 4,096 records."
                    )
                    if records.isEmpty {
                        ContentUnavailableView(
                            "No transitions yet",
                            systemImage: "list.number",
                            description: Text("Step the machine to record its first atomic transition.")
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("\(records.count) retained transitions")
                            .font(.subheadline)
                            .foregroundStyle(WorkbenchStyle.secondary)
                        ForEach(records.reversed()) { record in
                            TraceRecordCard(record: record)
                        }
                    }
                }
                .padding(20)
            }
            .background(WorkbenchStyle.background)
            .navigationTitle("Trace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    WorkbenchCloseButton(label: "Close execution trace")
                }
            }
            .tint(WorkbenchStyle.accent)
        }
        .preferredColorScheme(.dark)
    }
}

private struct TraceRecordCard: View {
    let record: StepRecord

    var body: some View {
        WorkbenchPanel {
            VStack(alignment: .leading, spacing: 9) {
                Text("STEP \(record.id)")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(WorkbenchStyle.secondary)
                Text("\(record.beforeState) → \(record.afterState)")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                Text("Read \(record.read) · wrote \(record.write)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(WorkbenchStyle.accent)
                Text("Head \(record.headBefore) → \(record.headAfter) · \(record.move == .left ? "L · left" : "R · right")")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(WorkbenchStyle.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(record.id). State \(record.beforeState) to \(record.afterState). Read \(record.read), wrote \(record.write), moved \(record.move == .left ? "left" : "right") from cell \(record.headBefore) to \(record.headAfter).")
    }
}
