import SwiftUI
import SwiftData
import AVFoundation

/// App entry point. Sets up the SwiftData database and the audio session.
@main
struct EightCountApp: App {
    init() {
        // `.playback` makes the video's sound play even when the ring/silent
        // switch is on — important in a practice room.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    var body: some Scene {
        WindowGroup {
            ProjectListView()
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        // Creates (or opens) the on-device database for all three model types.
        .modelContainer(for: [Project.self, CountNote.self, PoseSnapshot.self])
    }
}
