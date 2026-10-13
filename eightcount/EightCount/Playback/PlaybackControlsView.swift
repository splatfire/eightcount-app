import SwiftUI
import UIKit

/// All playback controls in a compact stack (about 290 pt tall):
///
///  1. timeline slider + "0:12.34 / 3:05.00" + current 8-count label
///  2. fine scrubber: [◀ frame] [drag strip] [frame ▶]
///  3. [-2s] [ Play / Pause ] [+2s] [snapshot]
///  4. speeds 0.25× 0.5× 0.75× 1× + mirror
///  5. [Set A] [Set B] [Loop] [Clear]
@MainActor
struct PlaybackControlsView: View {
    let controller: PlayerController
    /// e.g. "8-count 5 · 3". Hidden when nil.
    let countLabel: String?
    /// Shows a camera button when set.
    let onSnapshot: (() -> Void)?

    /// While the slider thumb is being dragged we show this value instead of
    /// `controller.currentTime`, so time updates don't fight your finger.
    @State private var isScrubbing = false
    @State private var scrubTime: Double = 0
    @State private var wasPlayingBeforeScrub = false

    init(controller: PlayerController, countLabel: String?, onSnapshot: (() -> Void)?) {
        self.controller = controller
        self.countLabel = countLabel
        self.onSnapshot = onSnapshot
    }

    var body: some View {
        VStack(spacing: 6) {
            timelineRow
            FineScrubber(controller: controller)
            transportRow
            speedRow
            loopRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .disabled(!controller.isReady)
    }

    // MARK: - Row 1: timeline

    /// Slider needs a non-empty range, even before a video is loaded.
    private var sliderUpperBound: Double {
        max(controller.duration, 0.01)
    }

    private var shownTime: Double {
        isScrubbing ? scrubTime : controller.currentTime
    }

    private var timelineRow: some View {
        VStack(spacing: 0) {
            Slider(
                value: Binding(
                    get: { min(shownTime, sliderUpperBound) },
                    set: { newValue in
                        scrubTime = newValue
                        controller.seek(to: newValue)   // live preview while dragging
                    }
                ),
                in: 0...sliderUpperBound,
                onEditingChanged: { editing in
                    if editing {
                        // Finger down: remember play state and pause.
                        scrubTime = controller.currentTime
                        wasPlayingBeforeScrub = controller.isPlaying
                        isScrubbing = true
                        controller.pause()
                    } else {
                        // Finger up: land exactly where the thumb is.
                        controller.seek(to: scrubTime)
                        isScrubbing = false
                        if wasPlayingBeforeScrub {
                            controller.play()
                        }
                    }
                }
            )
            .tint(Theme.accent)
            .accessibilityLabel("Video position")
            .accessibilityValue(formatTime(shownTime))

            HStack(alignment: .firstTextBaseline) {
                Text("\(formatTime(shownTime)) / \(formatTime(controller.duration))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let countLabel = countLabel {
                    Text(countLabel)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Row 3: transport

    private var transportRow: some View {
        HStack(spacing: 8) {
            Button {
                controller.skip(by: -2)
            } label: {
                skipLabel(systemImage: "gobackward", text: "2s")
            }
            .buttonStyle(.big)
            .frame(width: 66)
            .accessibilityLabel("Back 2 seconds")

            Button {
                controller.togglePlayPause()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .buttonStyle(.big(isOn: true))
            .accessibilityLabel(controller.isPlaying ? "Pause" : "Play")

            Button {
                controller.skip(by: 2)
            } label: {
                skipLabel(systemImage: "goforward", text: "2s")
            }
            .buttonStyle(.big)
            .frame(width: 66)
            .accessibilityLabel("Forward 2 seconds")

            if let onSnapshot = onSnapshot {
                Button {
                    onSnapshot()
                } label: {
                    Image(systemName: "camera.fill")
                }
                .buttonStyle(.big)
                .frame(width: 60)
                .accessibilityLabel("Take snapshot")
            }
        }
    }

    private func skipLabel(systemImage: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
            Text(text)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
        }
    }

    // MARK: - Row 4: speed + mirror

    private var speedRow: some View {
        HStack(spacing: 6) {
            ForEach(PlayerController.speeds, id: \.self) { speed in
                Button(speedText(speed)) {
                    controller.setRate(speed)
                }
                .buttonStyle(.big(isOn: controller.rate == speed))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityLabel("Speed \(speedText(speed))")
            }

            Button {
                controller.isMirrored.toggle()
            } label: {
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
            }
            .buttonStyle(.big(isOn: controller.isMirrored))
            .accessibilityLabel(controller.isMirrored ? "Mirror on" : "Mirror off")
        }
    }

    /// 0.25 → "0.25×", 1.0 → "1×".
    private func speedText(_ speed: Float) -> String {
        let value = Double(speed)
        if value == value.rounded() {
            return "\(Int(value))×"
        }
        return "\(value)×"
    }

    // MARK: - Row 5: A-B loop

    private var hasBothLoopPoints: Bool {
        controller.loopStart != nil && controller.loopEnd != nil
    }

    private var loopTitle: String {
        if let index = controller.loopedEightCount {
            return "8-count \(index + 1)"
        }
        return controller.isLooping ? "Loop on" : "Loop"
    }

    private var loopRow: some View {
        HStack(spacing: 6) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                controller.setA()
            } label: {
                loopPointLabel(name: "A", time: controller.loopStart)
            }
            .buttonStyle(.big)
            .accessibilityLabel("Set loop start A")

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                controller.setB()
            } label: {
                loopPointLabel(name: "B", time: controller.loopEnd)
            }
            .buttonStyle(.big)
            .accessibilityLabel("Set loop end B")

            Button {
                controller.toggleLoop()
            } label: {
                VStack(spacing: 1) {
                    Image(systemName: "repeat")
                    Text(loopTitle)
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .buttonStyle(.big(isOn: controller.isLooping, tint: Theme.loopColor))
            .disabled(!hasBothLoopPoints)
            .opacity(hasBothLoopPoints ? 1 : 0.4)
            .accessibilityLabel(controller.isLooping ? "Loop on" : "Loop off")

            Button {
                controller.clearLoop()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.big)
            .frame(width: 56)
            .disabled(controller.loopStart == nil && controller.loopEnd == nil)
            .accessibilityLabel("Clear loop")
        }
    }

    /// "Set A" before it's set; afterwards "A" with the time underneath.
    private func loopPointLabel(name: String, time: Double?) -> some View {
        VStack(spacing: 1) {
            Text(time == nil ? "Set \(name)" : name)
                .lineLimit(1)
            if let time = time {
                Text(formatTime(time))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.loopColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}
