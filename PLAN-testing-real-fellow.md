# Testing Phase: Real Fellow on Her Own Device

## The Problem

SwiftData is local-only. The fellow's device starts with an empty database — no Program, no Users, no invite codes. The invite code system only matches against local data. We need a **bootstrap mechanism** to seed the fellowship program data onto her device before she can onboard.

## Files to Create / Modify

| File | Action | Purpose |
|------|--------|---------|
| `Procedus/Services/TestProgramSeeder.swift` | **Create** | Standalone service to seed a test program with known invite codes, users, attendings, facilities, and sample cases |
| `Procedus/ProcedusApp.swift` | Modify | Add auto-seed on first launch (DEBUG builds) |
| `Procedus/Views/Shared/RootView.swift` | Modify | Add hidden seed trigger on OnboardingView for TestFlight builds |

Base path: `/Users/gyounis/Desktop/LUMEN INNOVATIONS DEVLOPMENT FOLDER/Procedus-Unified/Procedus U/`

---

## Architecture Overview

### Current Flow (same device)
```
Admin populates program → Fellow selects identity → Uses app
          ↑ all on one device (shared SwiftData)
```

### New Flow (fellow's own device)
```
App auto-seeds program on first launch (DEBUG)
       ↓
Fellow opens app → Onboarding → "Join Institution"
       ↓
Enters known invite code "FELL01"
       ↓
Selects her pre-created identity
       ↓
Full app access with test data
```

---

## Step 1: Create `TestProgramSeeder` Service

A standalone static service that creates a ready-to-use fellowship program. Extracted from the existing `populateDevProgram()` pattern in AdminDashboardView but lighter-weight and reusable.

### What It Creates

**Program:**
- Name: "Springfield Cardiology Fellowship" (or configurable)
- Institution: "Springfield Medical Center"
- Specialty: Cardiology (3 packs: IC, EP, Cardiac Imaging)
- **Known invite codes** (hardcoded, memorable):
  - Fellow: `"FELL01"`
  - Attending: `"ATTN01"`
  - Admin: `"ADMN01"`

**Users (Fellows):**
- **The real fellow** — parameterized name/email/PGY (passed in or configured via a constant)
- Lisa Simpson — PGY-4 (test peer with sample cases)
- Maggie Simpson — PGY-5 (test peer with sample cases)

**Users (Admin):**
- Cindy Crabapple — admin account (for admin testing if needed)

**Attendings:**
- Dr. Nick Riviera
- Ned Flanders
- Moe Szyslak
- Apu Nahasapeemapetilon

**Facilities:**
- University Hospital (UH)
- Outpatient Lab (OPL)

**Evaluation Fields:**
- 5 default evaluation fields (Procedural Competence, Clinical Judgment, Documentation, Professionalism, Communication)

**Sample Cases (for peer fellows only, NOT for the real fellow):**
- ~20-30 cases each for Lisa and Maggie with realistic procedures
- Mixed attestation statuses (90% attested, 10% pending)
- The real fellow starts with an empty case log so she can test adding her own cases

### Key Design Decisions

1. **Idempotent**: Check `UserDefaults.standard.bool(forKey: "testProgramSeeded")` before seeding. Skip if already seeded.
2. **Real fellow starts clean**: No pre-populated cases for her — she tests the full case-creation flow.
3. **Known invite codes**: Hardcoded so they can be shared verbally or via text. Not randomly generated.
4. **Configurable real fellow**: Define her details as constants at the top of the seeder so they're easy to change.

### API

```swift
struct TestProgramSeeder {
    /// The real fellow's details (configure before building)
    static let realFellowFirstName = "Sarah"  // CHANGE THIS
    static let realFellowLastName = "Johnson"  // CHANGE THIS
    static let realFellowEmail = "sarah@example.com"  // CHANGE THIS
    static let realFellowPGY = 4  // CHANGE THIS

    /// Known invite codes
    static let fellowInviteCode = "FELL01"
    static let attendingInviteCode = "ATTN01"
    static let adminInviteCode = "ADMN01"

    /// Seeds the test program if not already seeded
    static func seedIfNeeded(modelContext: ModelContext)

    /// Forces a re-seed (deletes existing test data first)
    static func reseed(modelContext: ModelContext)
}
```

---

## Step 2: Auto-Seed on First Launch (DEBUG Builds)

In `ProcedusApp.swift`, add auto-seed logic in the app's init or `.onAppear`:

```swift
#if DEBUG
.onAppear {
    TestProgramSeeder.seedIfNeeded(modelContext: modelContext)
}
#endif
```

This runs once (guarded by UserDefaults flag). After seeding, the fellow sees the normal onboarding screen with the populated database behind it.

---

## Step 3: Hidden Seed Trigger for TestFlight (Optional, for later)

If we later distribute via TestFlight (Release build), add a hidden trigger on the `OnboardingView`:

- **Trigger**: 5 rapid taps on the Procedus logo
- **Action**: Shows a confirmation alert "Set up test program?"
- **On confirm**: Calls `TestProgramSeeder.seedIfNeeded(modelContext:)`
- **After seed**: Shows brief "Test program ready. Use code FELL01 to join." message

This would be behind a `#if BETA` or a runtime flag, NOT `#if DEBUG` (which is stripped in Release).

**Note**: This step is optional for initial testing. If the fellow can come in with her device for an Xcode direct install, `#if DEBUG` auto-seed is sufficient.

---

## Step 4: Fellow's Testing Walkthrough

### First Launch (what she sees)
1. App opens → **OnboardingView**: "Welcome to Lumenus"
2. Two buttons: "Individual Mode" and "Join Institution"
3. She taps **"Join Institution"**

### Joining the Program
4. **InstitutionalSetupView**: Enter invite code field
5. She enters `FELL01`
6. App finds the matching program → shows **RoleSetupView**
7. She sees "Springfield Cardiology Fellowship" + "Fellow" badge
8. **"Select Your Account"** section lists her pre-created account
9. She selects her name → taps **"Complete Setup"**

### Testing Full Functionality
10. She lands on the **Fellow Dashboard** (Case Log tab)
11. Test areas:

| Feature | What to Test |
|---------|-------------|
| **Case Log** | Add a new case, select procedures from IC/EP/Imaging packs, pick attending, facility, access site, complications |
| **Procedure Import** | Import a CSV procedure log (all 8 improvements we built) |
| **Images** | Attach images to cases, share to Teaching Files |
| **Analytics** | View procedure counts, charts, progress toward milestones |
| **Duty Hours** | Log shifts, view weekly totals, check compliance |
| **Settings** | View profile, specialty packs, default facility, attendings list |
| **Notifications** | Case logging reminders, attestation status alerts |
| **Attestation** | After logging a case, check if it appears in pending queue (she won't see the attending view, but cases should be pending) |

---

## Step 5: Verifying Admin Side (Developer Device)

While the fellow tests, the developer can:
1. Install the same DEBUG build on their own device
2. Auto-seed creates the same program (with same invite codes)
3. Onboard as admin using `ADMN01`
4. Or use dev mode "Sign in as Admin" button
5. View the fellow's cases in the admin dashboard (on the developer's device these won't sync — this is purely for testing the admin UI with the peer fellows' seeded data)

**Important limitation**: Since SwiftData is local, the developer's admin device and the fellow's device have **separate databases**. The fellow's cases won't appear on the admin device. This is a known architectural constraint of the local-only data model.

---

## Implementation Details

### TestProgramSeeder.swift Structure

```swift
import SwiftData
import Foundation

struct TestProgramSeeder {
    // Configuration constants at top
    // ...

    static func seedIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: "testProgramSeeded") else { return }

        // 1. Create Program with known invite codes
        // 2. Create admin user
        // 3. Create attendings (4 active)
        // 4. Create facilities (2)
        // 5. Create fellows (real fellow + 2 test peers)
        // 6. Create evaluation fields (5)
        // 7. Create sample cases for peer fellows (NOT the real fellow)
        // 8. Save and mark as seeded

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: "testProgramSeeded")
    }

    static func reseed(modelContext: ModelContext) {
        // Delete all existing test data
        // Reset UserDefaults flag
        // Call seedIfNeeded()
    }
}
```

### Sample Case Creation (for peers)

Reuse patterns from existing `populateDevProgram()`:
- IC procedures: LHC, coronary angiography, PCI, IVUS
- EP procedures: ablation, device implant
- Imaging: TTE, TEE
- 90% attested with random evaluations (3-5 ratings), 10% pending
- Round-robin attending distribution
- Dates spread over the last 6-12 months

### ProcedusApp.swift Change

Add one block inside the `WindowGroup` body or a `.task {}` modifier:

```swift
#if DEBUG
.task {
    TestProgramSeeder.seedIfNeeded(modelContext: modelContext)
}
#endif
```

### RootView.swift Change (for TestFlight, optional)

Add tap gesture on the Procedus logo in OnboardingView:

```swift
Image(systemName: "doc.badge.arrow.up")  // or whatever the logo is
    .onTapGesture(count: 5) {
        showTestSeedAlert = true
    }
```

---

## Distribution Plan

### Option A: Xcode Direct Install (Recommended for initial testing)
1. Add the fellow's device UDID to the development provisioning profile
2. Connect her device or use wireless debugging
3. Build & run the DEBUG scheme directly to her device
4. App auto-seeds, she onboards with `FELL01`
5. **Pros**: Simplest, DEBUG features available, auto-seed works
6. **Cons**: Requires physical access to device (or she must be nearby)

### Option B: TestFlight (For remote/ongoing testing)
1. Implement the hidden seed trigger (not behind `#if DEBUG`)
2. Archive with Release config, upload to App Store Connect
3. Add fellow as TestFlight tester
4. She installs, uses hidden trigger, then onboards
5. **Pros**: Remote distribution, closer to production behavior
6. **Cons**: Requires hidden trigger code, no DEBUG features

### Recommendation
Start with **Option A** for the first testing session. Move to Option B once the core flow is validated.

---

## Verification Checklist

After implementation, verify on a fresh device (or after deleting the app):

- [ ] App launches → auto-seeds → onboarding screen appears
- [ ] "Join Institution" → enter `FELL01` → program found
- [ ] Real fellow's name appears in identity selection
- [ ] Select identity → lands on Fellow Dashboard
- [ ] Case Log tab shows empty state (no pre-populated cases for real fellow)
- [ ] Can add a new case (procedure picker works with IC/EP/Imaging packs)
- [ ] Can select attending from seeded list (Dr. Nick, Ned, Moe, Apu)
- [ ] Can select facility (University Hospital, Outpatient Lab)
- [ ] Analytics tab loads (empty initially)
- [ ] Duty Hours tab loads
- [ ] Settings shows correct profile, specialty packs, attendings
- [ ] Images tab works
- [ ] Import procedure log works (all 8 improvements)
- [ ] Peer fellows (Lisa, Maggie) have sample cases visible in admin context
