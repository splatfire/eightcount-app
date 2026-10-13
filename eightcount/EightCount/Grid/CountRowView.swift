import SwiftUI
import SwiftData

/// One 8-count in the list: number, start time, notes preview, little
/// detail chips, snapshot thumbnails, plus Loop and Edit buttons.
@MainActor
struct CountRowView: View {
    /// 0-based index (shown as index + 1).
    let index: Int
    /// Video time (seconds) where this 8-count starts.
    let startTime: Double
    /// The note for this 8-count, if one exists.
    let note: CountNote?
    /// True while the video is playing inside this 8-count.
    let isCurrent: Bool
    /// True while this 8-count is being looped.
    let isLooped: Bool
    let onJump: () -> Void
    let onToggleLoop: () -> Void
    let onEdit: () -> Void

    /// How many thumbnails fit in the row before we show "+n".
    private static let maxThumbnails = 4

    init(index: Int, startTime: Double, note: CountNote?, isCurrent: Bool, isLooped: Bool,
         onJump: @escaping () -> Void,
         onToggleLoop: @escaping () -> Void,
         onEdit: @escaping () -> Void) {
        self.index = index
        self.startTime = startTime
        self.note = note
        self.isCurrent = isCurrent
        self.isLooped = isLooped
        self.onJump = onJump
        self.onToggleLoop = onToggleLoop
        self.onEdit = onEdit
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // The whole left part is one big button: tap = jump here.
            Button(action: onJump) {
                HStack(alignment: .top, spacing: 12) {
                    numberColumn
                    details
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Jumps the video to this 8-count")

            // Separate buttons, so they never trigger the jump.
            VStack(spacing: 8) {
                loopButton
                editButton
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isCurrent ? Theme.highlight : Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isCurrent)
        .animation(.easeInOut(duration: 0.2), value: isLooped)
    }

    private var borderColor: Color {
        if isCurrent { return Theme.accent }
        if isLooped { return Theme.loopColor.opacity(0.7) }
        return Color.clear
    }

    // MARK: - Left side

    private var numberColumn: some View {
        VStack(spacing: 2) {
            Text("\(index + 1)")
                .font(.system(size: 34, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(isCurrent ? Theme.accent : Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(formatTime(startTime))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 64)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("8-count \(index + 1), starts at \(formatTime(startTime))")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            let mainText = (note?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if mainText.isEmpty {
                Text("Tap ✎ to add notes")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                Text(mainText)
                    .font(.body)
                    .foregroundStyle(Color.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            let chips = makeChips()
            if !chips.isEmpty {
                ChipFlowLayout(spacing: 6) {
                    ForEach(chips) { chip in
                        chipView(chip)
                    }
                }
            }

            if let note, !note.snapshots.isEmpty {
                thumbnailStrip(note.sortedSnapshots)
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chips (feet / arms / facing / lyric)

    private struct Chip: Identifiable {
        let id: String
        let icon: String
        let text: String
        var isLyric = false
    }

    private func makeChips() -> [Chip] {
        guard let note else { return [] }
        func clean(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
        var chips: [Chip] = []
        let feet = clean(note.feet)
        let arms = clean(note.arms)
        let facing = clean(note.facing)
        let lyric = clean(note.lyric)
        if !feet.isEmpty { chips.append(Chip(id: "feet", icon: "shoeprints.fill", text: feet)) }
        if !arms.isEmpty { chips.append(Chip(id: "arms", icon: "figure.arms.open", text: arms)) }
        if !facing.isEmpty { chips.append(Chip(id: "facing", icon: "location.north.line.fill", text: facing)) }
        if !lyric.isEmpty { chips.append(Chip(id: "lyric", icon: "music.note", text: "“\(lyric)”", isLyric: true)) }
        return chips
    }

    private func chipView(_ chip: Chip) -> some View {
        HStack(spacing: 4) {
            Image(systemName: chip.icon)
                .font(.caption2)
            Text(chip.text)
                .font(.caption)
                .italic(chip.isLyric)
                .lineLimit(1)
        }
        .foregroundStyle(chip.isLyric ? Theme.loopColor : Color.white.opacity(0.9))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Theme.surfaceRaised))
    }

    // MARK: - Snapshot thumbnails

    private func thumbnailStrip(_ snapshots: [PoseSnapshot]) -> some View {
        let shown = Array(snapshots.prefix(Self.maxThumbnails))
        let extra = snapshots.count - shown.count
        return HStack(spacing: 6) {
            ForEach(shown) { snapshot in
                SnapshotThumbnailView(snapshot: snapshot, width: 44, height: 56)
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 44, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.surfaceRaised)
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(snapshots.count) snapshot\(snapshots.count == 1 ? "" : "s")")
    }

    // MARK: - Right side buttons

    private var loopButton: some View {
        Button(action: onToggleLoop) {
            Image(systemName: "repeat")
                .font(.title3.weight(.semibold))
                .foregroundStyle(isLooped ? Color.black : Color.white)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isLooped ? Theme.loopColor : Theme.surfaceRaised)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(loopButtonLabel)
    }

    private var loopButtonLabel: String {
        isLooped ? "Stop looping 8-count \(index + 1)" : "Loop 8-count \(index + 1)"
    }

    private var editButton: some View {
        Button(action: onEdit) {
            Image(systemName: "pencil")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.white)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.surfaceRaised)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit notes for 8-count \(index + 1)")
    }
}

/// Lays chips out left to right and wraps to a new line when full.
private struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = fittedSize(of: subview, maxWidth: maxWidth)
            if x > 0 && x + size.width > maxWidth {
                // Next line.
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width
            widest = max(widest, x)
            x += spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = fittedSize(of: subview, maxWidth: bounds.width)
            if x > 0 && x + size.width > bounds.width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    /// The chip's natural size, but never wider than the row.
    private func fittedSize(of subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        guard ideal.width > maxWidth, maxWidth.isFinite else { return ideal }
        return subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
    }
}
