import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Home screen: all projects, newest first. Create, rename, delete, import.
struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]

    @State private var path: [Project] = []
    @State private var showNewProject = false
    @State private var showImporter = false
    @State private var projectToDelete: Project?
    @State private var projectToRename: Project?
    @State private var renameTitle = ""
    @State private var renameSection = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if projects.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("EightCount")
            .navigationDestination(for: Project.self) { project in
                ProjectDetailView(project: project)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import notes", systemImage: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewProject = true
                    } label: {
                        Label("New project", systemImage: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
        }
        .sheet(isPresented: $showNewProject) {
            NewProjectSheet { project in
                path.append(project)   // open the new project right away
            }
        }
        // Import a project file that was exported from this app.
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                do {
                    let project = try ProjectArchive.importProject(from: url, into: modelContext)
                    path.append(project)
                } catch {
                    errorMessage = error.localizedDescription
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        // Always confirm before deleting.
        .confirmationDialog(
            "Delete \"\(projectToDelete?.displayTitle ?? "")\"?",
            isPresented: Binding(
                get: { projectToDelete != nil },
                set: { if !$0 { projectToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: projectToDelete
        ) { project in
            Button("Delete Project", role: .destructive) { delete(project) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This deletes the project, its notes, its snapshots and its copy of the video. This can't be undone.")
        }
        .alert("Rename Project", isPresented: Binding(
            get: { projectToRename != nil },
            set: { if !$0 { projectToRename = nil } }
        )) {
            TextField("Title", text: $renameTitle)
            TextField("Section", text: $renameSection)
            Button("Save") { saveRename() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Subviews

    private var list: some View {
        List {
            ForEach(projects) { project in
                NavigationLink(value: project) {
                    ProjectRow(project: project)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        projectToDelete = project
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        startRename(project)
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.gray)
                }
                .contextMenu {
                    Button {
                        startRename(project)
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        projectToDelete = project
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            ContentUnavailableView(
                "No projects yet",
                systemImage: "figure.dance",
                description: Text("Create a project for each song or section you're learning.")
            )
            Button {
                showNewProject = true
            } label: {
                Label("New Project", systemImage: "plus")
            }
            .buttonStyle(.big(isOn: true))
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Actions

    private func startRename(_ project: Project) {
        renameTitle = project.title
        renameSection = project.section
        projectToRename = project
    }

    private func saveRename() {
        guard let project = projectToRename else { return }
        let title = renameTitle.trimmingCharacters(in: .whitespaces)
        if !title.isEmpty { project.title = title }
        project.section = renameSection.trimmingCharacters(in: .whitespaces)
        project.updatedAt = .now
        try? modelContext.save()
        projectToRename = nil
    }

    private func delete(_ project: Project) {
        path.removeAll { $0.id == project.id }
        VideoStorage.deleteVideo(named: project.videoFileName)
        modelContext.delete(project)   // notes and snapshots are deleted too (cascade)
        try? modelContext.save()
        projectToDelete = nil
    }
}

/// One row in the project list.
private struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: project.videoFileName == nil ? "video.slash" : "play.rectangle.fill")
                .font(.title2)
                .foregroundStyle(project.videoFileName == nil ? Theme.secondaryText : Theme.accent)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.headline)
                HStack(spacing: 8) {
                    if !project.section.isEmpty {
                        Text(project.section)
                    }
                    if project.bpm > 0 {
                        Text("\(Int(project.bpm.rounded())) BPM")
                    }
                    let noteCount = project.notes.filter { !$0.isEmpty }.count
                    if noteCount > 0 {
                        Text("\(noteCount) notes")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.vertical, 8)
    }
}
