import SwiftUI

/// [◀ 1 frame] [ drag strip ] [1 frame ▶]
///
/// The strip works like a jog wheel: drag your finger sideways and the video
/// moves one frame for every few points of movement (right = forward), so
/// you can land on an exact frame. The tick marks move with your finger.
/// The frame buttons repeat while you hold them down.
@MainActor
struct FineScrubber: View {
    let controller: PlayerController

    /// Where the current drag started; a new value means a new drag.
    @State private var dragStart: CGPoint? = nil
    /// Finger translation already handled in this drag.
    @State private var lastTranslation: CGFloat = 0
    /// Movement not yet turned into a whole frame.
    @State private var leftover: CGFloat = 0
    /// True while a finger is on the strip (resets itself automatically).
    @GestureState private var isTouching = false

    /// Finger movement (points) needed to move one frame. Higher = finer.
    private let pointsPerFrame: CGFloat = 7
    /// Every n-th tick is drawn taller.
    private let ticksPerMajor = 5

    init(controller: PlayerController) {
        self.controller = controller
    }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                controller.stepFrames(-1)
            } label: {
                Image(systemName: "backward.frame.fill")
            }
            .buttonStyle(.big)
            .buttonRepeatBehavior(.enabled)
            .frame(width: 60)
            .accessibilityLabel("Back one frame")

            strip

            Button {
                controller.stepFrames(1)
            } label: {
                Image(systemName: "forward.frame.fill")
            }
            .buttonStyle(.big)
            .buttonRepeatBehavior(.enabled)
            .frame(width: 60)
            .accessibilityLabel("Forward one frame")
        }
    }

    // MARK: - Drag strip

    private var strip: some View {
        // Copy values into constants so the Canvas drawing code below
        // doesn't need to reach back into this view.
        let fps = controller.frameRate > 0 ? controller.frameRate : 30
        let frameIndex = controller.currentTime * fps
        let spacing = pointsPerFrame
        let perMajor = ticksPerMajor
        let majorSpacing = spacing * CGFloat(perMajor)
        // Shift the ticks with the playhead so they "follow" the finger.
        let phase = CGFloat(frameIndex * Double(spacing)).truncatingRemainder(dividingBy: majorSpacing)
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let frameText = "Frame \(Int(frameIndex.rounded()) + 1)"
        let hint: String = isTouching ? frameText : "← drag to fine-tune →"

        return ZStack(alignment: .top) {
            shape.fill(Theme.surfaceRaised)

            // Ruler-style tick marks hanging from the top edge.
            Canvas { context, size in
                var minor = Path()
                var major = Path()
                var x = phase - majorSpacing
                var i = 0
                while x <= size.width {
                    if i % perMajor == 0 {
                        major.move(to: CGPoint(x: x, y: 6))
                        major.addLine(to: CGPoint(x: x, y: 26))
                    } else {
                        minor.move(to: CGPoint(x: x, y: 6))
                        minor.addLine(to: CGPoint(x: x, y: 16))
                    }
                    x += spacing
                    i += 1
                }
                context.stroke(minor, with: .color(.white.opacity(0.25)), lineWidth: 1)
                context.stroke(major, with: .color(.white.opacity(0.55)), lineWidth: 1.5)
            }

            // The fixed "playhead" in the middle.
            Capsule()
                .fill(Theme.accent)
                .frame(width: 3, height: 30)
                .padding(.top, 2)

            // Hint / current frame number at the bottom.
            VStack {
                Spacer(minLength: 0)
                Text(hint)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(isTouching ? Theme.accent : Theme.secondaryText)
                    .lineLimit(1)
                    .padding(.bottom, 4)
            }
        }
        .clipShape(shape)
        .overlay {
            shape.stroke(isTouching ? Theme.accent : Color.clear, lineWidth: 2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Theme.tapHeight)
        .contentShape(Rectangle())
        .gesture(dragGesture)
        // VoiceOver: swipe up/down to step frames.
        .accessibilityElement()
        .accessibilityLabel("Fine scrub")
        .accessibilityValue(frameText)
        .accessibilityAdjustableAction { direction in
            if direction == .increment {
                controller.stepFrames(1)
            } else if direction == .decrement {
                controller.stepFrames(-1)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isTouching) { _, state, _ in
                state = true
            }
            .onChanged { value in
                // First event of a new drag: reset and pause playback.
                if dragStart != value.startLocation {
                    dragStart = value.startLocation
                    lastTranslation = 0
                    leftover = 0
                    controller.pause()
                }

                // Only use how far the finger moved since the last event.
                let delta = value.translation.width - lastTranslation
                lastTranslation = value.translation.width
                leftover += delta

                // Turn every `pointsPerFrame` of movement into one frame.
                let frames = Int((leftover / pointsPerFrame).rounded(.towardZero))
                if frames != 0 {
                    leftover -= CGFloat(frames) * pointsPerFrame
                    controller.stepFrames(frames)
                }
            }
            .onEnded { _ in
                dragStart = nil
                lastTranslation = 0
                leftover = 0
            }
    }
}
