# Where we left off

_Last updated: 18 October 2026 · by Cursor_

## State right now

- **Repo:** github.com/splatfire/eightcount-app, branch `main`. On the Mac
  the folder is `~/eightcount-app`.
- EightCount builds and CI was green (Xcode 27 + 26, UI tests on iPhone
  6.9" and iPad 13" simulators). The iPhone app still only builds on a Mac
  with Xcode (`cd eightcount && ./setup-mac.sh`).
- Cloud agents (Linux) now have Swift 6.4.1. A check of the plain math
  passed: 120 BPM, count 1 at 0.5s, 20s video → 5 eight-counts; a 0.5×
  take lines up; a watch speed message round-trips. This is not an iPhone
  build.
- Recent app work: App Store prep, universal app, memory-test crash and
  countdown beep fixes. Plan: free app first, one-time Pro unlock later.

## Waiting on the owner

1. Click **Save** on the Cloud Agent environment card so later agents
   start with Swift already installed.
2. Join the Apple Developer Program (99 USD/year), then follow
   `eightcount/APPSTORE.md` from step 2.
3. Test on the iPhone after `./setup-mac.sh --update`:
   - memory test while recording (eye button) – no crash any more?
   - countdown beeps on time with 3-2-1? If not: beep before/after the
     number, by how much, Bluetooth headphones yes/no?
4. Older open questions: does the Apple Watch app install/work? After a 0.75×
   recording, is the 1× replay gap constant or growing?

## Next steps (for whichever app works next)

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
