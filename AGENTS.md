# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## What this repo is
- iOS app: `Procedus/` (SwiftUI + SwiftData)
- Firebase Cloud Functions: `Procedus/functions/` (Node)

## Common commands

### iOS app (Xcode project)
Open in Xcode:
- `open Procedus.xcodeproj`

Inspect schemes/targets:
- `xcodebuild -list -project Procedus.xcodeproj`
  - Current scheme: `Procedus`

Build from CLI (Debug):
- `xcodebuild -project Procedus.xcodeproj -scheme Procedus -configuration Debug -destination 'generic/platform=iOS Simulator' build`

Clean:
- `xcodebuild -project Procedus.xcodeproj -scheme Procedus clean`

Tests:
- No dedicated XCTest target is listed by `xcodebuild -list` right now.
- If/when a test target exists, run all tests with:
  - `xcodebuild -project Procedus.xcodeproj -scheme Procedus -destination 'generic/platform=iOS Simulator' test`
- If/when you need to run a single XCTest (example pattern):
  - `xcodebuild ... test -only-testing:<TestTargetName>/<TestClassName>/<testMethodName>`

### Firebase Cloud Functions (`Procedus/functions`)
Install deps:
- `cd Procedus/functions && npm install`

Lint (this is also run via `firebase.json` predeploy):
- `cd Procedus/functions && npm run lint`

Run emulator for functions:
- `cd Procedus/functions && npm run serve`

Deploy functions:
- `cd Procedus/functions && npm run deploy`

View function logs:
- `cd Procedus/functions && npm run logs`

Notes:
- `Procedus/functions/package.json` pins Node via `"engines": { "node": "24" }`.
- `Procedus/functions/index.js` currently contains scaffolding (no exported triggers yet).

## High-level architecture

### App entry + persistence
- `Procedus/ProcedusApp.swift` is the app entry point.
  - Builds a SwiftData `Schema` containing core models (e.g. `User`, `CaseEntry`, `Program`, `Attending`, `TrainingFacility`, attestation/evaluation entities, notifications, media, duty hours, etc.).
  - Configures shared services against the SwiftData main context (`AuditService`, `NotificationManager`, `UserDeletionService`, `SearchTermService`).
  - Runs `EvaluationMigrationService.migrateIfNeeded(...)` during startup.

### Navigation + mode/role routing
- `Procedus/Views/Shared/RootView.swift` is the root router.
  - Onboarding gate: `appState.hasCompletedOnboarding` decides whether to show onboarding vs main UI.
  - Two “modes”:
    - Individual mode (no institutional role selection)
    - Institutional mode (role-based UI: fellow / attending / admin)
  - Role selection fans out to different `TabView` setups.
  - Wrapper views (`FellowContentWrapper`, `AttendingContentWrapper`, `AdminContentWrapper`) implement a shared top bar pattern (notifications + settings, plus log actions for fellows).

### Central state
- `Procedus/Services/AppState.swift` is the central app state.
  - Uses `@Observable` and persists user choices in `UserDefaults` (onboarding state, selected identity IDs, enabled specialty packs, individual profile fields, etc.).
  - Owns “mode” (`accountMode`) and “role” (`userRole`) interpretation.
  - Includes DEBUG-only dev sign-in helpers used by onboarding (`devSignIn(...)`).

### Data model layer
- `Procedus/Models/Models.swift` holds the SwiftData `@Model` entities.
  - The core entity is `CaseEntry` (procedure tags, facilities/attendings, attestation status, evaluations, notes, migration flags, etc.).
  - `Program` and `User` model institutional programs/roles; invite codes are generated on `Program`.

### Domain services
- `Procedus/Services/` contains most non-UI logic (examples: duty hours compliance, exports/imports, network monitoring, notifications, redaction/PHI detection, media storage, migrations).
  - When debugging a UI issue, check whether the view is directly manipulating SwiftData models vs delegating to a service.

### Procedure catalogs (“specialty packs”)
- `Procedus/Catalogs/` contains catalogs and helpers (e.g. `SpecialtyPackCatalog.swift`).
- `AppState.enabledSpecialtyPackIds` controls which packs are active; onboarding/individual setup can auto-enable packs based on the selected specialty.

### Recent large feature drops
- `Procedus/HANDOFF_V7_UPDATE.md` describes a major admin + attending implementation update (build date January 18, 2026) and calls out the largest files/views (notably `AdminDashboardView.swift` and `AttestationQueueView.swift`) plus key workflows (attestation, evaluations, exports).