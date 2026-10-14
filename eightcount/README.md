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
- **Record yourself** with the front camera while the tutorial plays. You see
  yourself live next to the tutorial, or the tutorial as a see-through
  "ghost" over your camera image. The camera records video only; the music
  comes from the tutorial.
- **Compare**: your take and the tutorial play in sync with the tutorial's
  music. Turn the phone sideways for **you on the left and the tutorial on
  the right**. In portrait it's **you on top, the tutorial below**.
- **AI dance analysis, on your iPhone**: body tracking compares your arms,
  legs, posture and timing with the tutorial for each 8-count. Apple
  Intelligence then writes tips on what to work on.
- **Liquid Glass** design on iOS 26 and newer (including iOS 27), with a
  normal look on older iOS.

Everything stays on your iPhone: no accounts, no servers, no analytics. The AI
analysis runs on the device too.

---

## 1. Run it on your iPhone (step by step)

You need: a Mac with Xcode installed, your iPhone, and a USB cable
(after the first run, Wi-Fi also works).

**Which Xcode?** Use the newest Xcode from the Mac App Store (Xcode 26 or
newer). Older Xcode versions still build the app, but without two things:
Liquid Glass, and the Apple-Intelligence-written tips. The analysis then
falls back to built-in tips. The code switches these on automatically when
your Xcode supports them.

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

### 1.2 Get the code onto your Mac

```sh
git clone -b claude/nice-bardeen-84bg5p https://github.com/splatfire/splatfire.git
cd splatfire/eightcount
```

(Already cloned? Run `git pull` inside the `splatfire` folder instead.)

**Shortcut (recommended):** with your iPhone connected by cable and unlocked:

```sh
./setup-mac.sh --install
```

It checks Xcode, installs XcodeGen, generates the project and runs a compile
check. It then finds your Apple Team, builds and signs the app, and installs
and launches it on your iPhone. If something is missing that only you can
do, such as signing in to Xcode, tapping "Trust" or turning on Developer
Mode, it stops and tells you exactly what to do. After you've done it, run
it again.

Other options: `./setup-mac.sh` (generate and open Xcode only),
`--bundle-id com.yourname.eightcount` (if the default ID is taken),
`--team ABCDE12345`, `--no-open`.

The code is also compiled automatically on GitHub's Macs, with Xcode 27 and
Xcode 26, after every change ("EightCount iOS build" under the repo's
**Actions** tab). A green check there means it compiles.

### 1.3 Generate and open the project (manual way)

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

### 1.4 Sign in and pick your team (signing)

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

### 1.5 Prepare the iPhone (one time)

1. Connect the iPhone with the cable, unlock it, and tap **Trust** when it asks
   to trust this computer.
2. Turn on **Developer Mode** on the iPhone: **Settings → Privacy & Security →
   Developer Mode** → on → restart → confirm with **Turn On** and your passcode.
   If the switch isn't there, keep the iPhone connected and open
   **Window → Devices and Simulators** in Xcode once. The option then appears.

### 1.6 Run

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

### 1.7 Updates without the cable

**Now (free Apple ID): over Wi-Fi from your Mac**

1. One time, run this to put an **"Update EightCount"** icon on your
   Desktop:
   ```sh
   ~/splatfire/eightcount/setup-mac.sh --shortcut
   ```
2. From then on, **double-click "Update EightCount"**. It downloads my newest
   changes and installs them on your iPhone **over Wi-Fi**. The iPhone must
   be unlocked and on the same Wi-Fi as the Mac. It only needs the cable if
   the iPhone has never been paired.
3. Do the same at least every 7 days. With a free Apple ID, apps stop
   opening after 7 days, and the update restarts that clock. Your projects
   stay.

**Later (paid Apple Developer Program, 99 USD/EUR per year): TestFlight, no Mac at all**

Everything is prepared in `.github/workflows/eightcount-testflight.yml`.
After this one-time setup, every change is built by GitHub and appears in
the **TestFlight** app on your iPhone. You tap **Update**, with no Mac and no
7-day expiry (each build lasts 90 days).

1. Enrol at <https://developer.apple.com/programs/enroll/>.
2. In <https://appstoreconnect.apple.com>, go to **Apps → + → New App** and
   choose iOS, the name "EightCount" (or any name) and the bundle ID
   `io.github.splatfire.eightcount`. If the bundle ID isn't in the list,
   create it first under developer.apple.com → Certificates, IDs & Profiles
   → Identifiers.
3. Go to **Users and Access → Integrations → App Store Connect API → +**.
   Give the key **Admin** access, because it has to create the
   distribution certificate. Download the `.p8` file (it can only be
   downloaded once) and note the **Key ID** and **Issuer ID**.
4. On GitHub, open the repo → **Settings → Secrets and variables → Actions
   → New repository secret** and add these 4 secrets:
   - `ASC_KEY_ID`: the Key ID
   - `ASC_ISSUER_ID`: the Issuer ID
   - `ASC_KEY_P8_BASE64`: run `base64 -i ~/Downloads/AuthKey_XXXX.p8 | pbcopy`
     in Terminal, then paste
   - `APPLE_TEAM_ID`: your Team ID (developer.apple.com → Membership)
5. On GitHub: **Actions → EightCount TestFlight → Run workflow**. After
   about 15 minutes plus Apple's processing, the build appears in App Store
   Connect → TestFlight. Add yourself under **Internal Testing**, then
   install the **TestFlight** app on the iPhone and accept the invite.

Not tested yet: GitHub can't run this without your paid account's keys.
If the first run fails, send me the error from the Actions tab.

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
| `NSCameraUsageDescription` | Text shown when the app first asks to use the **camera**, for recording yourself. If you say no, you can turn it on later in Settings → EightCount. |
| `UISupportedInterfaceOrientations` = Portrait + Landscape | Landscape is needed for the record and compare screens. All other screens stay portrait (`Services/OrientationLock.swift`). |
| `UIRequiresFullScreen`, `UILaunchScreen` | Standard iPhone-app setup; launch screen is plain black. |
| `ITSAppUsesNonExemptEncryption = NO` | Saves a question if you ever upload to TestFlight. |

Things that need **no** permission:

- **Files** (`fileImporter`): you pick the file yourself, so no permission is needed.
- **Sound**: the app sets the audio session to "playback", so the music plays
  even when the silent switch is on.
- **Keeping the screen awake** while a video plays (`isIdleTimerDisabled`).

- **Microphone**: not used. Recordings have no sound, because the music comes
  from the tutorial.
- **AI analysis** (Vision body tracking and Apple's on-device model): no
  permission or special setting is needed. Apple Intelligence must be turned
  on in Settings → Apple Intelligence & Siri for the written tips. Otherwise
  you get built-in tips.

The app never uses the microphone, network or location.

---

## 4. Project layout

```
eightcount/
├── project.yml                 XcodeGen spec → generates EightCount.xcodeproj
├── README.md
└── EightCount/
    ├── App/EightCountApp.swift         app entry, database, audio session
    ├── Models/                         SwiftData: Project, CountNote, PoseSnapshot, Take
    │                                   (+ AnalysisReport, saved inside a Take)
    ├── Views/                          project list, new-project sheet,
    │                                   practice screen (ProjectDetailView), video import buttons
    ├── Playback/                       PlayerController (AVPlayer logic), video view,
    │                                   controls, fine scrubber
    ├── Grid/                           CountGrid math, tap tempo, tempo sheet,
    │                                   8-count list, note editor, snapshot viewer, NoteStore
    ├── Transfer/                       export/import file format, share sheet
    ├── Recording/                      front camera recorder, record screen
    ├── Compare/                        synced two-video playback, compare screen, takes list
    ├── Analysis/                       body-pose extraction (Vision), comparison,
    │                                   coach tips (Apple Foundation Models), results screen
    ├── Services/                       VideoStorage, PhotosPicker transfer, FrameGrabber
    ├── Design/                         Theme (colors, big buttons), Glass (Liquid Glass)
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

### Record → Compare → Analyze (how to use it)

1. In the practice screen, put the video where you want to start. Pick a
   speed: practicing at 0.5× is fine, because the compare screen accounts
   for it. Tip: set an A-B loop, or loop one 8-count, to record exactly that
   part.
2. Tap **⏺ (Record yourself)** at the top. Put the phone on a stand so your
   **whole body** is visible, then tap the red button. Recording starts, a
   3-2-1 countdown runs, then the tutorial and its music start.
3. Tap Stop, or it stops by itself at the end of the loop or video. Then
   tap **Compare**.
4. In Compare, turn the phone sideways for you (left) and the tutorial
   (right). Play, scrub, slow down, and switch to ghost overlay to see the
   differences.
5. If your video looks a bit early or late even though you danced on the
   beat, use **Sync** to nudge it by a frame or 0.1 s.
6. Tap **✨ Analyze** for the AI feedback, then **Show me on the video**. The
   app pauses at each issue, draws a stick figure over you and over the
   tutorial with the problem limb in red, and you step through the issues
   with ‹ ›. **Replay** plays that moment slowly. Red dots on the timeline
   mark every issue.
7. Switch to **Ghost** for a one-to-one comparison. The tutorial is laid
   see-through over you and lined up with your body automatically. Drag or
   pinch to adjust it.
8. All recordings are under ⋯ → **My Takes**.

How the AI analysis works: Apple's Vision framework finds 15 body points
(shoulders, elbows, wrists, hips, knees, ankles…) in about 10 frames per
second of both videos. The app compares joint angles, arm height, posture,
movement size and timing for each 8-count. It gives a score per 8-count
and lists the biggest differences ("Lift your left arm higher, 8-count 3,
count 5"). Apple's on-device language model turns that into a few friendly
tips. It's good at angles, levels and timing. It can't judge style,
facial expression or energy.

---

## 5. Check on Mac (what I'm not 100 % sure about)

**Verified on GitHub's Macs** (workflow `.github/workflows/eightcount-ios-build.yml`,
runs after every change, results under the repo's **Actions** tab):

- **Builds with 0 errors** with **Xcode 27** (27A266a, iOS 27.0 SDK) and with
  Xcode 26, for a real iPhone (unsigned).
- **UI test passes in the iOS 27 Simulator.** It taps through: project list
  → practice screen with video → play → 0.5× + mirror → loop an 8-count →
  notes → My Takes → compare (portrait and landscape) → AI analysis. Nothing
  crashed, and landscape shows you on the left and the tutorial on the
  right. It uses a generated test video with no person in it, so the
  analysis correctly answers "couldn't find the dancer". Screenshots are in
  the run's **Artifacts** ("ui-screenshots").

**Not testable there** (no camera, no real person, no Apple Intelligence in
the simulator), so please check these on your iPhone: recording with the
front camera, real dance analysis, the Apple-Intelligence tips, and signing
with your Apple ID.

The lists below were written before the code could be compiled. They're
still useful if something behaves oddly on the phone.

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

**D. Record / compare / AI analysis (added in the second round)**

Build errors, if any, are most likely here:

1. `ForEach(projects)` / `NavigationLink(value: project)` need the SwiftData
   models to be `Identifiable`. If Xcode complains, use
   `ForEach(projects, id: \.persistentModelID)`.
2. `RecordView`'s `.sensoryFeedback(trigger:) { old, new in … }`. If the
   closure's type can't be worked out, write `-> SensoryFeedback?` after
   `old, new in`.
3. `CameraRecorder` observes `videoRotationAngleForHorizonLevelPreview` on
   `AVCaptureDevice.RotationCoordinator`. If the key path is rejected, react
   to `UIDevice.orientationDidChangeNotification` instead.
4. `Analysis/PoseExtractor.swift`: `for try await result in
   generator.images(for:)` and the Vision calls. A warning about an
   unnecessary `try` is harmless.
5. `Analysis/CoachWriter.swift` (Foundation Models): `LanguageModelSession`,
   `respond(to:)`, `SystemLanguageModel.default.availability`. This part is
   only compiled with Xcode 26+.
6. Deprecation warnings for Vision's `VN…` classes on new SDKs are fine
   (yellow, not red).

Test these on the phone:

1. **Recording upright in landscape:** record once in portrait and once
   sideways. Both should be upright in the compare screen.
2. **Sync:** clap on count 1 while recording, then compare. If you're a few
   frames off, use Sync to nudge. The phone's camera start delay isn't
   exactly known, so this is expected.
3. **Music while recording:** the tutorial's sound plays from the speaker
   and the recording has no sound.
4. **After recording, "Compare" opens the compare screen.** If it ever
   doesn't open, tell me and I'll add a short delay.
5. **Analysis:** try a short part (one or two 8-counts) first. It takes
   roughly 1–2 minutes per minute of video. Check that "late" or "early"
   matches what you see, and that left/right in the tips matches your own
   left/right.
6. **Apple Intelligence tips:** the caption should say "Tips by Apple
   Intelligence". If it says "Built-in tips", turn on Apple Intelligence in
   Settings, or wait until its model has finished downloading.
7. **Liquid Glass:** buttons and control bars should look like glass on
   iOS 26/27.

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

**Testing**
- **A Debug-only demo seed** (`App/DebugSeed.swift`) creates a "Demo"
  project when the app is launched with `-seedDemo`. Only the UI test uses
  it. It's left out of release builds, and a normal launch never triggers it.
- **A UI-test target** (`EightCountUITests`) and a GitHub Actions workflow
  build and test the app on Xcode 27 and 26. They're free, because the repo
  is public.

**Look & layout**
- **Always dark** (`UIUserInterfaceStyle = Dark`), coral-pink accent, light-blue
  for anything loop-related.
- **Portrait for practice, landscape allowed for record and compare.** The
  practice screen stays portrait-only. Turning sideways is mainly useful
  for side by side.
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

**Recording, compare & AI analysis**
- **AI runs fully on the iPhone** (your choice). Vision body tracking plus
  Apple's Foundation Models framework. No API key, no cost, nothing uploaded.
- **Recordings have no sound** (no microphone needed). The compare screen
  plays the tutorial's music.
- **What gets recorded:** recording starts at the current video position,
  at the current speed and mirror setting. If an A-B loop or a looped
  8-count is active, it records exactly that part and stops at its end.
- **A 3-second countdown** after you press Record. The recording keeps it,
  and the app remembers where the tutorial started, so the two line up.
- **Sync fine-tuning.** The camera starts with a small delay that differs
  from phone to phone, so the compare screen has a "Sync" panel to nudge
  your video by ±1 frame or ±0.1 s. The nudge is saved with the take.
- **The recorded file is not mirrored** (it's how others see you). The
  compare screen shows it **mirrored by default**, like a mirror, and you
  can switch that off.
- **The AI compares what you see on screen.** If you look the same as the
  tutorial on screen (with the current mirror settings), it counts as a
  match. So the mirror toggles affect the analysis, and the app tells you
  when you should re-analyze.
- **In group videos the AI follows the biggest (closest) dancer** in each
  frame. Choosing a specific dancer is in Next steps.
- **Timing sign:** "late" means you do the move after the tutorial does.
  Detection works in steps of 0.1 s, within ±0.6 s.
- **The latest analysis is saved with each take.** Re-analyzing replaces it.
- **Takes are not part of the notes export** (they're videos). Deleting a
  project or a take always asks first, and deletes the video files too.

**Liquid Glass (iOS 26 / 27)**
- **Liquid Glass on iOS 26+, solid look on iOS 17–25.** The deployment
  target stays iOS 17. The glass code is guarded twice: compiled only with
  Xcode 26+ (`#if compiler(>=6.2)`), and used only on iOS 26+ (`#available`).
- **Glass parts:** all big buttons, the 8-count loop/edit buttons, and the
  control bars that float over video. Navigation bars, toolbars, sheets and
  menus get glass automatically from iOS.
- **Built on the iOS 26 APIs** (`glassEffect`, `GlassEffectContainer`), which
  iOS 27 still uses. Reportedly, iOS 27 makes the glass less transparent and
  adds a user setting for it. Both would apply to this app automatically.
  Also reportedly, Xcode 27 no longer lets apps opt out of Liquid Glass; this
  app doesn't try to. These iOS 27 details come from secondary sources
  ([Wikipedia](https://en.wikipedia.org/wiki/Liquid_Glass),
  [migration write-up](https://ecorpit.com/ios-27-liquid-glass-xcode-27-migration-guide-2026/)),
  not Apple's own docs, so I didn't use any iOS-27-only API.

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
- **Practice tracking:** a "practiced / not yet" checkmark per 8-count and a
  progress bar per project.

Other ideas that came up while building:

- Open `.eightcount.json` files directly from AirDrop, Messages or Files
  ("Open in EightCount"). This needs a custom document type in Info.plist.
  Right now you import them with the ⤓ button on the project list.
- Landscape mode for the practice screen too.
- Pick which dancer the AI should follow in group videos.
- Optional cloud AI (e.g. Claude) for richer, style-level feedback, if you
  ever want it. It would need an API key and would upload frames.
- Show a video thumbnail in the project list.
