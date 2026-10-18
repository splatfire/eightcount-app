# Rules for every AI assistant working on this repo

Read by **Cursor** (automatically), **Claude Code** (via `CLAUDE.md`) and any
other agent. The owner switches between these apps; this file and
`HANDOFF.md` are how each one knows where the last one stopped.

## 1. Start of every session (before doing anything else)

1. Get the newest version: run `./handoff.sh start` in the repo root (it
   pulls from GitHub and prints `HANDOFF.md`). If you can't run commands,
   at least read `HANDOFF.md`.
2. Read `HANDOFF.md` fully: current state, what's next, open questions.
3. Then do what the owner asks.

## 2. End of every session (or after each finished piece of work)

1. Update `HANDOFF.md` (keep it short – it is "now", not history):
   - date, which app you are (Cursor / Claude Code), what you did,
   - what's next, open questions, what you're waiting on from the owner,
   - anything half-finished (files, branch, why).
2. Add one line per finished feature/fix to `PROGRESS.md` (the history).
3. Save and sync: `./handoff.sh save "short description"` (commits
   everything and pushes to GitHub). Never leave work only on one computer.

**Only one app at a time.** If both edit at once, git conflicts follow. If
`./handoff.sh start` reports a conflict, stop and tell the owner in plain words.

## 3. The project

- **EightCount**: native iPhone/iPad app (SwiftUI, SwiftData, AVFoundation,
  Vision, FoundationModels), iOS 17+, Apple Watch remote (watchOS 10).
  Everything is in `eightcount/`. Details: `eightcount/README.md`,
  App Store steps: `eightcount/APPSTORE.md`.
- **Repo:** github.com/splatfire/eightcount-app, branch `main`. Work and push
  on `main` (history before 18 Oct 2026: splatfire/splatfire, branch
  `claude/nice-bardeen-84bg5p`).
- The Xcode project is GENERATED: edit `eightcount/project.yml`, then
  `xcodegen generate`. Never edit or commit `EightCount.xcodeproj`.
- Build / install on the owner's iPhone: `cd eightcount && ./setup-mac.sh --update`
  (or `--install`). Logs: `eightcount/build.log`, `eightcount/device-build.log`.
- CI (GitHub Actions, `.github/workflows/eightcount-ios-build.yml`): builds
  with Xcode 27 + 26 and runs the UI tests on an iPhone and an iPad simulator
  on every push. Check it after pushing; a red CI must be fixed.
- Swift 5 language mode. Liquid Glass code is guarded by `#if compiler(>=6.2)`
  + `#available(iOS 26.0, *)` (`eightcount/EightCount/Design/Glass.swift`).
- Commit messages: plain English, what and why. No AI model names in commits
  or code.

## 4. How to talk to the owner

- The owner is a beginner: explain in plain words, short, do the work yourself.
- **Never make things up.** If you're not sure, say so (or "I don't know"),
  give a confidence level, and ask for missing information instead of
  guessing. Cite sources for facts from the web.
- Things only the owner can do (Apple ID, paying, tapping "Trust" on the
  iPhone, App Store Connect): explain step by step.

## 5. Cloud agents (Linux)

Cursor cloud agents run on Ubuntu, not a Mac. They cannot install Xcode,
so they cannot build the iPhone app, open the simulator, or install on a
phone. That still happens on the owner's Mac:

```sh
cd eightcount && ./setup-mac.sh
```

GitHub Actions (Xcode 27 and 26) is the compile check.

The cloud machine has Swift 6.4.1 on `PATH` (`swift` and `swiftc` in
`/usr/local/bin`, toolchain in `/opt/swift`). Use it to run the plain math
the app is built on. Compile these three files together with a driver
named `main.swift` (any other file name is treated as a library and
top-level code is rejected):

- `eightcount/EightCount/Grid/CountGrid.swift` (8-counts)
- `eightcount/EightCount/Services/TakeTiming.swift` (lining up a take)
- `eightcount/Shared/WatchProtocol.swift` (Apple Watch messages)

A green run of that math is not a green iPhone build.
