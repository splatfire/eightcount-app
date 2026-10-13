# EightCount (iOS dance-practice app) — progress

App lives in `eightcount/`. Generate the Xcode project with `xcodegen generate` in that folder.

## Done
- [x] Project skeleton: `eightcount/project.yml`, Info.plist, asset catalog + app icon
- [x] SwiftData models: Project, CountNote, PoseSnapshot
- [x] VideoStorage (copies videos into Application Support/Videos), PickedMovie (PhotosPicker file transfer)
- [x] VideoImportButtons (Photos + Files), NewProjectSheet, ProjectListView (create / rename / delete with confirmation)
- [x] CountGrid math (BPM + offset -> 8-counts), Theme / BigButtonStyle

## In progress
- Playback (PlayerController, video view, controls, fine scrubber) — subagent
- 8-count grid UI (tempo sheet + tap tempo, count list, note editor, FrameGrabber) — subagent
- Export/import (ProjectArchive, ShareSheet) — subagent
  NOTE: ProjectListView already calls `ProjectArchive.importProject(from:into:)`, so the
  project does not compile until Transfer/ProjectArchive.swift exists.

## Next step
- Wait for / finish the three parts above, then write the real `Views/ProjectDetailView.swift`
  that wires them together (video top, controls, scrollable 8-count list).
- Then README.md (eightcount/README.md), then one independent review pass.

## Open problems
- Nothing can be compiled here (Linux). Everything must be checked in Xcode on the Mac.
