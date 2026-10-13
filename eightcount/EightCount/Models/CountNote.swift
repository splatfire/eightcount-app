import Foundation
import SwiftData

/// Notes for one 8-count. Created lazily the first time you write something
/// or take a snapshot for that 8-count.
@Model
final class CountNote {
    /// 0-based number of the 8-count (0 = first 8-count, shown as "1").
    /// Notes are tied to this number, not to a video time, so if you change
    /// the BPM or start offset the notes stay with "8-count #n".
    var countIndex: Int
    var text: String
    var feet: String
    var arms: String
    var facing: String
    /// The lyric you hear at the start of this 8-count.
    var lyric: String
    var updatedAt: Date

    var project: Project?

    /// Pose pictures for this 8-count. Deleted together with the note.
    @Relationship(deleteRule: .cascade, inverse: \PoseSnapshot.note)
    var snapshots: [PoseSnapshot] = []

    init(countIndex: Int, text: String = "", feet: String = "", arms: String = "",
         facing: String = "", lyric: String = "") {
        self.countIndex = countIndex
        self.text = text
        self.feet = feet
        self.arms = arms
        self.facing = facing
        self.lyric = lyric
        self.updatedAt = .now
    }

    /// Snapshots in the order they appear in the video.
    var sortedSnapshots: [PoseSnapshot] {
        snapshots.sorted { $0.time < $1.time }
    }

    /// True when nothing has been written and there are no snapshots.
    var isEmpty: Bool {
        [text, feet, arms, facing, lyric].allSatisfy {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } && snapshots.isEmpty
    }
}
