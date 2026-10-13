import SwiftUI
import SwiftData

// The "AI dance check" screen (shown in a sheet on top of the compare screen)
// plus the little pieces that run the analysis in the background.
// Everything runs on the iPhone. Nothing is uploaded.

// MARK: - Running the analysis

/// Problems that can happen before any poses are compared.
enum AnalysisError: LocalizedError {
    case videoUnreadable
    case tooShort

    var errorDescription: String? {
        switch self {
        case .videoUnreadable:
            return "I couldn't read one of the videos."
        case .tooShort:
            return "This recording is too short to analyze. Record at least a few seconds of dancing."
        }
    }
}

/// Runs all the steps one after another. Everything it needs is passed in as
/// plain values (SwiftData objects must not leave the main actor).
enum DanceAnalyzer {
    struct Input: Sendable {
        var tutorialURL: URL
        var takeURL: URL
        var timing: TakeTiming
        var bpm: Double
        var offset: Double
        var projectTitle: String
        var tutorialMirrored: Bool
        var takeMirrored: Bool
    }

    /// Finds the poses, compares them and writes the tips.
    /// `progress` goes from 0 to 1: tutorial poses 0-0.45, your poses
    /// 0.45-0.9, comparing 0.9-0.95, writing tips 0.95-1.
    static func analyze(_ input: Input, progress: @escaping @Sendable (Double) -> Void) async throws -> AnalysisReport {
        let timing = input.timing
        progress(0)

        let tutorialDuration = (try? await PoseExtractor.duration(of: input.tutorialURL)) ?? 0
        let takeDuration = (try? await PoseExtractor.duration(of: input.takeURL)) ?? 0
        guard tutorialDuration > 0, takeDuration > 0 else { throw AnalysisError.videoUnreadable }
        try Task.checkCancellation()

        // The part of the tutorial that the take covers.
        let start = timing.tutorialStart
        let end = min(timing.tutorialEnd, tutorialDuration)
        let tutorialTimes = PoseExtractor.sampleTimes(from: start, to: end)
        guard tutorialTimes.count >= 10 else { throw AnalysisError.tooShort }

        // The matching part of your take, with extra room on both sides so
        // we can try small time shifts (0.6 s of tutorial time each way).
        let margin = 0.6 / timing.rate
        let takeLow = max(0, timing.takeTime(forTutorialTime: start) - margin)
        let takeHigh = min(takeDuration, timing.takeTime(forTutorialTime: end) + margin)
        let takeTimes = PoseExtractor.sampleTimes(from: takeLow, to: takeHigh)
        guard takeTimes.count >= 10 else { throw AnalysisError.tooShort }

        // 1. The tutorial dancer.
        let tutorialSamples = try await PoseExtractor.extract(from: input.tutorialURL, at: tutorialTimes) { value in
            progress(value * 0.45)
        }
        try Task.checkCancellation()
        progress(0.45)

        // 2. You.
        let takeSamples = try await PoseExtractor.extract(from: input.takeURL, at: takeTimes) { value in
            progress(0.45 + value * 0.45)
        }
        try Task.checkCancellation()
        progress(0.9)

        // 3. Compare.
        let comparison = PoseComparer.Input(
            tutorial: tutorialSamples,
            take: takeSamples,
            plannedTutorialFrames: tutorialTimes.count,
            timing: timing,
            tutorialRange: start...end,
            tutorialDuration: tutorialDuration,
            bpm: input.bpm,
            offset: input.offset,
            tutorialMirrored: input.tutorialMirrored,
            takeMirrored: input.takeMirrored
        )
        var report = try PoseComparer.compare(comparison)
        try Task.checkCancellation()
        progress(0.95)

        // 4. Friendly tips.
        let coach = await CoachWriter.write(report: report, projectTitle: input.projectTitle)
        try Task.checkCancellation()
        report.coachText = coach.text
        report.coachSource = coach.source
        progress(1)
        return report
    }
}

/// Owns the background task, so "Cancel" and leaving the sheet stop it.
@MainActor
final class AnalysisRunner: ObservableObject {
    enum State {
        case idle
        case running
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    /// 0...1 over all steps.
    @Published private(set) var progress: Double = 0

    private var worker: Task<AnalysisReport, Error>?
    private var waiter: Task<Void, Never>?
    /// Identifies the current run, so a stopped run cannot change the screen later.
    private var runID: UUID?

    /// Starts an analysis. `onFinished` is called on the main actor with the result.
    func start(input: DanceAnalyzer.Input, onFinished: @escaping @MainActor (AnalysisReport) -> Void) {
        cancelTasks()
        let id = UUID()
        runID = id
        state = .running
        progress = 0

        // Called from the background; hops to the main actor to update the UI.
        let reportProgress: @Sendable (Double) -> Void = { [weak self] value in
            Task { @MainActor in
                self?.updateProgress(value, run: id)
            }
        }

        // The heavy work runs off the main actor, with plain values only.
        let work = Task.detached(priority: .userInitiated) {
            try await DanceAnalyzer.analyze(input, progress: reportProgress)
        }
        worker = work

        waiter = Task { [weak self] in
            do {
                let result = try await work.value
                try Task.checkCancellation()
                guard let self, self.runID == id else { return }
                onFinished(result)
                self.finishRun()
            } catch {
                guard let self, self.runID == id, !Task.isCancelled else { return }
                self.worker = nil
                self.waiter = nil
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    /// Stops the analysis (if one is running) and goes back to the start.
    func cancel() {
        cancelTasks()
        if case .running = state { state = .idle }
        progress = 0
    }

    /// Shows an error without running anything.
    func fail(_ message: String) {
        cancelTasks()
        state = .failed(message)
    }

    private func cancelTasks() {
        runID = nil
        worker?.cancel()
        waiter?.cancel()
        worker = nil
        waiter = nil
    }

    private func finishRun() {
        worker = nil
        waiter = nil
        runID = nil
        state = .idle
    }

    private func updateProgress(_ value: Double, run id: UUID) {
        guard runID == id, case .running = state else { return }
        let clamped = max(0, min(1, value))
        // Don't redraw for tiny steps.
        if clamped - progress >= 0.005 { progress = clamped }
    }
}

// MARK: - The screen

@MainActor
struct AnalysisView: View {
    let project: Project
    let take: Take
    let tutorialMirrored: Bool
    let takeMirrored: Bool
    /// Called with a TUTORIAL time (seconds) the compare screen should seek to.
    let onJump: (Double) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var runner = AnalysisRunner()
    @State private var report: AnalysisReport?

    init(project: Project, take: Take, tutorialMirrored: Bool, takeMirrored: Bool, onJump: @escaping (Double) -> Void) {
        self.project = project
        self.take = take
        self.tutorialMirrored = tutorialMirrored
        self.takeMirrored = takeMirrored
        self.onJump = onJump
        // Show a saved result right away.
        _report = State(initialValue: take.analysisReport)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    content
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .preferredColorScheme(.dark)
        // Leaving the sheet stops a running analysis.
        .onDisappear { runner.cancel() }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Label("AI dance check", systemImage: "sparkles")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text(project.displayTitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 8)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: Theme.tapHeight, height: Theme.tapHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    @ViewBuilder private var content: some View {
        switch runner.state {
        case .running:
            runningSection
        case .failed(let message):
            errorSection(message)
        case .idle:
            if let report {
                resultsSection(report)
            } else {
                introSection
            }
        }
    }

    // Not analyzed yet.
    private var introSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("How close are you to the tutorial?")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Text("I look for the body in the tutorial and in your recording, then compare your joint angles and timing. You get a score, plus the things to work on first.")
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Works best when your whole body is in the video, the room is bright and only you are in the frame.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .analysisCard()

            Label("Runs entirely on your iPhone. Nothing is uploaded.", systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)

            Button {
                startAnalysis()
            } label: {
                Label("Analyze my dancing", systemImage: "sparkles")
            }
            .buttonStyle(.big(isOn: true))
        }
    }

    // Working.
    private var runningSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ProgressView(value: max(0, min(1, runner.progress)))
                .tint(Theme.accent)
            Text(phaseText)
                .font(.system(.title3, design: .rounded).weight(.semibold))
            Text("\(Int((runner.progress * 100).rounded()))%  ·  This can take a minute. Keep this screen open.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            Button {
                runner.cancel()
            } label: {
                Label("Cancel", systemImage: "xmark")
            }
            .buttonStyle(.big)
        }
        .analysisCard()
    }

    private var phaseText: String {
        let p = runner.progress
        if p < 0.45 { return "Finding the tutorial dancer…" }
        if p < 0.9 { return "Finding you…" }
        if p < 0.95 { return "Comparing poses…" }
        return "Writing tips…"
    }

    // Something went wrong.
    private func errorSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("That didn't work", systemImage: "exclamationmark.triangle.fill")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.orange)
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                startAnalysis()
            } label: {
                Label("Try again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.big(isOn: true))
        }
        .analysisCard()
    }

    // The result.
    private func resultsSection(_ report: AnalysisReport) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if report.tutorialMirrored != tutorialMirrored || report.takeMirrored != takeMirrored {
                Label("Mirror settings changed — analyze again for accurate results",
                      systemImage: "arrow.left.and.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
                    .analysisCard()
            }

            scoreHeader(report)

            if !report.coachText.isEmpty {
                coachCard(report)
            }
            if !report.topFindings.isEmpty {
                findingsSection(report)
            }
            if !report.segments.isEmpty {
                segmentsSection(report)
            }

            Button {
                startAnalysis()
            } label: {
                Label("Analyze again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.big)

            Text("Body tracking compares joint angles and timing. It can't judge style, facial expression or energy — trust your eyes too.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func scoreHeader(_ report: AnalysisReport) -> some View {
        VStack(spacing: 12) {
            ScoreRing(score: report.overallScore)
            Text(report.timingHeadline)
                .font(.system(.headline, design: .rounded))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("Your body was found in \(Int((report.poseCoverage * 100).rounded()))% of the frames.")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func coachCard(_ report: AnalysisReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your coach says")
                .font(.system(.title3, design: .rounded).weight(.bold))
            ForEach(coachLines(from: report.coachText)) { line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if line.isBullet {
                        Text("•").foregroundStyle(Theme.accent)
                    }
                    Text(styled(line.text))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(report.coachSource == CoachWriter.appleIntelligenceSource ? "Tips by Apple Intelligence" : "Built-in tips")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .analysisCard()
    }

    private func findingsSection(_ report: AnalysisReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Work on these first")
                .font(.system(.title3, design: .rounded).weight(.bold))
            ForEach(report.topFindings) { finding in
                Button {
                    onJump(finding.time)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(finding.bodyPart)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Theme.accent)
                            Text(finding.message)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(finding.whereText)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: Theme.tapHeight, alignment: .leading)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func segmentsSection(_ report: AnalysisReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(report.segments.first?.isEightCount == true ? "By 8-count" : "By section")
                .font(.system(.title3, design: .rounded).weight(.bold))
            ForEach(report.segments) { segment in
                Button {
                    onJump(segment.start)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(segment.label)
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(segment.score)")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(ScoreRing.color(for: segment.score))
                        }
                        ScoreBar(score: segment.score)
                        if let first = segment.findings.first {
                            Text(first.message)
                                .font(.footnote)
                                .foregroundStyle(Theme.secondaryText)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: Theme.tapHeight, alignment: .leading)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Actions

    /// Reads everything needed from the SwiftData objects (main actor), then
    /// starts the background work with plain values only.
    private func startAnalysis() {
        guard let tutorialURL = project.videoURL else {
            runner.fail("This project has no tutorial video.")
            return
        }
        let takeURL = take.videoURL
        guard FileManager.default.fileExists(atPath: takeURL.path) else {
            runner.fail("The recording could not be found on this iPhone.")
            return
        }
        let input = DanceAnalyzer.Input(
            tutorialURL: tutorialURL,
            takeURL: takeURL,
            timing: take.timing,
            bpm: project.bpm,
            offset: project.offset,
            projectTitle: project.displayTitle,
            tutorialMirrored: tutorialMirrored,
            takeMirrored: takeMirrored
        )
        let currentTake = take
        let context = modelContext
        runner.start(input: input) { newReport in
            currentTake.analysisReport = newReport
            try? context.save()
            report = newReport
        }
    }
}

// MARK: - Small views

/// Big circular score with a colored ring.
@MainActor
private struct ScoreRing: View {
    let score: Int

    /// Red below 50, orange below 75, green from 75.
    static func color(for score: Int) -> Color {
        if score < 50 { return .red }
        if score < 75 { return .orange }
        return .green
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceRaised, lineWidth: 14)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(100, score))) / 100)
                .stroke(Self.color(for: score), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                Text("out of 100")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(width: 160, height: 160)
        .padding(.top, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score) out of 100")
    }
}

/// A thin colored bar showing a 0-100 score.
@MainActor
private struct ScoreBar: View {
    let score: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceRaised)
                Capsule()
                    .fill(ScoreRing.color(for: score))
                    .frame(width: geometry.size.width * CGFloat(max(0, min(100, score))) / 100)
            }
        }
        .frame(height: 8)
    }
}

private extension View {
    /// Dark rounded card used for the sections.
    func analysisCard() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
    }
}

// MARK: - Coach text helpers

/// One line of the coach text.
private struct CoachLine: Identifiable {
    let id: Int
    let text: String
    let isBullet: Bool
}

/// Splits the coach text into lines and removes bullet markers
/// ("- ", "* ", "• ", "1. ") so we can draw our own bullets.
private func coachLines(from text: String) -> [CoachLine] {
    var result: [CoachLine] = []
    for raw in text.split(whereSeparator: { $0.isNewline }) {
        var line = raw.trimmingCharacters(in: .whitespaces)
        if line.isEmpty { continue }
        var isBullet = false
        for marker in ["- ", "* ", "• ", "– ", "— "] where line.hasPrefix(marker) {
            line = String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
            isBullet = true
            break
        }
        if let range = line.range(of: "^[0-9]+[.)] +", options: .regularExpression) {
            line.removeSubrange(range)
            isBullet = true
        }
        if line.isEmpty { continue }
        result.append(CoachLine(id: result.count, text: line, isBullet: isBullet))
    }
    return result
}

/// Shows **bold** and *italic* from the model's text; plain text if it fails.
private func styled(_ text: String) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
}
