import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Two big buttons: "From Photos" and "From Files". The chosen video is
/// copied into app storage and `onImported` is called with the new file name.
struct VideoImportButtons: View {
    /// Called on the main thread with (stored file name, original file name).
    var onImported: (_ storedFileName: String, _ originalName: String) -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var isCopying = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            // PhotosPicker runs outside the app, so it needs no Photos permission.
            PhotosPicker(selection: $photoItem, matching: .videos) {
                Label("From Photos", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.big)

            Button {
                showFileImporter = true
            } label: {
                Label("From Files", systemImage: "folder")
            }
            .buttonStyle(.big)

            if isCopying {
                ProgressView("Copying video…")
                    .padding(.top, 4)
            }
        }
        .disabled(isCopying)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await importFromPhotos(item) }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.movie]) { result in
            switch result {
            case .success(let url):
                Task { await importFromFiles(url) }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .alert("Couldn't import video", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func importFromPhotos(_ item: PhotosPickerItem) async {
        isCopying = true
        defer { isCopying = false; photoItem = nil }
        do {
            // Large videos (or ones stored in iCloud) can take a while here.
            if let movie = try await item.loadTransferable(type: PickedMovie.self) {
                onImported(movie.storedFileName, movie.originalName)
            } else {
                errorMessage = "The selected item isn't a video."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func importFromFiles(_ url: URL) async {
        isCopying = true
        defer { isCopying = false }
        do {
            // Copy off the main thread so the UI doesn't freeze on big files.
            let name = try await Task.detached(priority: .userInitiated) {
                try VideoStorage.importSecurityScopedVideo(from: url)
            }.value
            onImported(name, url.lastPathComponent)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
