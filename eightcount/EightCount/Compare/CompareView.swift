import AVFoundation
import SwiftData
import SwiftUI
import UIKit

/// Watch yourself (a "take") next to the tutorial, perfectly in sync, with the
/// tutorial's music.
///
///  - Landscape: YOU on the left, TUTORIAL on the right.
///  - Portrait:  YOU on top, TUTORIAL at the bottom.
///  - "Overlay" mode: the tutorial is a see-through ghost over you.
///
/// Present it with `.fullScreenCover`. It has its own close button.
@MainActor
struct CompareView: View {
    let project: Project
    let take: Take
    let tutorialMirrored: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var playback: SyncedPlayback

    /// true = two videos next to each other, false = ghost overlay.
    @State private var isSideBySide = true
    /// Your video is flipped by default, like looking in a mirror.
    /// (The recorded file itself is NOT mirrored.)
    @State private var mirrorMe = true
    @State private var mirrorTutorial: Bool
    /// How visible the tutorial ghost is in overlay mode.
    @State private var ghostOpacity = 0.45
    @State private var controlsVisible = true

    @State private var showSync = false
    @State private var showAnalysis = false

    /// While the slider thumb is dragged we show this value instead of the
    /// real playhead, so updates don't fight your finger.
    @State private var isScrubbing = false
    @State private var scrubTime = 0.0
    @State private var wasPlayingBeforeScrub = false

    init(project: Project, take: Take, tutorialMirrored: Bool) {
        self.project = project
        self.take = take
        self.tutorialMirrored = tutorialMirrored
        _playback = State(initialValue: SyncedPlayback(project: project, take: take))
        _mirrorTutorial = State(initialValue: tutorialMirrored)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            let insets = geo.safeAreaInsets
            VStack(spacing: 0) {
                videoRegion(landscape: landscape, insets: insets)
                // Portrait: the controls sit under the videos so they never cover them.
                if !landscape && controlsVisible {
                    portraitBar(insets: insets)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.2), value: controlsVisible)
        .onAppear {
            OrientationLock.allowLandscape()
            SyncedPlayback.activateAudioSession()
        }
        .task {
            await playback.load()
        }
        .onDisappear {
            OrientationLock.portraitOnly()
            playback.tearDown()
            try? modelContext.save()
        }
        .sheet(isPresented: $showAnalysis) {
            AnalysisView(
                project: project,
                take: take,
                tutorialMirrored: mirrorTutorial,
                takeMirrored: mirrorMe,
                onJump: { time in playback.seek(to: time) }
            )
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
    }

    // MARK: - Videos

    /// The videos plus the floating controls. Tapping the video hides/shows them.
    private func videoRegion(landscape: Bool, insets: EdgeInsets) -> some View {
        videoArea(landscape: landscape)
            .contentShape(Rectangle())
            .onTapGesture {
                controlsVisible.toggle()
            }
            .overlay(alignment: .top) {
                if controlsVisible {
                    topRow(insets: insets)
                }
            }
            .overlay(alignment: .bottom) {
                // Landscape: a compact bar floats over the bottom of the videos.
                if landscape && controlsVisible {
                    landscapeBar(insets: insets)
                }
            }
    }

    @ViewBuilder
    private func videoArea(landscape: Bool) -> some View {
        ZStack {
            Color.black

            if isSideBySide {
                // AnyLayout keeps the same views when the phone rotates.
                let layout = landscape
                    ? AnyLayout(HStackLayout(spacing: 2))
                    : AnyLayout(VStackLayout(spacing: 2))
                layout {
                    pane(title: "YOU", badge: landscape ? .topTrailing : .bottomLeading) {
                        youVideo
                    }
                    pane(title: "TUTORIAL", badge: landscape ? .topLeading : .bottomLeading) {
                        tutorialVideo
                    }
                }
            } else {
                // Overlay: you underneath, the tutorial as a ghost on top.
                ZStack {
                    youVideo
                    tutorialVideo
                        .opacity(ghostOpacity)
                        .allowsHitTesting(false)
                }
            }

            statusOverlay
        }
    }

    /// One video with a small capsule badge in a corner.
    private func pane<Content: View>(title: String, badge: Alignment,
                                     @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: badge) {
            content()
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.heavy))
                .tracking(1)
                .foregroundStyle(Color.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .padding(8)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var youVideo: some View {
        CompareVideoLayer(player: playback.takePlayer)
            .scaleEffect(x: mirrorMe ? -1 : 1, y: 1)
            .opacity(playback.isReady ? 1 : 0)
    }

    private var tutorialVideo: some View {
        CompareVideoLayer(player: playback.tutorialPlayer)
            .scaleEffect(x: mirrorTutorial ? -1 : 1, y: 1)
            .opacity(playback.isReady ? 1 : 0)
    }

    @ViewBuilder
    private var statusOverlay: some View {
        if let error = playback.loadError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding()
        } else if !playback.isReady {
            ProgressView()
                .tint(.white)
                .controlSize(.large)
        }
    }

    // MARK: - Top row (close, layout, mirror, sync, analyze)

    private func topRow(insets: EdgeInsets) -> some View {
        GlassGroup(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.big)
                .frame(width: 56)
                .accessibilityLabel("Close")

                Spacer(minLength: 0)

                Button {
                    isSideBySide.toggle()
                } label: {
                    Image(systemName: "square.on.square")
                }
                .buttonStyle(.big(isOn: !isSideBySide, tint: Theme.loopColor))
                .frame(width: 56)
                .accessibilityLabel(isSideBySide ? "Switch to overlay" : "Switch to side by side")

                mirrorMenu

                Button {
                    showSync = true
                } label: {
                    Text("Sync")
                }
                .buttonStyle(.big(isOn: abs(playback.nudge) > 0.0005, tint: Theme.loopColor))
                .frame(width: 72)
                .accessibilityLabel("Sync")
                .popover(isPresented: $showSync) {
                    CompareSyncPanel(playback: playback) {
                        // Close the popover first, then open the analysis sheet.
                        showSync = false
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 400_000_000)
                            showAnalysis = true
                        }
                    }
                    .presentationCompactAdaptation(.popover)
                    .preferredColorScheme(.dark)
                }

                Button {
                    showAnalysis = true
                } label: {
                    Image(systemName: "sparkles")
                }
                .buttonStyle(.big)
                .frame(width: 56)
                .accessibilityLabel("Analyze")
            }
        }
        .padding(.top, max(insets.top, 8))
        .padding(.leading, insets.leading + 12)
        .padding(.trailing, insets.trailing + 12)
    }

    /// Mirror switches live in a menu to save space.
    private var mirrorMenu: some View {
        Menu {
            Toggle("Mirror me", isOn: $mirrorMe)
            Toggle("Mirror tutorial", isOn: $mirrorTutorial)
        } label: {
            Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Color.white)
                .frame(width: 56, height: Theme.tapHeight)
                .glassSurface(RoundedRectangle(cornerRadius: 14, style: .continuous), interactive: true)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Mirror options")
    }

    // MARK: - Bottom bars

    private func portraitBar(insets: EdgeInsets) -> some View {
        GlassGroup(spacing: 8) {
            VStack(spacing: 8) {
                scrubRow
                if !isSideBySide {
                    ghostRow
                }
                HStack(spacing: 8) {
                    frameBackButton.frame(width: 64)
                    playButton
                    frameForwardButton.frame(width: 64)
                    loopButton.frame(width: 64)
                }
                speedRow
            }
        }
        .padding(.horizontal, max(insets.leading, insets.trailing, 12))
        .padding(.top, 8)
        .padding(.bottom, max(insets.bottom, 8))
        .background(Color.black)
    }

    private func landscapeBar(insets: EdgeInsets) -> some View {
        GlassGroup(spacing: 8) {
            VStack(spacing: 8) {
                scrubRow
                if !isSideBySide {
                    ghostRow
                }
                HStack(spacing: 8) {
                    frameBackButton.frame(width: 56)
                    playButton.frame(width: 84)
                    frameForwardButton.frame(width: 56)
                    loopButton.frame(width: 56)
                    speedRow
                }
            }
        }
        .padding(.leading, insets.leading + 12)
        .padding(.trailing, insets.trailing + 12)
        .padding(.bottom, max(insets.bottom, 8))
    }

    // MARK: - Control pieces

    private var playButton: some View {
        Button {
            playback.togglePlayPause()
        } label: {
            Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                .font(.title2)
        }
        .buttonStyle(.big(isOn: true))
        .disabled(!playback.isReady)
        .accessibilityLabel(playback.isPlaying ? "Pause" : "Play")
    }

    private var frameBackButton: some View {
        Button {
            playback.stepFrames(-1)
        } label: {
            Image(systemName: "backward.frame.fill")
        }
        .buttonStyle(.big)
        .disabled(!playback.isReady)
        .accessibilityLabel("Back one frame")
    }

    private var frameForwardButton: some View {
        Button {
            playback.stepFrames(1)
        } label: {
            Image(systemName: "forward.frame.fill")
        }
        .buttonStyle(.big)
        .disabled(!playback.isReady)
        .accessibilityLabel("Forward one frame")
    }

    private var loopButton: some View {
        Button {
            playback.isLooping.toggle()
        } label: {
            Image(systemName: "repeat")
        }
        .buttonStyle(.big(isOn: playback.isLooping, tint: Theme.loopColor))
        .accessibilityLabel(playback.isLooping ? "Loop on" : "Loop off")
    }

    private var speedRow: some View {
        HStack(spacing: 6) {
            ForEach(SyncedPlayback.speeds, id: \.self) { speed in
                Button {
                    playback.setRate(speed)
                } label: {
                    Text(SyncedPlayback.speedLabel(Double(speed)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .buttonStyle(.big(isOn: playback.rate == speed))
                .accessibilityLabel("Speed \(SyncedPlayback.speedLabel(Double(speed)))")
            }
        }
    }

    // MARK: - Scrubber

    private var shownTime: Double {
        isScrubbing ? scrubTime : playback.currentTime
    }

    /// Slider needs a non-empty range, even before loading finishes.
    private var sliderRange: ClosedRange<Double> {
        let lower = playback.range.lowerBound
        return lower...max(playback.range.upperBound, lower + 0.01)
    }

    private var scrubRow: some View {
        VStack(spacing: 2) {
            Slider(
                value: Binding(
                    get: { min(max(shownTime, sliderRange.lowerBound), sliderRange.upperBound) },
                    set: { newValue in
                        scrubTime = newValue
                        playback.seek(to: newValue)   // live preview while dragging
                    }
                ),
                in: sliderRange,
                onEditingChanged: scrubEditingChanged
            )
            .tint(Theme.accent)
            .disabled(!playback.isReady)
            .accessibilityLabel("Position")
            .accessibilityValue(formatTime(shownTime))

            HStack(alignment: .firstTextBaseline) {
                Text("\(formatTime(shownTime)) / \(formatTime(playback.range.upperBound))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let label = countLabel {
                    Text(label)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassSurface(RoundedRectangle(cornerRadius: 14, style: .continuous),
                      fallback: Color.black.opacity(0.55))
    }

    private func scrubEditingChanged(_ editing: Bool) {
        if editing {
            // Finger down: remember if we were playing, then pause.
            scrubTime = playback.currentTime
            wasPlayingBeforeScrub = playback.isPlaying
            isScrubbing = true
            playback.pause()
        } else {
            // Finger up: land exactly where the thumb is.
            playback.seek(to: scrubTime)
            isScrubbing = false
            if wasPlayingBeforeScrub {
                playback.play()
            }
        }
    }

    /// "8-count 5 · 3" when the project has a tempo.
    private var countLabel: String? {
        let grid = CountGrid(bpm: project.bpm, offset: project.offset, duration: playback.tutorialDuration)
        guard grid.isValid,
              let index = grid.index(at: shownTime),
              let beat = grid.beat(at: shownTime) else { return nil }
        return "8-count \(index + 1) · \(beat)"
    }

    /// Opacity slider for the ghost (overlay mode only).
    private var ghostRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.lefthalf.filled")
                .foregroundStyle(Color.white.opacity(0.8))
            Text("Ghost")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.white)
            Slider(value: $ghostOpacity, in: 0.2...0.8)
                .tint(Theme.loopColor)
                .accessibilityLabel("Tutorial ghost opacity")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassSurface(RoundedRectangle(cornerRadius: 14, style: .continuous),
                      fallback: Color.black.opacity(0.55))
    }
}

// MARK: - Sync popover

/// Small panel to nudge your video earlier/later and to start the analysis.
@MainActor
private struct CompareSyncPanel: View {
    let playback: SyncedPlayback
    let onAnalyze: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Sync your video")
                    .font(.system(.headline, design: .rounded))

                Text("If your moves look early or late even though you danced on the beat, nudge your video. Looks late? Tap +. Looks early? Tap −.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text("Nudge")
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text(nudgeText)
                        .font(.system(.body, design: .monospaced).weight(.bold))
                        .monospacedDigit()
                }

                GlassGroup(spacing: 8) {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            nudgeButton("−0.1 s", delta: -0.1)
                            nudgeButton("+0.1 s", delta: 0.1)
                        }
                        HStack(spacing: 8) {
                            nudgeButton("−1 frame", delta: -1.0 / SyncedPlayback.stepFPS)
                            nudgeButton("+1 frame", delta: 1.0 / SyncedPlayback.stepFPS)
                        }
                        HStack(spacing: 8) {
                            Button {
                                playback.applyNudge(-playback.nudge)
                            } label: {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(.big)
                            .disabled(abs(playback.nudge) < 0.0005)

                            Button(action: onAnalyze) {
                                Label("Analyze", systemImage: "sparkles")
                            }
                            .buttonStyle(.big(isOn: true))
                        }
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 340, height: 340)
    }

    private var nudgeText: String {
        let frames = playback.nudge * SyncedPlayback.stepFPS
        return String(format: "%+.2f s  (%+.1f fr)", playback.nudge, frames)
    }

    private func nudgeButton(_ title: String, delta: Double) -> some View {
        Button {
            playback.applyNudge(delta)
        } label: {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .buttonStyle(.big)
    }
}

// MARK: - Video layer

/// Shows an `AVPlayer` aspect-fit. (Named differently from `VideoSurface`'s
/// private `PlayerLayerView` on purpose.)
@MainActor
private struct CompareVideoLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> CompareLayerHostView {
        let view = CompareLayerHostView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: CompareLayerHostView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

/// A UIView whose own layer *is* an AVPlayerLayer.
@MainActor
private final class CompareLayerHostView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        // Safe: `layerClass` above guarantees the layer type.
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
        // Taps go to SwiftUI (tap to hide/show the controls).
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }
}
