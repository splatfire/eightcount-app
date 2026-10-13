import SwiftUI
import SwiftData

/// The practice screen for one project:
/// video on top, playback controls below, the scrollable 8-count list under that.
@MainActor
struct ProjectDetailView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext

    @State private var controller = PlayerController()

    // Updated by `PlayheadTracker` only when they actually change, so this big
    // view doesn't redraw 60 times a second while the video plays.
    @State private var currentIndex: Int?
    @State private var countLabel: String?

    @State private var editing: EditTarget?
    @State private var showTempo = false
    @State private var followPlayback = true
    @State private var showReplaceConfirm = false
    @State private var showReplaceSheet = false
    @State private var isGrabbing = false
    @State private var snapshotCount = 0
    @State private var flash = false
    @State private var alertMessage: String?

    // Recording yourself and comparing (see Recording/ and Compare/).
    @State private var showRecord = false
    @State private var showTakes = false
    @State private var comparing: Take?
    /// Actions to run once a sheet/cover has finished closing (SwiftUI can't
    /// open a new full-screen cover while another one is still closing).
    @State private var pendingCompare: Take?
    @State private var pendingRecord = false
    /// Which video file the player has loaded, so coming back from the
    /// record/compare screens doesn't reload it (and lose your place).
    @State private var loadedFileName: String?

    /// The 8-count layout for the current BPM / offset / video length.
    private var grid: CountGrid {
        CountGrid(bpm: project.bpm, offset: project.offset, duration: controller.duration)
    }

    /// True when the project has a video and the file is really there.
    private var hasVideo: Bool {
        guard let url = project.videoURL else { return false }
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    var body: some View {
        Group {
            if hasVideo {
                practiceView
            } else {
                noVideoView
            }
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        // (Re)load the video whenever the project's video file changes.
        .task(id: project.videoFileName) {
            guard hasVideo, let url = project.videoURL,
                  loadedFileName != project.videoFileName else { return }
            loadedFileName = project.videoFileName
            await controller.load(url: url)
        }
        .onDisappear { controller.tearDown() }
        .sheet(item: $editing) { target in
            NoteEditorSheet(project: project, countIndex: target.id, grid: grid)
        }
        .sheet(isPresented: $showTempo) { tempoSheet }
        .sheet(isPresented: $showReplaceSheet) { replaceVideoSheet }
        .sheet(isPresented: $showTakes, onDismiss: runPendingActions) {
            TakesListView(
                project: project,
                onOpen: { take in
                    pendingCompare = take
                    showTakes = false
                },
                onRecordNew: {
                    pendingRecord = true
                    showTakes = false
                }
            )
        }
        .fullScreenCover(isPresented: $showRecord, onDismiss: runPendingActions) {
            recordView
        }
        .fullScreenCover(item: $comparing) { take in
            CompareView(project: project, take: take, tutorialMirrored: controller.isMirrored)
        }
        .confirmationDialog(
            "Replace the video?",
            isPresented: $showReplaceConfirm,
            titleVisibility: .visible
        ) {
            Button("Choose New Video", role: .destructive) { showReplaceSheet = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The app's copy of the current video will be deleted. Your notes and snapshots stay.")
        }
        .alert("Heads up", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .sensoryFeedback(.success, trigger: snapshotCount)
    }

    // MARK: - Main layout

    private var practiceView: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Video: as wide as the screen, but never taller than ~1/3 of
                // it, so the controls and the 8-count list still fit.
                let aspect = max(controller.videoAspectRatio, 0.1)
                let videoHeight = min(geo.size.width / aspect, geo.size.height * 0.34)

                VideoSurface(controller: controller)
                    .frame(width: geo.size.width, height: videoHeight)
                    .clipped()
                    .overlay {
                        // Short white flash = "snapshot taken".
                        Color.white.opacity(flash ? 0.6 : 0)
                            .allowsHitTesting(false)
                    }
                    .background(
                        PlayheadTracker(
                            controller: controller,
                            grid: grid,
                            currentIndex: $currentIndex,
                            countLabel: $countLabel
                        )
                    )

                PlaybackControlsView(
                    controller: controller,
                    countLabel: countLabel,
                    onSnapshot: { takeSnapshot() }
                )
                .padding(.vertical, 8)

                Divider().overlay(Theme.surfaceRaised)

                CountListView(
                    project: project,
                    grid: grid,
                    currentIndex: currentIndex,
                    loopedIndex: controller.isLooping ? controller.loopedEightCount : nil,
                    followPlayback: followPlayback && controller.isPlaying,
                    onJump: { jump(to: $0) },
                    onToggleLoop: { toggleLoop($0) },
                    onEdit: { editing = EditTarget(id: $0) },
                    onSetupTempo: { showTempo = true }
                )
            }
        }
    }

    /// Shown when the project has no video yet (e.g. right after importing
    /// someone's notes) or the video file has gone missing.
    private var noVideoView: some View {
        ScrollView {
            VStack(spacing: 20) {
                ContentUnavailableView {
                    Label("No video yet", systemImage: "video.badge.plus")
                } description: {
                    if let name = project.originalVideoName {
                        Text("Add the video for this project. It was originally \"\(name)\".")
                    } else {
                        Text("Add the tutorial or dance practice video for this project.")
                    }
                }
                // The import buttons live in a sheet: SwiftUI can get confused
                // by two `.fileImporter`s in one screen hierarchy (the project
                // list already has one for importing notes).
                Button {
                    showReplaceSheet = true
                } label: {
                    Label("Add Video", systemImage: "plus")
                }
                .buttonStyle(.big(isOn: true))
                .padding(.horizontal, 24)
            }
            .padding(.top, 40)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 0) {
                Text(project.title).font(.headline)
                if !project.section.isEmpty {
                    Text(project.section)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                startRecording()
            } label: {
                Label("Record Yourself", systemImage: "record.circle")
            }
            .disabled(!hasVideo)
        }
        ToolbarItem(placement: .topBarTrailing) {
            ExportProjectButton(project: project)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showTempo = true
                } label: {
                    Label("Tempo & Count 1…", systemImage: "metronome")
                }
                Button {
                    showTakes = true
                } label: {
                    Label("My Takes (\(project.takes.count))", systemImage: "person.2.crop.square.stack")
                }
                Toggle(isOn: $followPlayback) {
                    Label("Follow Playback in List", systemImage: "list.bullet.below.rectangle")
                }
                if hasVideo {
                    Button(role: .destructive) {
                        showReplaceConfirm = true
                    } label: {
                        Label("Replace Video…", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

    // MARK: - Sheets

    private var tempoSheet: some View {
        TempoSetupSheet(
            project: project,
            currentTime: { controller.currentTime },
            playbackRate: Double(controller.rate),
            onSeek: { controller.seek(to: $0) }
        )
        // A play/pause bar inside the sheet, so you can tap along to the
        // music without closing it.
        .safeAreaInset(edge: .bottom) {
            SheetPlayBar(controller: controller)
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }

    private var replaceVideoSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(hasVideo
                     ? "Pick the new video. Notes stay attached to their 8-count numbers."
                     : "Pick the video for this project.")
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                VideoImportButtons { stored, original in
                    attachVideo(stored: stored, original: original)
                    showReplaceSheet = false
                }
                Spacer()
            }
            .padding(24)
            .navigationTitle(hasVideo ? "Replace Video" : "Add Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showReplaceSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Record & compare

    /// The record screen. It starts where you are in the video, at your
    /// current speed and mirror setting. If an A-B loop (or a looped
    /// 8-count) is on, it records exactly that part.
    private var recordView: some View {
        let looping = controller.isLooping
        let start = looping ? (controller.loopStart ?? controller.currentTime) : controller.currentTime
        let end = looping ? controller.loopEnd : nil
        return RecordView(
            project: project,
            startTime: start,
            endTime: end,
            rate: Double(controller.rate),
            tutorialMirrored: controller.isMirrored,
            onFinished: { take in
                pendingCompare = take   // opened after the cover has closed
                showRecord = false
            }
        )
    }

    private func startRecording() {
        controller.pause()
        showRecord = true
    }

    /// Runs what was requested from inside a sheet/cover once it is gone.
    private func runPendingActions() {
        if let take = pendingCompare {
            pendingCompare = nil
            comparing = take
        } else if pendingRecord {
            pendingRecord = false
            startRecording()
        }
    }

    // MARK: - Actions

    /// Tap on an 8-count: jump to its first beat.
    private func jump(to index: Int) {
        guard grid.isValid else { return }
        controller.seek(to: max(grid.start(of: index), 0))
    }

    /// Loop just this 8-count, or stop looping it if it already loops.
    private func toggleLoop(_ index: Int) {
        guard grid.isValid else { return }
        if controller.isLooping && controller.loopedEightCount == index {
            controller.clearLoop()
        } else {
            controller.loopEightCount(index, start: max(grid.start(of: index), 0), end: grid.end(of: index))
            if !controller.isPlaying { controller.play() }
        }
    }

    /// Grabs the current frame and attaches it to the 8-count at the playhead.
    private func takeSnapshot() {
        guard let url = project.videoURL, !isGrabbing else { return }
        guard grid.isValid else {
            alertMessage = "Set the BPM first (tap the tempo bar above the list), so the snapshot can be attached to an 8-count."
            return
        }
        let time = controller.currentTime
        // Before count 1 (the intro) counts as the first 8-count.
        let index = grid.index(at: time) ?? 0
        let mirrored = controller.isMirrored
        isGrabbing = true
        Task {
            defer { isGrabbing = false }
            do {
                let data = try await FrameGrabber.jpegData(from: url, at: time, mirrored: mirrored)
                NoteStore.addSnapshot(jpegData: data, time: time, countIndex: index,
                                      to: project, context: modelContext)
                snapshotCount += 1
                withAnimation(.easeOut(duration: 0.05)) { flash = true }
                // Wait a moment before fading out; setting it back in the same
                // instant would cancel the flash before it's ever drawn.
                try? await Task.sleep(for: .milliseconds(80))
                withAnimation(.easeIn(duration: 0.35)) { flash = false }
            } catch {
                alertMessage = "Couldn't grab this frame: \(error.localizedDescription)"
            }
        }
    }

    /// Stores a newly imported video on the project (replacing any old one).
    private func attachVideo(stored: String, original: String) {
        controller.pause()
        let oldName = project.videoFileName
        project.videoFileName = stored
        project.originalVideoName = original
        project.updatedAt = .now
        try? modelContext.save()
        if oldName != stored { VideoStorage.deleteVideo(named: oldName) }
    }
}

/// Identifies which 8-count the note editor is open for.
private struct EditTarget: Identifiable {
    let id: Int
}

/// Invisible helper view. It reads the playhead (which changes ~60×/s) and
/// only writes `currentIndex` / `countLabel` when they really change.
/// Keeping this in its own tiny view stops the whole screen from redrawing
/// on every frame.
private struct PlayheadTracker: View {
    let controller: PlayerController
    let grid: CountGrid
    @Binding var currentIndex: Int?
    @Binding var countLabel: String?

    var body: some View {
        let time = controller.currentTime
        let index = grid.index(at: time)
        let label = Self.label(grid: grid, time: time)
        Color.clear
            .onAppear { update(index, label) }
            .onChange(of: index) { _, newValue in update(newValue, label) }
            .onChange(of: label) { _, newValue in update(index, newValue) }
    }

    private func update(_ index: Int?, _ label: String?) {
        if currentIndex != index { currentIndex = index }
        if countLabel != label { countLabel = label }
    }

    /// "8-count 5 · 3", "Intro" before count 1, nil without BPM.
    static func label(grid: CountGrid, time: Double) -> String? {
        guard grid.isValid else { return nil }
        guard let index = grid.index(at: time), let beat = grid.beat(at: time) else { return "Intro" }
        return "8-count \(index + 1) · \(beat)"
    }
}

/// Small play/pause bar shown at the bottom of the tempo sheet.
private struct SheetPlayBar: View {
    let controller: PlayerController

    var body: some View {
        HStack(spacing: 12) {
            Text(formatTime(controller.currentTime))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Theme.secondaryText)
                .frame(minWidth: 90, alignment: .leading)
            Button {
                controller.togglePlayPause()
            } label: {
                Label(controller.isPlaying ? "Pause" : "Play",
                      systemImage: controller.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.big(isOn: true))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
