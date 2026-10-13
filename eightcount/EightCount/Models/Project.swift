import Foundation
import SwiftData

/// One song or section you are learning, e.g. "Hype Boy – chorus".
@Model
final class Project {
    var id: UUID
    var title: String
    /// Free text like "chorus", "verse 2", "dance break".
    var section: String
    /// Song tempo in beats per minute. 0 means "not set yet".
    var bpm: Double
    /// Video time (seconds) where count 1 of the first 8-count starts.
    var offset: Double
    /// File name of the copied video inside `VideoStorage.directory`.
    /// We store only the name (not a full path) because the app's folder
    /// path can change when the app is reinstalled or updated.
    var videoFileName: String?
    /// The name the video had when it was imported (just for display).
    var originalVideoName: String?
    var createdAt: Date
    var updatedAt: Date

    /// Notes for each 8-count. Deleting the project deletes its notes.
    @Relationship(deleteRule: .cascade, inverse: \CountNote.project)
    var notes: [CountNote] = []

    init(title: String, section: String = "", bpm: Double = 0, offset: Double = 0) {
        self.id = UUID()
        self.title = title
        self.section = section
        self.bpm = bpm
        self.offset = offset
        self.createdAt = .now
        self.updatedAt = .now
    }

    /// Full URL of the project's video, or nil if no video is attached.
    var videoURL: URL? {
        guard let videoFileName else { return nil }
        return VideoStorage.url(forFileName: videoFileName)
    }

    /// "Title · section" for headers.
    var displayTitle: String {
        section.isEmpty ? title : "\(title) · \(section)"
    }

    /// The note for 8-count `index`, if one has been written.
    func note(for index: Int) -> CountNote? {
        notes.first { $0.countIndex == index }
    }
}
