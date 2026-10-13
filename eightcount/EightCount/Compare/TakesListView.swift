import SwiftData
import SwiftUI

/// All recordings of yourself for one project, newest first.
/// Tap one to compare it with the tutorial; swipe to delete (after a question).
@MainActor
struct TakesListView: View {
    let project: Project
    let onOpen: (Take) -> Void
    let onRecordNew: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// The take the user swiped to delete (waiting for confirmation).
    @State private var takePendingDelete: Take?
    @State private var showDeleteConfirm = false

    init(project: Project, onOpen: @escaping (Take) -> Void, onRecordNew: @escaping () -> Void) {
        self.project = project
        self.onOpen = onOpen
        self.onRecordNew = onRecordNew
    }

    /// Newest first.
    private var sortedTakes: [Take] {
        project.takes.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedTakes.isEmpty {
                    emptyState
                } else {
                    takeList
                }
            }
            .background(Theme.background)
            .navigationTitle("My Takes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onRecordNew()
                    } label: {
                        Label("Record", systemImage: "video.fill")
                    }
                }
            }
            .confirmationDialog(
                "Delete this recording?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible,
                presenting: takePendingDelete
            ) { take in
                Button("Delete", role: .destructive) {
                    TakeStore.delete(take, context: modelContext)
                    takePendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    takePendingDelete = nil
                }
            } message: { _ in
                Text("The video file and its analysis will be removed. This can't be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Pieces

    private var takeList: some View {
        List {
            // `Take` has its own `id` property, so name the identity explicitly.
            ForEach(sortedTakes, id: \.persistentModelID) { take in
                Button {
                    onOpen(take)
                } label: {
                    TakeRow(take: take)
                }
                .buttonStyle(.plain)
                .listRowBackground(Theme.surface)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        takePendingDelete = take
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No recordings yet", systemImage: "video.slash")
        } description: {
            Text("Record yourself dancing along with the tutorial, then watch both side by side.")
        } actions: {
            Button {
                onRecordNew()
            } label: {
                Label("Record Yourself", systemImage: "video.fill")
            }
            .buttonStyle(.big(isOn: true))
            .frame(maxWidth: 300)
        }
    }
}

// MARK: - One row

@MainActor
private struct TakeRow: View {
    let take: Take

    var body: some View {
        // A take that was just deleted can still be drawn for a moment;
        // reading a deleted model would crash, so skip it.
        if take.modelContext != nil {
            let report = take.analysisReport
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(take.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Color.white)

                    Text("\(formatTime(take.tutorialStart)) – \(formatTime(take.tutorialEnd))")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(Theme.secondaryText)

                    Label(SyncedPlayback.speedLabel(take.recordRate), systemImage: "speedometer")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 8)

                if let report {
                    scoreBadge(report.overallScore)
                }

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .frame(minHeight: Theme.tapHeight)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
    }

    private func scoreBadge(_ score: Int) -> some View {
        let color = scoreColor(score)
        return Text("\(score)")
            .font(.system(.title3, design: .rounded).weight(.heavy))
            .monospacedDigit()
            .foregroundStyle(color)
            .frame(width: 52, height: 40)
            .background(Capsule().fill(color.opacity(0.18)))
            .accessibilityLabel("Score \(score)")
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return Color.green }
        if score >= 60 { return Color.yellow }
        return Color.orange
    }
}
