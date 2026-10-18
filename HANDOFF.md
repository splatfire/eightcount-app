# Where we left off

_Last updated: 18 October 2026 · by Cursor (cloud session)_

## State right now

- **Moved to its own repo:** github.com/splatfire/eightcount-app (branch
  `main`). On the Mac the new folder is `~/eightcount-app` (the old
  `~/splatfire` is no longer used for the app).

- **Code review fixes merged into `main`** (PR #2,
  https://github.com/splatfire/eightcount-app/pull/2): crash guards for
  imported files, safer deletes, playback/export race fixes, small logic
  fixes. CI now also runs on pull requests.
- `main` builds and all CI checks are green (Xcode 27 + 26, UI tests on
  iPhone 6.9" and iPad 13" simulators).
- Earlier work: App Store prep (privacy manifest, `eightcount/PRIVACY.md`,
  in-app About & Privacy, `eightcount/APPSTORE.md` with store texts),
  universal app (iPhone incl. iPhone Duo, iPad, Apple-silicon Mac),
  fixes for the memory-test recording crash and the countdown beeps.
- Plan: free app on the App Store first; one-time "Pro" unlock later.

## Waiting on the owner

1. Run `./setup-mac.sh --update` to get the review fixes on the iPhone.
2. Join the Apple Developer Program (99 USD/year), then follow
   `eightcount/APPSTORE.md` from step 2.
3. Test on the iPhone after `./setup-mac.sh --update`:
   - memory test while recording (eye button) – no crash any more?
   - countdown beeps on time with 3-2-1? If not: beep before/after the
     number, by how much, Bluetooth headphones yes/no?
   - phone call / Control Center during recording: does the camera come back?
4. Older open questions: does the Apple Watch app install/work? After a 0.75×
   recording, is the 1× replay gap constant or growing?

## Next steps (for whichever app works next)

- Review findings NOT fixed yet (need an iPhone to test, so left alone):
  camera recovery after an interruption (`CameraRecorder` has no
  interruption observer), background task so a take finishes saving when the
  app is left mid-recording, closing the record screen while a take is
  "finishing" discards it (`RecordView` `end()`), `SyncedPlayback` has no
  `deinit` removing its time observer, `CountCues` voice-loading task not
  cancelled on stop. Checked and rejected as not real: left/right coach
  labels (Vision names joints by the dancer's own body), formation drag hit
  area, play-after-seek at the end of the video.
- When the owner has the paid team: help with `setup-mac.sh --install --team …`,
  App Store Connect, the 4 GitHub secrets for TestFlight.
- If the bundle ID is "not available" on the paid team: pick a new one
  (`--bundle-id`), warn that it installs as a second, empty app.
- Add an iPhone Duo UI-test run to CI once GitHub's Xcode has the iOS 27.1
  SDK (CI currently builds with the iOS 27.0 SDK).
- Later: one-time Pro unlock (StoreKit 2).

## Half-finished / caution

- Nothing half-finished.
- Don't build App Store uploads with a beta Xcode.
