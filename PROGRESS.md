STATUS: DONE

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

## In progress
- Nothing.

## Next step
- On the Mac: `cd eightcount && xcodegen generate && open EightCount.xcodeproj`, build, and fix any
  first-build errors (see README → "Check on Mac").
- Then the nice-to-haves in README → "Next steps".

## Open problems
- The code has never been compiled (written on Linux; no Swift toolchain could be downloaded here).
  Expect a few small compile errors on the first Xcode build.
