# Entropy — Product Plan

## Vision

**Entropy** — a single iOS app to tame the chaos of Apple Notes, scattered reminders, and mental bookkeeping. Five core pillars:

1. **Vacations** — TripIt-style trip planning with email ingestion
2. **Notes** — Categorized, folder-based notes with per-note reminders
3. **Personal Vault** — Secure storage for passports, licenses, IDs
4. **Projects** — Structured project tracking with auto-sync from local dev folders
5. **Reminders** — Cross-cutting notification engine powering all sections

---

## 1. Vacations (TripIt-style)

### Data Model

```
Trip
├── name: String                    // "Italy Summer 2026"
├── startDate: Date
├── endDate: Date
├── coverImage: Data?
├── status: TripStatus              // .planning, .booked, .inProgress, .completed
│
├── accommodations: [Accommodation]
│   ├── hotelName: String
│   ├── address: String
│   ├── checkIn / checkOut: Date
│   ├── confirmationNumber: String
│   ├── notes: String
│   └── attachments: [Attachment]   // booking PDFs, screenshots
│
├── flights: [Flight]
│   ├── airline, flightNumber
│   ├── departure / arrival (airport, dateTime)
│   ├── confirmationCode: String
│   ├── seatAssignment: String?
│   └── attachments: [Attachment]
│
├── reservations: [Reservation]     // restaurants, tours, activities
│   ├── type: ReservationType       // .restaurant, .tour, .activity, .carRental, .other
│   ├── name, location, dateTime
│   ├── confirmationNumber: String?
│   └── notes: String
│
├── itineraryDays: [ItineraryDay]   // day-by-day plan
│   ├── date: Date
│   └── items: [ItineraryItem]      // ordered list of activities/notes for that day
│
├── todoItems: [TripTodo]           // things to do before/during the trip
│   ├── title: String               // "Book seats", "Get travel insurance"
│   ├── isCompleted: Bool
│   ├── dueDate: Date?
│   └── reminder: Reminder?         // linked reminder
│
└── notes: String                   // general trip notes
```

### Key Features

- **Email ingestion**: Forward a booking confirmation email → app parses it and creates the relevant Flight, Accommodation, or Reservation. Implementation approach:
  - Dedicated email address (e.g., `trips@yourapp.com`) via a cloud function that receives inbound email (SendGrid Inbound Parse or Mailgun Routes)
  - Cloud function extracts structured data using an LLM or rule-based parser
  - Pushes parsed data to the user's account via push notification or background sync
  - Alternative: Share sheet integration — share an email from Mail.app → app parses the content directly on-device
- **Trip timeline view**: Visual day-by-day itinerary with flights, hotels, and activities on a timeline
- **Pre-trip checklist**: Auto-generated + custom todo items with reminders ("Book seats 1 week before flight")
- **Relative reminders**: "Remind me X days before [trip start / flight / checkout]"

### Screens

| Screen | Description |
|--------|-------------|
| Trip List | Cards showing upcoming/past trips with cover image, dates, countdown |
| Trip Detail | Tabbed view: Overview · Itinerary · Accommodation · Flights · Reservations · Todos |
| Add/Edit Trip | Form for trip basics |
| Add Flight/Hotel/etc. | Forms for each sub-entity |
| Email Import | Processing view when ingesting a forwarded email |

---

## 2. Notes (Categorized Folders)

### Data Model

```
NoteCategory (folder)
├── name: String                // "Work", "Tilbury", "Laguna", custom...
├── icon: String?               // SF Symbol name
├── color: String?              // accent color
├── sortOrder: Int
│
└── notes: [Note]
    ├── title: String
    ├── body: AttributedString   // rich text (bold, lists, links)
    ├── createdAt / updatedAt: Date
    ├── isPinned: Bool
    ├── tags: [String]
    ├── attachments: [Attachment] // images, PDFs
    └── reminders: [Reminder]    // multiple reminders per note
```

### Key Features

- **Default categories**: Work, Tilbury, Laguna (user-configurable)
- **Custom categories**: Add/rename/reorder/delete folders freely
- **Rich text editor**: Markdown-flavored editing (headers, bold, lists, links)
- **Per-note reminders**: Attach one or more reminders to any note with custom date/time
- **Quick capture**: Widget + share sheet for fast note creation
- **Search**: Full-text search across all notes and categories

### Screens

| Screen | Description |
|--------|-------------|
| Notes Home | Grid/list of category folders with note counts |
| Category View | List of notes within a folder, sortable by date/title/pinned |
| Note Editor | Rich text editor with reminder attachment UI |
| Category Management | Add/edit/reorder/delete categories |

---

## 3. Personal Vault

### Data Model

```
VaultItem
├── type: VaultItemType          // .passport, .driversLicense, .insurance, .medicalCard, .other
├── label: String                // "George Passport", "CA Driver's License"
├── images: [Data]               // front/back photos (encrypted at rest)
├── expirationDate: Date?        // for passport/license expiration tracking
├── notes: String
├── fields: [VaultField]         // key-value pairs (number, issuing country, etc.)
│   ├── key: String
│   └── value: String
└── reminder: Reminder?          // e.g., "Passport expires in 3 months"
```

### Key Features

- **Secure storage**: Data encrypted at rest using iOS Data Protection (NSFileProtectionComplete)
- **Biometric lock**: Face ID / Touch ID required to view vault items
- **Expiration tracking**: Auto-reminder when passport/license is approaching expiration
- **Photo capture**: Camera integration optimized for document scanning (VNDocumentCameraViewController)
- **Quick access**: Search and filter by document type

### Screens

| Screen | Description |
|--------|-------------|
| Vault Home | Grid of document cards grouped by type, blurred thumbnails until authenticated |
| Vault Item Detail | Full images + metadata, edit button |
| Add Document | Camera/photo picker + type selection + metadata fields |
| Vault Settings | Biometric toggle, auto-lock timeout |

---

## 4. Projects

### Data Model

```
Project
├── name: String                    // "Procedus App", "Entropy"
├── description: String
├── status: ProjectStatus           // .active, .paused, .completed, .archived
├── createdAt / updatedAt: Date
├── icon: String?
├── color: String?
│
├── currentStatus: String           // free-text: "Working on auth flow"
├── nextSteps: [ProjectStep]
│   ├── description: String
│   ├── isCompleted: Bool
│   ├── projectedCompletion: Date?
│   └── reminder: Reminder?
│
├── notes: [ProjectNote]            // running log of updates
│   ├── content: String
│   ├── timestamp: Date
│   └── source: NoteSource          // .manual, .autoSync
│
├── localFolderPath: String?        // "/Users/gyounis/Desktop/.../ProjectX"
├── lastSyncDate: Date?
│
└── tags: [String]
```

### Auto-Sync with Local Project Folders

This is the most technically ambitious feature. The idea: point a project at a folder on your Mac, and the app keeps `currentStatus` and `nextSteps` up to date by reading project artifacts.

**Implementation approach:**

1. **Mac companion agent** (or Claude Code hook):
   - A lightweight script/daemon that runs on the Mac
   - Watches designated project folders for changes
   - On change: reads key files (README, CHANGELOG, TODO.md, CLAUDE.md, recent git log)
   - Uses Claude API to summarize: current status, recent changes, next steps
   - Writes a structured `.project-status.json` to the folder (or syncs via iCloud/shared API)

2. **iCloud sync bridge**:
   - The Mac agent writes `.project-status.json` into an iCloud Drive folder
   - The iOS app watches that iCloud folder and ingests updates
   - Zero server infrastructure needed — piggybacks on iCloud

3. **Alternative: GitHub integration**:
   - For git-based projects, pull recent commits/PRs/issues via GitHub API
   - Auto-generate status summaries

**Sync payload format:**
```json
{
  "projectName": "Procedus",
  "folderPath": "/Users/gyounis/Desktop/.../Procedus-Unified",
  "lastUpdated": "2026-03-14T10:30:00Z",
  "currentStatus": "Testing phase — real fellow device seeding implemented",
  "recentChanges": [
    "Added TestProgramSeeder service",
    "Implemented admin dashboard improvements"
  ],
  "nextSteps": [
    "Run first test with fellow's device",
    "Implement Firebase cloud sync"
  ],
  "gitBranch": "master",
  "lastCommitMessage": "Add testing real fellow plan",
  "lastCommitDate": "2026-03-10T..."
}
```

### Key Features

- **Dashboard view**: At-a-glance status of all active projects
- **"Where was I?" recovery**: When you return to a project after weeks, see exactly what you were doing and what's next
- **Projected timeline**: Visual timeline of next steps with projected completion dates
- **Reminders**: Per-step reminders ("Check back on auth flow in 3 days")
- **Manual + auto notes**: Running log combines hand-written notes with auto-synced updates

### Screens

| Screen | Description |
|--------|-------------|
| Projects Dashboard | Cards for each project showing status badge, current status snippet, next step |
| Project Detail | Tabs: Status · Next Steps · Notes · Timeline · Settings |
| Add/Edit Project | Name, description, folder path, status |
| Sync Settings | Configure folder watching, sync frequency, iCloud folder location |

---

## 5. Reminders Engine (Cross-Cutting)

The reminder system is shared across all sections. Every section can create reminders, and they all flow through one engine.

### Data Model

```
Reminder
├── id: UUID
├── title: String
├── body: String?
├── triggerDate: Date               // absolute time to fire
├── triggerType: ReminderTriggerType
│   ├── .absolute(Date)             // "March 20, 2026 at 9am"
│   ├── .relative(TimeInterval, anchor: Date)  // "7 days before trip start"
│   └── .recurring(DateComponents)  // "Every Monday at 9am"
├── isCompleted: Bool
├── sourceType: ReminderSource      // .trip, .note, .vault, .project
├── sourceID: UUID                  // links back to the originating entity
├── notificationID: String          // UNNotification identifier for cancellation
└── createdAt: Date
```

### Implementation

- **UNUserNotificationCenter**: All reminders schedule local notifications
- **Relative reminders**: Computed at creation time. E.g., "1 week before flight" → calculate absolute date from flight departure, schedule notification
- **Recurring reminders**: Use `UNCalendarNotificationTrigger` with repeating `DateComponents`
- **Reminder management view**: Central place to see all upcoming reminders across all sections
- **Badge count**: App icon badge shows number of overdue/today reminders
- **Push notifications**: For v1, local notifications are sufficient. For cross-device sync (later), add Firebase Cloud Messaging

### Screens

| Screen | Description |
|--------|-------------|
| Reminders Hub | Chronological list of all upcoming reminders, grouped by today/this week/later |
| Add Reminder | Date/time picker, relative option ("X days before..."), recurrence picker |
| Reminder Detail | Shows linked entity (trip, note, project), edit/snooze/complete actions |

---

## Technical Architecture

### Platform & Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| **UI** | SwiftUI | Native iOS, consistent with existing Procedus expertise |
| **Data** | SwiftData | Local-first, no server dependency for core features |
| **Cloud Sync** | iCloud + CloudKit (later) | Apple-native sync for multi-device |
| **Notifications** | UNUserNotificationCenter | Local push notifications |
| **Email Parsing** | Firebase Cloud Function + LLM | Parse forwarded booking emails |
| **Project Sync** | Mac companion script + iCloud Drive | Lightweight, no custom server |
| **Security** | iOS Data Protection + Keychain | Vault encryption |
| **Auth** | Sign in with Apple (if cloud features needed) | Simple, privacy-focused |

### App Structure

```
Entropy/
├── App/
│   ├── Entropy.swift            // entry point, SwiftData schema
│   └── AppState.swift              // central state management
│
├── Models/
│   ├── Trip.swift                  // + Accommodation, Flight, Reservation, etc.
│   ├── Note.swift                  // + NoteCategory
│   ├── VaultItem.swift
│   ├── Project.swift               // + ProjectStep, ProjectNote
│   └── Reminder.swift
│
├── Services/
│   ├── ReminderEngine.swift        // notification scheduling, management
│   ├── EmailParser.swift           // booking email parsing
│   ├── ProjectSyncService.swift    // iCloud folder watching
│   ├── VaultSecurityService.swift  // biometric auth, encryption
│   └── SearchService.swift         // cross-section full-text search
│
├── Views/
│   ├── Root/
│   │   ├── MainTabView.swift       // bottom tabs: Vacations · Notes · Vault · Projects · Reminders
│   │   └── DashboardView.swift     // optional home screen with overview widgets
│   │
│   ├── Vacations/
│   │   ├── TripListView.swift
│   │   ├── TripDetailView.swift
│   │   ├── AddTripView.swift
│   │   ├── FlightDetailView.swift
│   │   ├── AccommodationDetailView.swift
│   │   └── EmailImportView.swift
│   │
│   ├── Notes/
│   │   ├── NotesHomeView.swift
│   │   ├── CategoryView.swift
│   │   ├── NoteEditorView.swift
│   │   └── CategoryManagementView.swift
│   │
│   ├── Vault/
│   │   ├── VaultHomeView.swift
│   │   ├── VaultItemDetailView.swift
│   │   └── AddDocumentView.swift
│   │
│   ├── Projects/
│   │   ├── ProjectsDashboardView.swift
│   │   ├── ProjectDetailView.swift
│   │   └── AddProjectView.swift
│   │
│   └── Reminders/
│       ├── RemindersHubView.swift
│       └── AddReminderView.swift
│
├── Components/
│   ├── ReminderPickerView.swift    // reusable reminder creation UI
│   ├── AttachmentViewer.swift
│   └── SearchBarView.swift
│
└── CloudFunctions/                 // Firebase / server-side
    └── emailIngest/                // inbound email → parsed trip data
```

### Navigation (Tab Bar)

```
┌─────────────────────────────────────────────┐
│                                             │
│            [ Active Content ]               │
│                                             │
├─────────────────────────────────────────────┤
│  ✈️ Trips  │  📝 Notes  │  🔒 Vault  │  📋 Projects  │  🔔 Reminders  │
└─────────────────────────────────────────────┘
```

---

## Build Phases

### Phase 1: Foundation (MVP)
- App shell with tab navigation
- SwiftData models for all entities
- Notes section (categories, CRUD, rich text)
- Reminders engine (local notifications, absolute + relative triggers)
- Basic Vacations (manual trip creation, accommodations, flights, todos)

### Phase 2: Vault + Projects
- Personal Vault with biometric lock and document scanning
- Projects section with manual status/next steps tracking
- Reminders integration across all sections

### Phase 3: Smart Features
- Email ingestion for trip bookings (cloud function)
- Project auto-sync via Mac companion + iCloud Drive
- Trip timeline visualization
- Full-text search across all sections

### Phase 4: Polish + Sync
- iCloud/CloudKit sync for multi-device
- Widgets (upcoming trips, today's reminders, project status)
- Share sheet integrations
- iPad layout optimization

---

## Your Specific Use Cases Mapped

| Your Need | App Section | How It Works |
|-----------|-------------|-------------|
| Trip planning with itinerary + hotel | **Vacations** → Trip Detail with accommodation, flights, itinerary tabs |
| Trip reservations | **Vacations** → Reservations (restaurants, tours, car rentals) |
| Trip reminders ("book seats 1 week before") | **Vacations** → Trip Todos with relative reminders |
| Forward booking email to app | **Vacations** → Email ingestion (like TripIt) |
| Notes about Laguna house | **Notes** → "Laguna" category folder |
| Work notes | **Notes** → "Work" category folder |
| Tilbury notes | **Notes** → "Tilbury" category folder |
| Custom note categories | **Notes** → Add any category you want |
| Reminders on specific notes | **Notes** → Per-note reminder attachment |
| Passport/license photos | **Vault** → Document cards with photo capture |
| Tracking Claude projects | **Projects** → One card per project with status + next steps |
| "Where was I?" after 2 weeks | **Projects** → Current Status + Next Steps auto-updated |
| Auto-sync from project folders | **Projects** → Mac companion script reads project files, syncs via iCloud |
| Phone notifications | **Reminders** → Local push notifications via UNUserNotificationCenter |

---

## Open Questions / Decisions Needed

1. **App name?** — This is a new app separate from Procedus/Lumenus. Working name needed.
2. **Same Xcode project or new?** — Recommend: new standalone project to keep concerns clean.
3. **iCloud sync from day one?** — Recommend: start local-only (SwiftData), add CloudKit in Phase 4.
4. **Email ingestion priority?** — This is the most complex feature. Could defer to Phase 3 and start with manual trip entry + share sheet parsing.
5. **Mac companion for project sync** — Could start with manual project updates and add auto-sync in Phase 3.
6. **iPad support?** — Recommend: design for iPhone first, iPad optimization in Phase 4.
