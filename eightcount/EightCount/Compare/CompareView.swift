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
        videoArea(landscape: landscape, insets: insets)
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
                // Landscape: a compact panel floats over the bottom of the videos.
                if landscape && controlsVisible {
                    landscapeBar(insets: insets)
                }
            }
    }

    @ViewBuilder
    private func videoArea(landscape: Bool, insets: EdgeInsets) -> some View {
        // The YOU badge sits below the top buttons while they are visible.
        let youTop = max(insets.top, 8) + (controlsVisible ? 48 : 0)
        ZStack {
            Color.black

            if isSideBySide {
                // AnyLayout keeps the same views when the phone rotates.
                let layout = landscape
                    ? AnyLayout(HStackLayout(spacing: 2))
                    : AnyLayout(VStackLayout(spacing: 2))
                layout {
                    pane(title: "YOU", top: youTop, leading: insets.leading + 10) {
                        youVideo
                    }
                    pane(title: "TUTORIAL", top: 10, leading: 10) {
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

    /// One video with a small translucent capsule badge in its top-leading corner.
    private func pane<Content: View>(title: String, top: CGFloat, leading: CGFloat,
                                     @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: .topLeading) {
            content()
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.92))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.42)))
                .padding(.top, top)
                .padding(.leading, leading)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
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
        GlassGroup(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.round(size: 40))
                .accessibilityLabel("Close")

                Spacer(minLength: 0)

                Button {
                    isSideBySide.toggle()
                } label: {
                    Image(systemName: isSideBySide ? "rectangle.split.2x1" : "square.on.square")
                }
                .buttonStyle(.round(size: 40, isOn: !isSideBySide, tint: Theme.loopColor))
                .accessibilityLabel(isSideBySide ? "Switch to overlay" : "Switch to side by side")

                mirrorMenu

                Button {
                    showSync = true
                } label: {
                    Image(systemName: "timer")
                }
                .buttonStyle(.round(size: 40, isOn: abs(playback.nudge) > 0.0005, tint: Theme.loopColor))
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
                .buttonStyle(.round(size: 40, isOn: true))
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
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 40, height: 40)
                .glassSurface(Circle(), interactive: true)
                .contentShape(Circle())
        }
        .accessibilityLabel("Mirror options")
    }

    // MARK: - Bottom controls

    private func portraitBar(insets: EdgeInsets) -> some View {
        GlassGroup(spacing: 10) {
            VStack(spacing: 14) {
                if !isSideBySide {
                    ghostRow
                }
                timelineBlock
                transportRow(compact: false)
                speedPicker
            }
        }
        .padding(.horizontal, max(insets.leading, insets.trailing) + 16)
        .padding(.top, 10)
        .padding(.bottom, max(insets.bottom, 10))
        .background(Color.black)
    }

    private func landscapeBar(insets: EdgeInsets) -> some View {
        GlassGroup(spacing: 10) {
            VStack(spacing: 6) {
                if !isSideBySide {
                    ghostRow
                }
                timelineBlock
                HStack(spacing: 16) {
                    transportRow(compact: true)
                    speedPicker
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
                shape
                    .fill(.ultraThinMaterial)
                    .overlay(shape.fill(Color.black.opacity(0.3)))
                    .overlay(shape.strokeBorder(Theme.hairline, lineWidth: 1))
            }
        }
        .frame(maxWidth: 640)
        .padding(.leading, insets.leading + 12)
        .padding(.trailing, insets.trailing + 12)
        .padding(.bottom, max(insets.bottom, 8))
    }

    // MARK: - Control pieces

    /// [Back one frame] [Play / Pause] [Forward one frame] [Loop]
    private func transportRow(compact: Bool) -> some View {
        let side: CGFloat = compact ? 40 : 48
        let playSize: CGFloat = compact ? 52 : 60
        let loopSize: CGFloat = compact ? 40 : 44
        return HStack(spacing: compact ? 12 : 20) {
            Button {
                playback.stepFrames(-1)
            } label: {
                Image(systemName: "backward.frame.fill")
            }
            .buttonStyle(.round(size: side))
            .buttonRepeatBehavior(.enabled)
            .disabled(!playback.isReady)
            .accessibilityLabel("Back one frame")

            Button {
                playback.togglePlayPause()
            } label: {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.round(size: playSize, prominent: true))
            .disabled(!playback.isReady)
            .accessibilityLabel(playback.isPlaying ? "Pause" : "Play")

            Button {
                playback.stepFrames(1)
            } label: {
                Image(systemName: "forward.frame.fill")
            }
            .buttonStyle(.round(size: side))
            .buttonRepeatBehavior(.enabled)
            .disabled(!playback.isReady)
            .accessibilityLabel("Forward one frame")

            Button {
                playback.isLooping.toggle()
            } label: {
                Image(systemName: "repeat")
            }
            .buttonStyle(.round(size: loopSize, isOn: playback.isLooping, tint: Theme.loopColor))
            .accessibilityLabel(playback.isLooping ? "Loop on" : "Loop off")
        }
        .animation(.snappy, value: playback.isPlaying)
        .animation(.snappy, value: playback.isLooping)
        .opacity(playback.isReady ? 1 : 0.45)
    }

    private var speedPicker: some View {
        let options = SyncedPlayback.speeds.map { speed -> PillPicker<Float>.Option in
            let title = SyncedPlayback.speedLabel(Double(speed))
            return PillPicker<Float>.Option(
                value: speed,
                title: title,
                accessibilityLabel: "Speed \(title)"
            )
        }
        return PillPicker<Float>(
            options: options,
            selection: playback.rate,
            onSelect: { playback.setRate($0) }
        )
    }

    // MARK: - Timeline

    private var shownTime: Double {
        isScrubbing ? scrubTime : playback.currentTime
    }

    private var timelineBlock: some View {
        VStack(spacing: 2) {
            CompareTimelineBar(
                value: shownTime,
                lower: playback.range.lowerBound,
                upper: playback.range.upperBound,
                isDragging: isScrubbing,
                onScrub: { scrubChanged($0) },
                onScrubEnd: { scrubEnded($0) },
                onNudge: { playback.seek(to: shownTime + $0) }
            )
            timeLabels
        }
        .disabled(!playback.isReady)
        .opacity(playback.isReady ? 1 : 0.45)
    }

    private var timeLabels: some View {
        let remaining = max(playback.range.upperBound - shownTime, 0)
        return ZStack {
            HStack {
                Text(formatTime(shownTime))
                Spacer(minLength: 8)
                Text(formatTime(-remaining))
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Theme.secondaryText)
            .lineLimit(1)

            if let label = countLabel {
                Text(label)
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.accent.opacity(0.16)))
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: countLabel)
        .accessibilityElement(children: .combine)
    }

    private func scrubChanged(_ time: Double) {
        if !isScrubbing {
            // Finger down: remember if we were playing, then pause.
            wasPlayingBeforeScrub = playback.isPlaying
            isScrubbing = true
            playback.pause()
        }
        scrubTime = time
        playback.seek(to: time)   // live preview while dragging
    }

    private func scrubEnded(_ time: Double) {
        // Finger up: land exactly where the knob is.
        playback.seek(to: time)
        isScrubbing = false
        if wasPlayingBeforeScrub {
            playback.play()
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
                .accessibilityHidden(true)
            Slider(value: $ghostOpacity, in: 0.2...0.8)
                .tint(Theme.loopColor)
                .accessibilityLabel("Tutorial ghost opacity")
        }
        .padding(.horizontal, 4)
        .frame(height: 32)
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
                            .buttonStyle(CompareCapsuleButtonStyle())
                            .disabled(abs(playback.nudge) < 0.0005)
                            .opacity(abs(playback.nudge) < 0.0005 ? 0.4 : 1)

                            Button(action: onAnalyze) {
                                Label("Analyze", systemImage: "sparkles")
                            }
                            .buttonStyle(CompareCapsuleButtonStyle(prominent: true))
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
        .buttonStyle(CompareCapsuleButtonStyle())
    }
}

/// Capsule button for the sync panel: glass, or solid accent when `prominent`.
private struct CompareCapsuleButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(prominent ? Color.black : Color.white)
            .frame(maxWidth: .infinity, minHeight: Theme.controlHeight)
            .background {
                if prominent {
                    Capsule().fill(Theme.accent)
                }
            }
            .modifier(CompareCapsuleGlass(prominent: prominent))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

private struct CompareCapsuleGlass: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if prominent {
            content
        } else {
            content.glassSurface(Capsule(), interactive: true, fallback: Theme.surfaceRaised)
        }
    }
}

// MARK: - Timeline scrubber

/// A slim custom scrubber: 4 pt track, accent fill, 14 pt knob, and a 32 pt
/// tall hit area where you can tap or drag to seek. `lower...upper` is the
/// part of the tutorial that your take covers.
private struct CompareTimelineBar: View {
    let value: Double
    let lower: Double
    let upper: Double
    let isDragging: Bool
    let onScrub: (Double) -> Void
    let onScrubEnd: (Double) -> Void
    let onNudge: (Double) -> Void

    private let knobSize: CGFloat = 14
    private let trackHeight: CGFloat = 4

    private var span: Double { max(upper - lower, 0.0001) }

    var body: some View {
        GeometryReader { geo in
            let inset = knobSize / 2
            let usable = max(geo.size.width - knobSize, 1)
            let x = inset + usable * fraction(of: value)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Theme.accent)
                    .frame(width: x, height: trackHeight)

                Circle()
                    .fill(Color.white)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .scaleEffect(isDragging ? 1.35 : 1)
                    .animation(.snappy, value: isDragging)
                    .offset(x: x - inset)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        onScrub(time(atX: drag.location.x, inset: inset, usable: usable))
                    }
                    .onEnded { drag in
                        onScrubEnd(time(atX: drag.location.x, inset: inset, usable: usable))
                    }
            )
        }
        .frame(height: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Position")
        .accessibilityValue(formatTime(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onNudge(1)
            case .decrement: onNudge(-1)
            @unknown default: break
            }
        }
    }

    private func fraction(of seconds: Double) -> CGFloat {
        guard seconds.isFinite else { return 0 }
        return CGFloat(min(max((seconds - lower) / span, 0), 1))
    }

    private func time(atX x: CGFloat, inset: CGFloat, usable: CGFloat) -> Double {
        let f = min(max((x - inset) / usable, 0), 1)
        return lower + Double(f) * span
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
