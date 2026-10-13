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

<!-- CHECK_ON_MAC -->

**How to fix a build error:** click the red error in Xcode's Issue navigator
(⌘5). It jumps to the line. Many errors have a **Fix** button. If you're stuck,
paste the error message and the file name into a chat with Claude.

---

## 6. Decisions I made

<!-- DECISIONS -->

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
