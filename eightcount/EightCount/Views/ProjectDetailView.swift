import SwiftUI
import SwiftData

/// Placeholder — replaced once playback, grid and export pieces exist.
struct ProjectDetailView: View {
    @Bindable var project: Project

    var body: some View {
        Text(project.displayTitle)
            .navigationTitle(project.title)
    }
}
