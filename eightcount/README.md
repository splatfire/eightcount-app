# EightCount — learn choreography in 8-counts

A native iPhone app (SwiftUI, iOS 17+) for learning dance choreography from
tutorial and dance-practice videos:

- **Import** a video from Photos or Files. The app keeps its own copy, so the
  video stays even if you delete it from Photos.
- **Practice playback**: mirror, 0.25× / 0.5× / 0.75× / 1× speed (the music
  keeps its pitch), an A-B loop you can set while the video plays, a scrubber,
  a fine-scrub strip and ±1-frame buttons.
- **8-count grid**: type the BPM or tap along, set where count 1 starts, and
  the video is split into 8-counts. Tap one to jump there, or loop just that one.
- **Notes per 8-count**: main note plus feet, arms, facing direction and the
  lyric cue.
- **Pose snapshots**: grab the current frame and attach it to the 8-count.
- **Projects**: one per song or section. Create, rename, delete (always confirmed).
- **Export / import** a project's notes and snapshots (not the video) as one
  file, so you can back them up or send them to someone in your group.

Everything stays on your iPhone: no accounts, no servers, no analytics.

---

## 1. Run it on your iPhone (step by step)

You need: a Mac with Xcode installed, your iPhone, and a USB cable
(after the first run, Wi-Fi also works).

### 1.1 Install Homebrew and XcodeGen (one time)

This folder has no `.xcodeproj` file. Instead, `project.yml` describes the
project and a small tool called **XcodeGen** turns it into one.

1. Open **Terminal** (press ⌘-Space, type "Terminal", press Return).
2. If you don't have Homebrew yet, install it with the command shown on
   <https://brew.sh> (copy, paste, Return, then follow what it prints at the
   end — on Apple-silicon Macs it asks you to run two more lines to add
   `brew` to your PATH).
3. Install XcodeGen:
   ```sh
   brew install xcodegen
   ```
4. Open Xcode once and let it install its extra components if it asks.

### 1.2 Generate and open the project

```sh
cd path/to/splatfire/eightcount      # the folder that contains project.yml
xcodegen generate
open EightCount.xcodeproj
```

Tip: you can type `cd ` and then drag the `eightcount` folder from Finder into
the Terminal window to fill in the path.

Run `xcodegen generate` again whenever files are added or removed or
`project.yml` changes. It rebuilds `EightCount.xcodeproj` from scratch.
**Close the project in Xcode before regenerating.**

### 1.3 Sign in and pick your team (signing)

1. Xcode → **Settings…** (⌘,) → **Accounts** → **+** → **Apple ID** → sign in.
   A free Apple ID shows up as "*Your Name* (Personal Team)".
2. In the project navigator (left), click the blue **EightCount** project icon,
   select the **EightCount** target, then open the **Signing & Capabilities** tab.
3. Leave **Automatically manage signing** checked. Set **Team** to your
   (Personal) Team.
4. If Xcode shows *"Failed to register bundle identifier"* or *"cannot be
   registered to your development team"*, that app ID is already taken by
   someone else. Change **Bundle Identifier** to something unique, such as
   `com.yourname.eightcount`. Then put the same value into
   `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`, so it survives the next
   regenerate.

**So you don't have to pick the team after every `xcodegen generate`:** after
step 3, go to the **Build Settings** tab, search for "Development Team", and
copy the 10-character ID. Paste it into `project.yml` at
`DEVELOPMENT_TEAM: ""` (between the quotes).

### 1.4 Prepare the iPhone (one time)

1. Connect the iPhone with the cable, unlock it, and tap **Trust** when it asks
   to trust this computer.
2. Turn on **Developer Mode** on the iPhone: **Settings → Privacy & Security →
   Developer Mode** → on → restart → confirm with **Turn On** and your passcode.
   If the switch isn't there, keep the iPhone connected and open
   **Window → Devices and Simulators** in Xcode once. The option then appears.

### 1.5 Run

1. In the Xcode toolbar at the top, click the device selector (next to
   "EightCount") and choose your iPhone.
2. Press **▶ Run** (⌘R). The first build takes a minute or two.
3. **Free Apple ID only:** the first launch fails with "Untrusted Developer".
   On the iPhone go to **Settings → General → VPN & Device Management** → tap
   your Apple ID → **Trust**. Then press ▶ in Xcode again.

You can also try the app in the **iPhone Simulator** (choose e.g. "iPhone 16"
as the destination) without any signing. Drag a video file onto the simulator
window to put it into its Photos app.

---

## 2. Free Apple ID vs. paid Apple Developer Program

| | Free Apple ID (Personal Team) | Paid Developer Program (99 USD/year) |
|---|---|---|
| Run on your own iPhone | Yes | Yes |
| How long an install keeps working | **7 days.** Then the app won't open until you connect the phone and press ▶ Run in Xcode again. Your data inside the app stays. | **1 year** |
| Apps per device | max. 3 of your own apps | no practical limit |
| New app IDs | max. 10 per 7 days | unlimited |
| Give the app to friends (TestFlight) | No | Yes (TestFlight, up to 10,000 testers) |
| App Store | No | Yes |

For this app (just for you, no special capabilities like iCloud or push
notifications) **the free Apple ID works**. The only annoyance is re-running it
from Xcode once a week. If your group wants the app too, the paid account plus
TestFlight is the easy way.

Sources: Apple's
[membership comparison](https://developer.apple.com/support/compare-memberships/)
and an [Apple developer-forum thread on the 7-day expiry](https://developer.apple.com/forums/thread/71283).

---

## 3. Permissions and Info.plist entries

The Info.plist is at `EightCount/Resources/Info.plist`.

| Key | Why |
|---|---|
| `NSPhotoLibraryUsageDescription` | Text for a Photos-permission prompt. **You will most likely never see that prompt.** The app uses `PhotosPicker`, which runs outside the app and needs no permission. I added the key anyway as a safety net: if iOS ever does ask, the app would crash without it. |
| `UIUserInterfaceStyle = Dark` | Always dark mode. |
| `UISupportedInterfaceOrientations = Portrait` | Portrait only (see Decisions). |
| `UIRequiresFullScreen`, `UILaunchScreen` | Standard iPhone-app setup; launch screen is plain black. |
| `ITSAppUsesNonExemptEncryption = NO` | Saves a question if you ever upload to TestFlight. |

Things that need **no** permission:

- **Files** (`fileImporter`): you pick the file yourself, so no permission is needed.
- **Sound**: the app sets the audio session to "playback", so the music plays
  even when the silent switch is on.
- **Keeping the screen awake** while a video plays (`isIdleTimerDisabled`).

The app never uses the camera, microphone, network or location.

---

## 4. Project layout

```
eightcount/
├── project.yml                 XcodeGen spec → generates EightCount.xcodeproj
├── README.md
└── EightCount/
    ├── App/EightCountApp.swift         app entry, database, audio session
    ├── Models/                         SwiftData: Project, CountNote, PoseSnapshot
    ├── Views/                          project list, new-project sheet,
    │                                   practice screen (ProjectDetailView), video import buttons
    ├── Playback/                       PlayerController (AVPlayer logic), video view,
    │                                   controls, fine scrubber
    ├── Grid/                           CountGrid math, tap tempo, tempo sheet,
    │                                   8-count list, note editor, snapshot viewer, NoteStore
    ├── Transfer/                       export/import file format, share sheet
    ├── Services/                       VideoStorage, PhotosPicker transfer, FrameGrabber
    ├── Design/Theme.swift              colors, big button style, time formatting
    └── Resources/                      Info.plist, Assets.xcassets (icon, colors)
```

How a practice session works in the code:

1. `ProjectDetailView` creates a `PlayerController` (wraps `AVPlayer`) and loads
   the project's copied video.
2. `CountGrid` turns *BPM + offset + video length* into 8-count start and end
   times. The math is in `Grid/CountGrid.swift`.
3. `CountListView` shows one row per 8-count. Tapping a row seeks the player.
   The loop button calls `loopEightCount`, which is just an A-B loop over that
   8-count.
4. Notes (`CountNote`) are stored by **8-count number**. A snapshot is a JPEG
   saved in a `PoseSnapshot` that belongs to a note.

---

## 5. Check on Mac (what I'm not 100 % sure about)

The code was written in a Linux environment without Xcode, so **it has never
been compiled**. I wrote it carefully against the iOS 17 APIs and had it
reviewed independently, but expect a few small compile errors on the first
build. Here is where to look first:

**A. Most likely to cause build errors (check these first)**

1. **Main-actor isolation** (if Xcode says something like "call to main
   actor-isolated … in a synchronous nonisolated context"). Most view structs
   are marked `@MainActor`. If one that isn't (`ExportProjectButton`,
   `VideoImportButtons`, small private views) complains, put `@MainActor` on
   the line above its `struct`. This mainly matters on Xcode 15; on Xcode 16
   and newer, every SwiftUI view is main-actor anyway.
2. **"Initializer is inaccessible due to 'private' protection level"** on
   `ProjectDetailView(project:)`, `NewProjectSheet { … }` or
   `VideoImportButtons { … }`. These rely on Swift's automatic initializer.
   If this appears, add an explicit `init` like the other views have.
3. **`Divider().overlay(Theme.surfaceRaised)`** in `ProjectDetailView`. If Xcode
   says "ambiguous use", change it to `.background(Theme.surfaceRaised)`.
4. **`Bindable(wrappedValue:)`** in `TempoSetupSheet`'s `init`, and the
   `ChipFlowLayout` (`Layout` protocol) in `CountRowView`.
5. **Concurrency *warnings*** in `PlayerController` (AVFoundation callbacks)
   and `SnapshotImageCache` (`static let NSCache`). These are yellow warnings,
   not errors. You can ignore them for now.

**B. Worth one test on the phone**

1. **Slow speeds:** at 0.25× and 0.5×, check that the sound keeps its pitch.
   The app uses Apple's `.spectral` setting. If you hear no sound at 0.25×,
   tell me.
2. **Mirror:** check that the video really flips (it uses SwiftUI's
   `scaleEffect(x: -1)` on the video view).
3. **Importing from Photos:** a long video or one stored in iCloud takes a
   moment to copy, and a "Copying video…" spinner shows. In the New Project
   form, check that tapping "From Photos" doesn't also open "From Files". Both
   buttons sit in one form row.
4. **"From Files" importing** in the New Project sheet and in the Add / Replace
   Video sheet. Also check the ⤓ import of a notes file on the project list.
   SwiftUI is picky about several file pickers, so I put each in its own sheet.
5. **The A-B loop:** it can overshoot B by up to about 1/60 s before jumping
   back. That's fine for dancing, but tell me if it feels late.
6. **Holding the ◀︎ / ▶︎ frame buttons should repeat**
   (`.buttonRepeatBehavior`).
7. **Export** (↑ button in the practice screen): the share sheet opens. Try
   "Save to Files" and AirDrop. Then import the file again from the project
   list.
8. **Auto-scroll:** while the video plays, the 8-count list scrolls to the
   current row.
9. **The tempo sheet** (tap the "♩ BPM" bar above the list) opens half-height
   with a Play/Pause bar, so you can tap along while the music plays.
10. **Silent switch:** music should still play with the switch on silent.

**C. Things I knowingly left simple**

- `@State private var controller = PlayerController()`: SwiftUI may create
  a few spare players that are thrown away right away. That's harmless,
  because creating one is cheap.
- Some SF Symbol names (`shoeprints.fill`, `figure.arms.open`,
  `location.north.line.fill`, …). A wrong name just shows an empty icon. It
  never breaks the build.

**How to fix a build error:** click the red error in Xcode's Issue navigator
(⌘5). It jumps to the line. Many errors have a **Fix** button. If you're stuck,
paste the error message and the file name into a chat with Claude.

---

## 6. Decisions I made

You said you couldn't answer questions live, so I made these calls myself.
Change any of them later.

**Project & tooling**
- **App name "EightCount"**, bundle ID `io.github.splatfire.eightcount`. Change it
  in `project.yml` if Xcode can't register it (see 1.3).
- **App folder `eightcount/`** inside this repo, next to the existing web
  apps. Root `README.md` links to it.
- **No third-party packages at all.** Everything uses Apple frameworks.
- **Swift 5 language mode** (`SWIFT_VERSION: 5.0`), so Swift 6's stricter
  concurrency checks show up as warnings, not build errors, on a first build.
- **Hand-written `Info.plist`** (not Xcode's generated one), so you can read
  every entry in one file.
- **Simple generated app icon**: eight beat dots in a circle, the first one
  highlighted, plus a play triangle.

**Look & layout**
- **Always dark** (`UIUserInterfaceStyle = Dark`), coral-pink accent, light-blue
  for anything loop-related.
- **Portrait only** for now ("portrait first"). Landscape is in Next steps.
- **Buttons are at least 52 pt tall** (Apple's minimum is 44 pt) for use from a
  distance.
- **Video takes at most about 1/3 of the screen height.** Video and controls
  stay fixed at the top, and only the 8-count list scrolls.
- **The 8-count list auto-scrolls to the current 8-count only while the
  video plays**, so you can scroll freely while paused. You can turn this off
  under ⋯ → "Follow Playback in List".

**Video & playback**
- **Videos are copied** into the app's private folder (Application
  Support/Videos), under a random file name. They're included in your
  normal iPhone backup.
- **Videos from Photos are imported in their original format**
  (`preferredItemEncoding: .current`). The other option re-encodes the video,
  which can take minutes on long clips.
- **A project can exist without a video.** You can add one later, or replace
  it (with a confirmation). Notes stay attached to their 8-count numbers.
- **Picking a video in the New Project sheet and then pressing Cancel deletes
  the copy**, so nothing is left behind.
- **Sound plays even with the silent switch on**, using the "playback" audio
  session. This also pauses music from other apps.
- **Pitch correction uses Apple's `.spectral` algorithm**, the highest-quality
  one.
- **Speed is one of four buttons** (0.25×, 0.5×, 0.75×, 1×), no free slider.
  The speed stays when you loop or jump.
- **Scrubbing precision comes in three layers**: the normal timeline slider,
  a "fine-scrub" strip (drag about 7 pt = 1 frame), and ◀︎/▶︎ one-frame buttons
  (hold to repeat). Frame length comes from the video's frame rate.
- **−2 s / +2 s buttons** for quick "again from a bit before" jumps.
- **A-B loop:** "Set A" and "Set B" save the current time. If B ends up
  before A they are swapped. The loop turns on automatically once both are
  set.
- **Looping an 8-count reuses the A-B loop** (A = start, B = end of that
  8-count), so the loop buttons show it too.
- **Jumping (tap a row, slider, ±2 s) outside the current loop turns the
  loop off** but keeps A and B, so one tap on "Loop" brings it back.
  Frame-stepping never turns it off.
- **The screen stays awake only while the video is actually playing.**
- **The video pauses when you leave the practice screen.**

**8-count grid & notes**
- **Notes are stored per 8-count number, not per video time.** If you later
  change the BPM or the start of count 1, the notes stay on "8-count #5"
  even though #5 now covers a slightly different part of the video. I chose
  this because you usually fine-tune the tempo first and then write notes.
- **Tap tempo corrects for slow speed.** If you tap along at 0.5× speed,
  the BPM is doubled back to the song's real tempo. It averages your last 8
  taps, and a pause of about 2 s starts over.
- **BPM range 40–250, one decimal place.** −1 / −0.5 / +0.5 / +1 buttons
  for fine adjustments.
- **"Count 1 starts NOW"** uses the current video position. Nudge buttons
  move it by ±0.01 s or ±0.05 s.
- **Anything before count 1 shows as "Intro"** in the count display.
- **A partial 8-count at the end of the video still gets a row.**
- **Empty notes are cleaned up.** Opening an 8-count's editor and closing it
  without typing anything doesn't leave an empty note behind.
- **Snapshots go to the 8-count at the playhead.** During the intro they go
  to 8-count 1. Snapshots need a BPM, so the app tells you to set one first.
- **A snapshot is saved as you see it.** If mirror mode is on, the picture is
  mirrored too. It's a JPEG, at most 1280 px on its longest side, stored in
  the database with SwiftData's "external storage".
- **Deleting anything always asks first**: projects, snapshots, and the
  current video when you replace it.

**Export / import**
- **The file format is a single `.json` file** (named
  `Title - section.eightcount.json`) with the snapshots embedded. iOS has no
  built-in zip API, and a plain JSON file needs no special file-type setup.
  The video is never included.
- **Importing always creates a new project.** It never overwrites an existing
  one. If the name already exists, " (imported)" is added. The imported
  project has no video and shows the original video's file name, so you know
  what to add.
- **Import is a button** (⤓ at the top left of the project list), not "Open
  in EightCount" from AirDrop or Files. That would need extra file-type setup
  (see Next steps).
- **Files from a newer app version, or that aren't EightCount files, are
  rejected** with a clear message.

---

## 7. Next steps (not built yet)

- **Count-in before a loop restarts:** a spoken or visual "5, 6, 7, 8" right
  before the A-B / 8-count loop jumps back, so you're ready on count 1.
- **Record yourself side by side:** record with the front camera and play it
  next to the tutorial, synced to the same start point.
- **Practice tracking:** a "practiced / not yet" checkmark per 8-count and a
  progress bar per project.

Other ideas that came up while building:

- Open `.eightcount.json` files directly from AirDrop, Messages or Files
  ("Open in EightCount"). This needs a custom document type in Info.plist.
  Right now you import them with the ⤓ button on the project list.
- Landscape / full-screen video mode.
- Show a video thumbnail in the project list.
