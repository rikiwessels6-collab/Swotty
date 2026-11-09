# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Swotty is a SwiftUI study-planner iOS app (iOS 16.1+, Swift 5.9) that is already live on the App Store (bundle ID `com.boundaryline.swotty`, last approved version 1.5, so `MARKETING_VERSION` is 1.6). All data is local (UserDefaults); there are no accounts or servers.

## There is no Mac here

The owner works from an iPad/iPhone, and Claude sessions run on Linux, so **Swift cannot be compiled or tested locally**. GitHub Actions on macOS runners is the compiler and the release pipeline. Write Swift carefully and let CI catch what it catches.

Common compile traps already hit in this repo: a local constant named the same as a method (`let subject = subject(for:)` must be `self.subject(for:)`); `if case .x = optional.last` needs `if let last = ..., case`; `if` inside a `ToolbarContentBuilder`; local helpers shadowing names like `calendar`.

## Commands

On a Mac (not available in normal sessions):

```bash
brew install xcodegen && xcodegen generate     # creates Swotty.xcodeproj (generated, gitignored)
xcodebuild test -project Swotty.xcodeproj -scheme Swotty \
  -destination "id=$(bash scripts/ci-simulator.sh)" CODE_SIGNING_ALLOWED=NO
# one test class / method:
#   ... -only-testing:SwottyTests/InsightsTests/testCountdownText
```

`project.yml` is the source of truth for targets, versions and entitlements. The `.xcodeproj`, the generated `Info.plist` files and `Config/*.entitlements` are gitignored; edit `project.yml` instead. `README.md` still shows an old `iPhone 16` destination and a "placeholder icon" note; CI no longer uses either.

## Release flow (user preference: ship without asking, once CI is green)

1. Commit and push to the PR branch `claude/navy-gold-redesign` (PR #5). `ios.yml` runs `build-for-testing` on a generic simulator, then the tests.
2. When that run is green, push the same commit to the **`testflight`** branch (plain fast-forward push, never force). `testflight.yml` then builds and uploads to TestFlight. Build number = the workflow run number. `workflow_dispatch` and tag pushes are blocked for this session's GitHub token, so the branch push is the trigger.
3. Check the run: `gh api "repos/rikiwessels6-collab/Swotty/actions/workflows/testflight.yml/runs?per_page=1"`. PR check-suite events wake the session.

Standing rules from the owner: **do not merge PR #5 until they say so**, and ask before changing anything on their Apple account. Force-pushes are blocked. The GitHub MCP tools and `gh` are the only GitHub access.

TestFlight signing: the archive is built **unsigned** (`CODE_SIGNING_ALLOWED=NO`) and signed at export with `-allowProvisioningUpdates` and an App Store Connect API key (secrets listed in `docs/TESTFLIGHT.md`), because automatic archive signing needs a registered device. The workflow selects Xcode 26+ because Apple rejects older SDKs.

## The App Group is not active

`project.yml` declares the App Group `group.com.boundaryline.swotty` for the app and widget, but the unsigned archive drops custom entitlements, so the shipped build has none. Embedding them (ad-hoc `codesign` before export) made the export fail with "No profiles for ... were found" because the group isn't registered on the owner's developer account and the API key can't create one. That embed step was backed out (build 10 behaviour, builds 12 onward). Consequence: `WidgetSnapshot.read()` finds nothing in the shared container, and the widgets fall back to reading the Swotty calendars in Apple Calendar (`CalendarFallback` in `SwottyWidget/WidgetData.swift`). To enable the real path the owner must register the group and enable it on both App IDs (see `docs/TESTFLIGHT.md`), after which the embed step has to be reinstated. iCloud sync is blocked by the same kind of Apple-side step.

## Architecture

- **`StudyStore`** (`Swotty/Store/StudyStore.swift`) is the single `ObservableObject` injected as an environment object. `items` (assessments), `subjects`, `lessons`, `periods`, `notes` are `@Published` with `didSet` observers that persist JSON to UserDefaults and trigger side effects: class reminders, Calendar timetable sync, and `refreshWidget()`. Add or mutate data through the store's methods (`add`, `update`, `delete`/`undoDelete`, `toggleCompleted`, ...) so reminders, Calendar events and the widget stay in step (`refreshExtras`).
- **Models are tolerant decoders.** Every `Codable` model decodes with `decodeIfPresent` and defaults, and `Assessment` stores `subjectID` under the legacy key `"subject"`. Keep that when adding fields so older saved data and backups (`BackupFile`) still load.
- **Week A / Week B**: `Swotty/Shared/ScheduleSettings.swift` holds the UserDefaults keys and `weekType(for:anchor:weekStart:)`. Weeks alternate from an anchor date so changing the week start never flips which week is A. A lesson's `week` is 0 (every week), 1 (A) or 2 (B). Changes post `ScheduleSettings.didChangeNotification`; the store, Calendar sync and widget all observe it. Class reminders in two-week mode are scheduled by date a fortnight ahead and topped up when the app becomes active (a repeating weekly trigger can't skip alternate weeks).
- **`Swotty/Shared/`** (`ScheduleSettings`, `WidgetSnapshot`) is compiled into **both** the app and the widget target, so it may only use Foundation.
- **Widget** (`SwottyWidget/`): Day Timetable and Tasks widgets. Data path is app → `WidgetSync` writes `WidgetSnapshot` JSON into the App Group container → widget reads it, falling back to Calendar (see above).
- **Services** (`Swotty/Services/`): `ReminderScheduler` (assessment notifications, including a day-of nudge with id `<uuid>-today`), `ClassReminders`, `StudyReminders` (optional revision and Sunday-summary notifications, id prefix `study-`), `CalendarSync` (EventKit: assessments as all-day events, timetable as recurring events in "Swotty Timetable"), `Insights` (pure workload/revision/quick-add parsing logic), `Haptics`. Put new logic that can be pure into a Foundation-only function with injected `now`/`calendar` so it is unit-testable in CI.
- **Design**: `Swotty/Design/Theme.swift` defines the navy and gold palette, `themedList()`/`themedScreen()`, and button styles. Use `Theme` tokens, not raw colours. Dark is the default appearance.
- **Views**: the Schedule tab is `ScheduleView` (Day/3-day/Week/Month) with `DayView` (timeline with per-class notes), `AgendaView`, `MonthCalendarView`, and `TimetableView` (editor). Settings is a grouped home (`SettingsView`) with one screen per row in `SettingsScreens.swift`.

## Tests

`SwottyTests/` holds XCTest unit tests for models and pure services (no UI tests). Date-dependent tests pass an explicit UTC `Calendar` and fixed `now` rather than using the current date.
