# Vaulted — Private Voice Journal

A vintage library card catalog–style iOS app for capturing voice and text notes with locked private drawers.

---

## How to Run

### Requirements
- **Xcode 15+**
- **iOS 16+ deployment target**
- Physical device or simulator (Face ID works best on device)

### Setup Steps

1. **Create a new Xcode project:**
   - File → New → Project → iOS App
   - Product Name: `Vaulted`
   - Interface: SwiftUI
   - Language: Swift
   - ✅ Use Core Data

2. **Add the source files** from each folder into your project matching the directory structure:
   ```
   App/
     VaultedApp.swift          ← Replace generated App entry point
   Models/
     Entities.swift
   Persistence/
     PersistenceController.swift
     Vaulted.xcdatamodeld/     ← Replace generated .xcdatamodeld
   Services/
     Audio/AudioService.swift
     Security/SecurityService.swift
   Repositories/
     DrawerRepository.swift
     CardRepository.swift
   ViewModels/
     HomeCaptureViewModel.swift
     LibraryViewModel.swift
     CardDetailViewModel.swift
   Views/
     Screens/
       HomeCaptureScreen.swift
       LibraryScreen.swift
       CardDetailScreen.swift
       TextComposerSheet.swift
     Components/
       CardRowView.swift
       AudioPlayerView.swift
       TimelineStackView.swift
       DrawerCabinetView.swift
       BookshelfMonthView.swift
   Theme/
     AppTheme.swift
   ```

3. **Replace the Core Data model:**
   - Delete the auto-generated `.xcdatamodeld`
   - Add the provided `Vaulted.xcdatamodeld` folder to the project (drag into Xcode, checking "Add to targets")

4. **Set deployment target** to iOS 16.0 in project settings.

5. **Add capabilities** in the project's Signing & Capabilities:
   - No special entitlements required (LocalAuthentication and AVFoundation are framework-level)

6. **Build & Run** — first launch seeds the 5 default drawers automatically.

---

## How Audio Files Are Stored

Voice notes are recorded in M4A format using AVAudioRecorder (AAC codec, 44.1kHz, mono).

**Storage path:**
```
<App Documents Directory>/Audio/<card-UUID>.m4a
```

**Lifecycle:**
1. Recording starts to a temporary file in `/tmp/<uuid>.m4a`
2. On recording stop, the file is moved to `Documents/Audio/<cardId>.m4a`
3. The filename (`<uuid>.m4a`) is stored in `CardEntity.audioFileName`
4. On card deletion, the audio file is removed from disk alongside the Core Data record

**Why Documents directory?**
Files in `Documents/` are included in iTunes/iCloud device backups by default, so voice notes survive device restores.

---

## How Locked Drawers Work

### Architecture

The `SecurityService` (singleton) manages unlock state in memory:

```swift
private var unlockedUntil: Date?  // nil = locked
```

### Unlock Flow

1. User taps the **Private** drawer or a private card
2. App checks `SecurityService.privateDrawerIsUnlocked`
3. If locked → triggers `LAContext.evaluatePolicy(.deviceOwnerAuthentication, ...)`
4. This prompts Face ID, Touch ID, or device passcode (system decides based on hardware)
5. On success → `unlockedUntil = now + 600s` (10 minutes)

### Auto-Lock

The drawer **locks immediately** when the app enters the background:
```swift
// In VaultedApp.swift
.onReceive(UIApplication.didEnterBackgroundNotification) { _ in
    security.lockPrivateDrawer()
}
```
This means switching apps or locking the screen immediately re-secures your private content.

### Redaction in Locked State

When `isPrivateUnlocked == false`, private cards display:
- Title: `"Private card"` 
- Snippet: `"••••••••••"`
- Duration: hidden
- SwiftUI `.redacted(reason: .placeholder)` applied for visual blur effect

### Creating a Custom Locked Drawer

```swift
DrawerRepository().createCustomDrawer(
    name: "Secret Project",
    isLocked: true,
    requiresBiometric: true
)
```

---

## Design System

| Token | Value |
|-------|-------|
| Paper background | `#F6F1E7` |
| Card surface | `#FCF9F3` |
| Border muted | `#D6CAB7` |
| Ink primary | `#211E1C` |
| Ink muted | `#70675E` |
| Accent gold | `#C49245` |
| Locked brown | `#7B5C3A` |

Typography uses system serif fonts (`.design: .serif`) throughout to evoke a vintage editorial feel.

---

## Known Limitations (v1)

1. **No iCloud sync** — all data is local only. Multi-device support is a future feature.
2. **No transcription** — voice notes are audio-only. A "Typed Copy" feature (on-device STT) is planned.
3. **No custom locked drawers UI** — creating additional locked drawers requires code. UI is planned.
4. **Single audio track playback** — only one voice note can play at a time.
5. **No waveform visualization** — the audio player shows a progress bar, not a live waveform.
6. **Tags stored as comma-separated string** — works fine for v1 but will migrate to a proper relationship in a future version.
7. **Drawer Cabinet view groups by weekday** — this is a calendar *day-of-week* grouping, not a specific date range. Week-based grouping by date is a planned improvement.
8. **No search in Private drawer while locked** — by design; content is fully hidden until authenticated.
9. **Simulator Face ID** — works in Xcode Simulator via Features → Face ID → Enrolled + Matching Face. Real device recommended for full experience.

---

## Project Architecture

```
┌─────────────────────────────────────────┐
│  Views (SwiftUI)                         │
│  ├── Screens (full page views)           │
│  └── Components (reusable pieces)        │
├─────────────────────────────────────────┤
│  ViewModels (@MainActor ObservableObject)│
├─────────────────────────────────────────┤
│  Repositories (Core Data access layer)  │
├─────────────────────────────────────────┤
│  Services                               │
│  ├── AudioService (AVFoundation)        │
│  └── SecurityService (LocalAuth)        │
├─────────────────────────────────────────┤
│  Persistence (Core Data stack)          │
└─────────────────────────────────────────┘
```

Data flows one way: Views observe ViewModels, ViewModels call Repositories/Services, Repositories read/write Core Data.
