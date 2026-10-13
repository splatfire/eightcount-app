# EightCount (iOS dance-practice app) — progress

App lives in `eightcount/`. Generate the Xcode project with `xcodegen generate` in that folder.

## Done
- [x] Project skeleton: `eightcount/project.yml`, Info.plist, asset catalog + app icon
- [x] SwiftData models: Project, CountNote, PoseSnapshot
- [x] VideoStorage (copies videos into Application Support/Videos), PickedMovie (PhotosPicker file transfer)
- [x] VideoImportButtons (Photos + Files), NewProjectSheet, ProjectListView (create / rename / delete with confirmation)
- [x] CountGrid math (BPM + offset -> 8-counts), Theme / BigButtonStyle

- [x] Views/ProjectDetailView.swift written against the agreed APIs (needs re-check once parts land)
- [x] README draft (eightcount/README.md) — "Check on Mac" and "Decisions" placeholders still to fill
- [x] Root README links to the app

## Done (parallel parts)
- [x] Playback DONE (Playback/PlayerController, VideoSurface, PlaybackControlsView, FineScrubber)
- [x] 8-count grid DONE (TempoTapper, TempoSetupSheet, CountListView, CountRowView, NoteEditorSheet, NoteStore, SnapshotViewer, FrameGrabber)
- [x] Export/import DONE (Transfer/ProjectArchive.swift, ShareSheet, ExportProjectButton)

## Next step
- Independent review pass of the whole codebase (subagent) for API mistakes / compile errors; apply fixes.
- Fill README placeholders <!-- CHECK_ON_MAC --> and <!-- DECISIONS -->, then one independent review pass.

## Open problems
- Nothing can be compiled here (Linux). Everything must be checked in Xcode on the Mac.
