# EightCount (iOS dance-practice app) — progress

App lives in `eightcount/`. Generate the Xcode project with `xcodegen generate` in that folder
(full instructions in `eightcount/README.md`).

## Done (everything in "Scope for this session")
- [x] Project skeleton: `eightcount/project.yml` (XcodeGen), Info.plist, asset catalog + app icon
- [x] SwiftData models: Project, CountNote, PoseSnapshot
- [x] Video import from Photos (PhotosPicker) and Files (fileImporter), copied into Application Support/Videos
- [x] Projects: list, create, rename, delete (with confirmation), add/replace video
- [x] Playback: mirror, 0.25/0.5/0.75/1x with pitch correction, A-B loop, slider + fine-scrub strip + frame steps, screen stays awake while playing
- [x] 8-count grid: BPM entry + tap tempo (speed-corrected), count-1 offset, jump to 8-count, loop one 8-count
- [x] Notes per 8-count (text, feet, arms, facing, lyric cue) + pose snapshots (AVAssetImageGenerator)
- [x] Export/import of notes + snapshots as `.eightcount.json` via share sheet / file importer
- [x] Independent review pass of the whole codebase; fixes applied
- [x] README: setup on Mac, free vs paid account, permissions, Check on Mac, Decisions, Next steps

## Session 2 scope (done)
User asked for (subagents must use model "sonnet" to save tokens):
1. Record yourself (front camera, no mic) while the tutorial plays; live side-by-side or ghost overlay.
2. Compare screen: landscape = you LEFT / tutorial RIGHT, portrait = you TOP / tutorial BOTTOM; synced, audio from tutorial.
3. On-device AI analysis (Vision body pose + Apple Foundation Models tips; user has iPhone 15 Pro+).
4. Liquid Glass (iOS 26+ APIs, guarded so iOS 17 still works).

- [x] Foundation (me): Take model, AnalysisReport, TakeTiming, TakeStore, OrientationLock, Glass styling, Info.plist camera key
- [x] Recording (sonnet agent): Recording/ (CameraRecorder, CameraPreviewView, RecordView)
- [x] Compare (sonnet agent): Compare/ (SyncedPlayback, CompareView, TakesListView)
- [x] Analysis (sonnet agent): Analysis/ (PoseExtractor, PoseComparer, CoachWriter, AnalysisView)
- [x] Integration in ProjectDetailView (record button, My Takes, compare cover)
- [x] Review (sonnet agent) + README update (features, permissions, decisions, Check on Mac D)

## Session 3 (in progress): get it building with Xcode 27
- The cloud session can't reach the user's Mac. Instead: GitHub Actions compile check
  `.github/workflows/eightcount-ios-build.yml` (runners `xcode-27` [preview] and `macos-26`),
  unsigned `xcodebuild build -destination generic/platform=iOS`. Fix errors until green.
- Added `eightcount/setup-mac.sh` (one-command local setup) and `eightcount/.gitignore`.
- Fixed README: decision bullets had been pasted into the feature list.

## Next step
- Watch the "EightCount iOS build" run; fix every compile error; re-push until both jobs are green.
- On the Mac: `cd eightcount && xcodegen generate && open EightCount.xcodeproj`, build, and fix any
  first-build errors (see README → "Check on Mac").
- Then test record → compare → analyze on the iPhone (README → Check on Mac, section D).
- Then the nice-to-haves in README → "Next steps".

## Open problems
- The code has never been compiled (written on Linux; no Swift toolchain could be downloaded here).
  Expect a few small compile errors on the first Xcode build.
