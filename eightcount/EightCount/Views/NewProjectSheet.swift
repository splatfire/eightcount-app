import SwiftUI
import SwiftData

/// Sheet for creating a project: title, section and (optionally) a video.
struct NewProjectSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Called with the new project so the list can open it.
    var onCreated: (Project) -> Void = { _ in }

    @State private var title = ""
    @State private var section = ""
    @State private var videoFileName: String?
    @State private var originalVideoName: String?
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Song") {
                    TextField("Title (e.g. Hype Boy)", text: $title)
                        .focused($titleFocused)
                        .font(.title3)
                    TextField("Section (e.g. chorus)", text: $section)
                        .font(.title3)
                }

                Section {
                    if let originalVideoName {
                        Label(originalVideoName, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    VideoImportButtons { stored, original in
                        // Picking a second video replaces the first one.
                        VideoStorage.deleteVideo(named: videoFileName)
                        videoFileName = stored
                        originalVideoName = original
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("Video")
                } footer: {
                    Text("The video is copied into the app, so it stays even if you delete it from Photos. You can also add it later.")
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Don't leave an orphaned video copy behind.
                        VideoStorage.deleteVideo(named: videoFileName)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .bold()
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { titleFocused = true }
        }
        .interactiveDismissDisabled(videoFileName != nil)
    }

    private func create() {
        let project = Project(
            title: title.trimmingCharacters(in: .whitespaces),
            section: section.trimmingCharacters(in: .whitespaces)
        )
        project.videoFileName = videoFileName
        project.originalVideoName = originalVideoName
        modelContext.insert(project)
        try? modelContext.save()
        dismiss()
        onCreated(project)
    }
}
