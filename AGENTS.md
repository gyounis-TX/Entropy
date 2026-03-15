# AGENTS.md

This file provides guidance when working with code in this repository.

## What this repo is
- iOS app: `Entropy/` (SwiftUI + SwiftData)
- Widget extension: `Entropy/Widget/` (WidgetKit)

## Common commands

### iOS app (Xcode project)
Open in Xcode:
- `open Entropy.xcodeproj`

Build from CLI (Debug):
- `xcodebuild -project Entropy.xcodeproj -scheme Entropy -configuration Debug -destination 'generic/platform=iOS Simulator' build`

Clean:
- `xcodebuild -project Entropy.xcodeproj -scheme Entropy clean`

## High-level architecture

### App entry + persistence
- `Entropy/App/EntropyApp.swift` is the app entry point.
  - Builds a SwiftData `Schema` containing core models (Trip, Note, VaultItem, Project, Reminder, Attachment, etc.).
  - Uses App Group shared container so widgets can access the same data store.
  - Handles deep links via `entropy://` URL scheme.

### Central state
- `Entropy/App/AppState.swift` is the central app state using `@Observable`.

### Data models
- `Entropy/Models/` contains SwiftData `@Model` entities: Trip, Note/NoteCategory, VaultItem/VaultField, Project, Reminder, Attachment, BookingData.

### Services
- `Entropy/Services/` contains business logic: Gmail scanning, booking parsing, vault security, reminders engine, export, search, trip checklists, project sync.

### Views
- `Entropy/Views/Root/` — MainTabView, SettingsView
- `Entropy/Views/Notes/` — Notes management
- `Entropy/Views/Vacations/` — Trip planning & booking
- `Entropy/Views/Vault/` — Secure document storage
- `Entropy/Views/Projects/` — Project tracking
- `Entropy/Views/Reminders/` — Reminders hub

### Components
- `Entropy/Components/` — Reusable UI components (MarkdownEditor, AttachmentViewer, SearchBar, etc.)

### Widgets
- `Entropy/Widget/` — WidgetKit extension with Quick Capture, Upcoming Trips, and Reminders widgets.
- `Entropy/Widget/SharedModelContainer.swift` — Shared SwiftData container for widget data access.
