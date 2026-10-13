import SwiftUI
import SwiftData

/// The scrollable list of 8-counts under the video.
/// Tap a row to jump there, ⟳ to loop it, ✎ to write notes.
@MainActor
struct CountListView: View {
    let project: Project
    let grid: CountGrid
    /// The 8-count playing right now (nil before count 1).
    let currentIndex: Int?
    /// The 8-count being looped, if any.
    let loopedIndex: Int?
    /// When true, the list scrolls by itself to keep the current 8-count visible.
    let followPlayback: Bool
    let onJump: (Int) -> Void
    let onToggleLoop: (Int) -> Void
    let onEdit: (Int) -> Void
    let onSetupTempo: () -> Void

    init(project: Project, grid: CountGrid, currentIndex: Int?, loopedIndex: Int?, followPlayback: Bool,
         onJump: @escaping (Int) -> Void,
         onToggleLoop: @escaping (Int) -> Void,
         onEdit: @escaping (Int) -> Void,
         onSetupTempo: @escaping () -> Void) {
        self.project = project
        self.grid = grid
        self.currentIndex = currentIndex
        self.loopedIndex = loopedIndex
        self.followPlayback = followPlayback
        self.onJump = onJump
        self.onToggleLoop = onToggleLoop
        self.onEdit = onEdit
        self.onSetupTempo = onSetupTempo
    }

    var body: some View {
        // Look up notes by 8-count number once, not once per row.
        let notesByIndex = Self.noteLookup(project.notes)

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    tempoChip
                    rows(notesByIndex)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .onChange(of: currentIndex) { _, newIndex in
                guard followPlayback, let newIndex else { return }
                scroll(proxy, to: newIndex)
            }
            .onChange(of: followPlayback) { _, isOn in
                guard isOn, let index = currentIndex else { return }
                scroll(proxy, to: index)
            }
        }
    }

    // MARK: - Pieces

    /// "♩ 120 BPM · count 1 at 0:03.20   Edit ›" — tap to open the tempo sheet.
    private var tempoChip: some View {
        Button(action: onSetupTempo) {
            HStack(spacing: 8) {
                if grid.bpm > 0 {
                    Text("♩ \(TempoTapper.displayString(for: grid.bpm)) BPM · count 1 at \(formatTime(grid.offset))")
                        .foregroundStyle(Color.white)
                } else {
                    Text("♩ Tempo not set")
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer(minLength: 8)
                Text(grid.bpm > 0 ? "Edit" : "Set")
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.accent)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.accent)
            }
            .font(.subheadline.weight(.medium).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Capsule().fill(Theme.surface))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tempoAccessibilityText)
    }

    private var tempoAccessibilityText: String {
        guard grid.bpm > 0 else { return "Tempo not set. Set tempo." }
        return "Tempo \(TempoTapper.displayString(for: grid.bpm)) BPM, count 1 at \(formatTime(grid.offset)). Edit."
    }

    @ViewBuilder
    private func rows(_ notesByIndex: [Int: CountNote]) -> some View {
        if grid.isValid && grid.numberOfEightCounts > 0 {
            ForEach(0..<grid.numberOfEightCounts, id: \.self) { index in
                CountRowView(
                    index: index,
                    startTime: grid.start(of: index),
                    note: notesByIndex[index],
                    isCurrent: currentIndex == index,
                    isLooped: loopedIndex == index,
                    onJump: { onJump(index) },
                    onToggleLoop: { onToggleLoop(index) },
                    onEdit: { onEdit(index) }
                )
                .id(index)
            }
        } else if grid.bpm > 0 && grid.duration <= 0 {
            // BPM is set, we're just waiting for the video's length.
            ProgressView("Loading video…")
                .padding(.top, 40)
        } else if grid.isValid {
            // BPM is set but count 1 is at/after the end of the video.
            messageState(
                title: "Count 1 is after the end",
                message: "Count 1 is set to \(formatTime(grid.offset)), but the video is only \(formatTime(grid.duration)) long. Move the start of count 1 earlier.",
                buttonTitle: "Fix Start of Count 1"
            )
        } else {
            messageState(
                title: "No 8-counts yet",
                message: "Set the song's BPM (or tap along) to split the video into 8-counts.",
                buttonTitle: "Set Tempo"
            )
        }
    }

    private func messageState(title: String, message: String, buttonTitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "metronome")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.title3.weight(.bold))
            Text(message)
                .font(.body)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onSetupTempo) {
                Label(buttonTitle, systemImage: "metronome")
            }
            .buttonStyle(.big(isOn: true))
            .padding(.horizontal, 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func scroll(_ proxy: ScrollViewProxy, to index: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(index, anchor: .center)
        }
    }

    /// [8-count number: note]. If there are ever two notes for the same
    /// 8-count (shouldn't happen), prefer the one with content.
    private static func noteLookup(_ notes: [CountNote]) -> [Int: CountNote] {
        var lookup: [Int: CountNote] = [:]
        for note in notes {
            if let existing = lookup[note.countIndex], !existing.isEmpty {
                continue
            }
            lookup[note.countIndex] = note
        }
        return lookup
    }
}
