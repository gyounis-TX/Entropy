// TestProgramSeeder.swift
// Procedus - Unified
// Seeds a test fellowship program for real fellow testing on a fresh device.
// Mirrors the data created by populateDevProgram() in AdminDashboardView.

#if DEBUG
import Foundation
import SwiftData
import UIKit

struct TestProgramSeeder {

    // MARK: - Real Fellow Configuration

    static let realFellowFirstName = "Pakinam"
    static let realFellowLastName = "Mekki"
    static let realFellowEmail = "pakinam@gmail.com"
    static let realFellowPGY = 5

    // MARK: - Known Invite Codes

    static let fellowInviteCode = "FELL01"
    static let attendingInviteCode = "ATTN01"
    static let adminInviteCode = "ADMN01"

    // MARK: - UserDefaults Key

    private static let seededKey = "testProgramSeeded"

    // MARK: - Public API

    static func seedIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        seed(modelContext: modelContext)
    }

    static func reseed(modelContext: ModelContext) {
        UserDefaults.standard.set(false, forKey: seededKey)
        try? modelContext.delete(model: CaseEntry.self)
        try? modelContext.delete(model: CaseMedia.self)
        try? modelContext.delete(model: MediaComment.self)
        try? modelContext.delete(model: User.self)
        try? modelContext.delete(model: Attending.self)
        try? modelContext.delete(model: TrainingFacility.self)
        try? modelContext.delete(model: EvaluationField.self)
        try? modelContext.delete(model: DutyHoursEntry.self)
        try? modelContext.delete(model: DutyHoursShift.self)
        try? modelContext.delete(model: BadgeEarned.self)
        try? modelContext.delete(model: Program.self)
        try? modelContext.save()
        seed(modelContext: modelContext)
    }

    // MARK: - Seed Implementation

    private static func seed(modelContext: ModelContext) {
        let calendar = Calendar.current

        // =============================================
        // 1. PROGRAM
        // =============================================
        let program = Program(
            programCode: Program.generateProgramCode(),
            name: "Springfield Cardiology Fellowship",
            institutionName: "Springfield Medical Center",
            specialtyPackIds: [
                "interventional-cardiology",
                "electrophysiology",
                "cardiac-imaging"
            ]
        )
        program.fellowInviteCode = fellowInviteCode
        program.attendingInviteCode = attendingInviteCode
        program.adminInviteCode = adminInviteCode
        program.fellowshipSpecialty = .cardiology
        program.evaluationsEnabled = true
        program.evaluationsRequired = true
        program.dutyHoursEnabled = true
        modelContext.insert(program)

        // =============================================
        // 2. ADMINS
        // =============================================
        let adminData = [
            ("Cindy", "Crabapple", "crabapple@springfield.com"),
            ("Lionel", "Hutz", "hutz@springfield.com")
        ]
        for (first, last, email) in adminData {
            let admin = User(email: email, firstName: first, lastName: last, role: .admin, accountMode: .institutional, programId: program.id)
            modelContext.insert(admin)
        }

        // =============================================
        // 3. ATTENDINGS (active)
        // =============================================
        var attendingIds: [UUID] = []
        let attendingInfo: [(first: String, last: String, email: String)] = [
            ("Dr. Nick", "Riviera", "drnick@springfield.com"),
            ("Ned", "Flanders", "ned@springfield.com"),
            ("Moe", "Szyslak", "moe@springfield.com"),
            ("Apu", "Nahasapeemapetilon", "apu@springfield.com")
        ]
        for (first, last, email) in attendingInfo {
            let attending = Attending(firstName: first, lastName: last)
            attending.programId = program.id
            modelContext.insert(attending)
            attendingIds.append(attending.id)

            let user = User(email: email, firstName: first, lastName: last, role: .attending, accountMode: .institutional, programId: program.id)
            modelContext.insert(user)
            attending.userId = user.id
        }

        // Archived attendings (for historical cases)
        var archivedAttendingIds: [UUID] = []
        let archivedAttendingInfo = [
            ("Leo", "Simpson", "leo@springfield.com"),
            ("Homer", "Simpson", "homer@springfield.com")
        ]
        for (first, last, email) in archivedAttendingInfo {
            let attending = Attending(firstName: first, lastName: last)
            attending.programId = program.id
            attending.isArchived = true
            modelContext.insert(attending)
            archivedAttendingIds.append(attending.id)

            let user = User(email: email, firstName: first, lastName: last, role: .attending, accountMode: .institutional, programId: program.id)
            user.isArchived = true
            modelContext.insert(user)
            attending.userId = user.id
        }

        // =============================================
        // 4. FACILITIES
        // =============================================
        var facilityIds: [UUID] = []
        for (name, shortName) in [("University Hospital", "UH"), ("Outpatient Lab", "OPL")] {
            let facility = TrainingFacility(name: name)
            facility.shortName = shortName
            facility.programId = program.id
            modelContext.insert(facility)
            facilityIds.append(facility.id)
        }

        // =============================================
        // 5. EVALUATION FIELDS
        // =============================================
        var evaluationFieldIds: [UUID] = []
        let defaultFields: [(String, String)] = [
            ("Procedural Competence", "Technical skill execution and equipment handling."),
            ("Clinical Judgment", "Patient selection and complication recognition."),
            ("Documentation", "Accurate and complete procedure documentation."),
            ("Professionalism", "Communication with team and patients."),
            ("Communication", "Clear handoffs and patient education.")
        ]
        for (i, (title, desc)) in defaultFields.enumerated() {
            let field = EvaluationField(title: title, descriptionText: desc, fieldType: .rating, isRequired: true, displayOrder: i, programId: program.id, isDefault: true)
            modelContext.insert(field)
            evaluationFieldIds.append(field.id)
        }

        // =============================================
        // 6. FELLOWS
        // =============================================

        // Real fellow (empty case log)
        let realFellow = User(email: realFellowEmail, firstName: realFellowFirstName, lastName: realFellowLastName, role: .fellow, accountMode: .institutional, programId: program.id, trainingYear: realFellowPGY)
        modelContext.insert(realFellow)

        // Active peers
        var activeFellowIds: [UUID] = []
        let activeFellowData: [(first: String, last: String, email: String, pgy: Int)] = [
            ("Lisa", "Simpson", "lisa@springfield.com", 4),
            ("Maggie", "Simpson", "maggie@springfield.com", 5),
            ("Bart", "Simpson", "bart@springfield.com", 6)
        ]
        for (first, last, email, pgy) in activeFellowData {
            let fellow = User(email: email, firstName: first, lastName: last, role: .fellow, accountMode: .institutional, programId: program.id, trainingYear: pgy)
            modelContext.insert(fellow)
            activeFellowIds.append(fellow.id)
        }

        // Graduated peers
        var graduatedFellowIds: [UUID] = []
        let graduatedFellowData: [(first: String, last: String, email: String)] = [
            ("Seymour", "Skinner", "skinner@springfield.com"),
            ("Groundskeeper", "Willie", "willie@springfield.com"),
            ("Milhouse", "VanHouten", "milhouse@springfield.com")
        ]
        for (first, last, email) in graduatedFellowData {
            let fellow = User(email: email, firstName: first, lastName: last, role: .fellow, accountMode: .institutional, programId: program.id, trainingYear: 6)
            fellow.hasGraduated = true
            fellow.graduatedAt = calendar.date(byAdding: .month, value: -6, to: Date())
            modelContext.insert(fellow)
            graduatedFellowIds.append(fellow.id)
        }

        try? modelContext.save()

        // =============================================
        // 7. CASE CREATION HELPERS
        // =============================================
        var attendingRoundRobin = 0
        func nextAttendingId() -> UUID {
            let id = attendingIds[attendingRoundRobin % attendingIds.count]
            attendingRoundRobin += 1
            return id
        }

        let cathNotes = ["Diagnostic cath, normal coronaries.", "Moderate disease, medical management.", "Severe 3VD, referred to surgery."]
        let pciNotes = ["Successful PCI with DES.", "Complex intervention, good result.", "Elective PCI, no complications."]
        let echoNotes = ["TTE showing preserved EF.", "Stress echo negative for ischemia.", "TEE for structural assessment."]
        let epNotes = ["EP study completed.", "Successful ablation.", "Device implant, good parameters."]

        let pciComplications = ["Bleeding", "Vascular Injury", "Hematoma", "MI", "Arrhythmia", "Renal/AKI", "Stroke/TIA"]
        let cathComplications = ["Bleeding", "Vascular Injury", "Hematoma", "Renal/AKI", "Allergic Reaction"]
        let epAblationComplications = ["Tamponade", "Stroke/TIA", "Arrhythmia", "Vascular Injury", "Bleeding", "Hematoma"]
        let epDeviceComplications = ["Pneumothorax", "Infection", "Hematoma", "Bleeding", "Arrhythmia"]

        func maybeComplications(from pool: [String]) -> [String] {
            Int.random(in: 1...100) <= 5 ? Array(pool.shuffled().prefix(Int.random(in: 1...2))) : []
        }

        func randomICAccess() -> [String] { Int.random(in: 1...10) <= 7 ? ["Radial"] : ["Femoral"] }
        func randomEPAblationAccess() -> [String] { Int.random(in: 1...10) <= 8 ? ["Femoral"] : ["Femoral", "Jugular"] }
        func randomEPDeviceAccess() -> [String] { [["Subclavian"], ["Axillary"], ["Subclavian", "Jugular"]].randomElement()! }

        func createCase(
            fellowId: UUID,
            procedureIds: [String],
            caseDate: Date,
            caseType: CaseType,
            notes: String,
            accessSites: [String] = [],
            complications: [String] = [],
            isPending: Bool = false,
            useArchivedAttending: Bool = false
        ) {
            let weekBucket = CaseEntry.makeWeekBucket(for: caseDate)
            let attendingId: UUID
            if useArchivedAttending && !archivedAttendingIds.isEmpty {
                attendingId = Int.random(in: 0..<10) < 7 ? archivedAttendingIds.randomElement()! : nextAttendingId()
            } else {
                attendingId = nextAttendingId()
            }

            let newCase = CaseEntry(fellowId: fellowId, ownerId: fellowId, attendingId: attendingId, weekBucket: weekBucket, facilityId: facilityIds.randomElement())
            newCase.programId = program.id
            newCase.procedureTagIds = procedureIds
            newCase.createdAt = caseDate
            newCase.caseTypeRaw = caseType.rawValue
            newCase.notes = notes
            newCase.accessSiteIds = accessSites
            newCase.complicationIds = complications
            newCase.operatorPositionRaw = OperatorPosition.primary.rawValue

            if isPending {
                newCase.attestationStatusRaw = AttestationStatus.pending.rawValue
            } else {
                newCase.attestationStatusRaw = AttestationStatus.attested.rawValue
                newCase.attestedAt = caseDate.addingTimeInterval(3600)
                newCase.attestorId = attendingId
                var evalResponses: [String: String] = [:]
                for fieldId in evaluationFieldIds {
                    evalResponses[fieldId.uuidString] = String(Int.random(in: 3...5))
                }
                if let data = try? JSONEncoder().encode(evalResponses), let json = String(data: data, encoding: .utf8) {
                    newCase.evaluationResponsesJson = json
                }
            }
            modelContext.insert(newCase)
        }

        // =============================================
        // 8. ACTIVE FELLOW CASES
        // =============================================

        // --- Lisa (PGY4): Beginner, 3 months ---
        let lisaId = activeFellowIds[0]
        for i in 0..<15 {
            let d = calendar.date(byAdding: .weekOfYear, value: -(i / 2), to: Date()) ?? Date()
            createCase(fellowId: lisaId, procedureIds: ["ic-dx-lhc", "ic-dx-coro"], caseDate: d, caseType: .invasive, notes: cathNotes.randomElement()!, accessSites: randomICAccess(), complications: maybeComplications(from: cathComplications), isPending: i < 1)
        }
        for i in 0..<5 {
            let d = calendar.date(byAdding: .weekOfYear, value: -i, to: Date()) ?? Date()
            createCase(fellowId: lisaId, procedureIds: ["ic-pci-stent"], caseDate: d, caseType: .invasive, notes: pciNotes.randomElement()!, accessSites: randomICAccess(), complications: maybeComplications(from: pciComplications))
        }
        for i in 0..<20 {
            let d = calendar.date(byAdding: .weekOfYear, value: -(i / 3), to: Date()) ?? Date()
            createCase(fellowId: lisaId, procedureIds: [i % 2 == 0 ? "ci-echo-tte" : "ci-echo-stress"], caseDate: d, caseType: .noninvasive, notes: echoNotes.randomElement()!, isPending: i < 1)
        }

        // --- Maggie (PGY5): 249 PCI, 15 months ---
        let maggieId = activeFellowIds[1]
        for i in 0..<249 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i / 4, 65), to: Date()) ?? Date()
            let procId = i % 5 == 0 ? "ic-pci-rotablator" : (i % 3 == 0 ? "ic-pci-dcb" : "ic-pci-stent")
            createCase(fellowId: maggieId, procedureIds: [procId], caseDate: d, caseType: .invasive, notes: pciNotes.randomElement()!, accessSites: randomICAccess(), complications: maybeComplications(from: pciComplications), isPending: i < 12)
        }
        for i in 0..<200 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i / 4, 65), to: Date()) ?? Date()
            createCase(fellowId: maggieId, procedureIds: ["ic-dx-lhc", "ic-dx-coro"], caseDate: d, caseType: .invasive, notes: cathNotes.randomElement()!, accessSites: randomICAccess(), complications: maybeComplications(from: cathComplications))
        }
        for i in 0..<150 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i / 3, 65), to: Date()) ?? Date()
            createCase(fellowId: maggieId, procedureIds: ["ci-echo-tte"], caseDate: d, caseType: .noninvasive, notes: echoNotes.randomElement()!)
        }
        for i in 0..<50 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i / 2, 65), to: Date()) ?? Date()
            createCase(fellowId: maggieId, procedureIds: ["ci-echo-tee"], caseDate: d, caseType: .noninvasive, notes: "TEE for procedure guidance.")
        }
        for i in 0..<30 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i * 2, 65), to: Date()) ?? Date()
            let procId = ["ep-dev-ppm-dp", "ep-abl-svt", "ep-dx-eps"].randomElement()!
            let isDevice = procId.contains("dev")
            createCase(fellowId: maggieId, procedureIds: [procId], caseDate: d, caseType: .invasive, notes: epNotes.randomElement()!, accessSites: isDevice ? randomEPDeviceAccess() : randomEPAblationAccess(), complications: maybeComplications(from: isDevice ? epDeviceComplications : epAblationComplications))
        }

        // --- Bart (PGY6): 249 PCI, 27 months ---
        let bartId = activeFellowIds[2]
        for i in 0..<249 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i / 3, 117), to: Date()) ?? Date()
            let procId = ["ic-pci-stent", "ic-pci-dcb", "ic-pci-rotablator", "ic-pci-ivl"].randomElement()!
            createCase(fellowId: bartId, procedureIds: [procId], caseDate: d, caseType: .invasive, notes: pciNotes.randomElement()!, accessSites: randomICAccess(), complications: maybeComplications(from: pciComplications), isPending: i < 12, useArchivedAttending: i > 200)
        }
        for i in 0..<250 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i / 3, 117), to: Date()) ?? Date()
            createCase(fellowId: bartId, procedureIds: ["ic-dx-lhc", "ic-dx-coro"], caseDate: d, caseType: .invasive, notes: cathNotes.randomElement()!, accessSites: randomICAccess(), complications: maybeComplications(from: cathComplications), useArchivedAttending: i > 200)
        }
        for i in 0..<200 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i / 3, 117), to: Date()) ?? Date()
            createCase(fellowId: bartId, procedureIds: ["ci-echo-tte"], caseDate: d, caseType: .noninvasive, notes: echoNotes.randomElement()!)
        }
        for i in 0..<60 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i * 2, 117), to: Date()) ?? Date()
            createCase(fellowId: bartId, procedureIds: ["ci-echo-tee"], caseDate: d, caseType: .noninvasive, notes: "TEE for structural guidance.")
        }

        // =============================================
        // 9. GRADUATED FELLOW CASES
        // =============================================

        // Skinner — EP Specialist
        let skinnerId = graduatedFellowIds[0]
        for i in 0..<150 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i / 2, 156), to: Date()) ?? Date()
            let procId = ["ep-abl-pvi", "ep-abl-svt", "ep-abl-cti", "ep-abl-avnrt", "ep-abl-vt-idio"].randomElement()!
            createCase(fellowId: skinnerId, procedureIds: [procId], caseDate: d, caseType: .invasive, notes: "Successful ablation procedure.", accessSites: randomEPAblationAccess(), complications: maybeComplications(from: epAblationComplications), useArchivedAttending: i > 120)
        }
        for i in 0..<80 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i, 156), to: Date()) ?? Date()
            let procId = ["ep-dev-ppm-dp", "ep-dev-icd", "ep-dev-crt-d", "ep-dev-leadless"].randomElement()!
            createCase(fellowId: skinnerId, procedureIds: [procId], caseDate: d, caseType: .invasive, notes: "Device implant, good parameters.", accessSites: randomEPDeviceAccess(), complications: maybeComplications(from: epDeviceComplications))
        }
        for i in 0..<150 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i / 2, 156), to: Date()) ?? Date()
            createCase(fellowId: skinnerId, procedureIds: ["ci-echo-tte"], caseDate: d, caseType: .noninvasive, notes: echoNotes.randomElement()!)
        }
        for i in 0..<50 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i * 3, 156), to: Date()) ?? Date()
            createCase(fellowId: skinnerId, procedureIds: ["ci-echo-tee"], caseDate: d, caseType: .noninvasive, notes: "TEE for device guidance.")
        }
        for i in 0..<100 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i, 156), to: Date()) ?? Date()
            createCase(fellowId: skinnerId, procedureIds: ["ic-dx-lhc"], caseDate: d, caseType: .invasive, notes: cathNotes.randomElement()!, accessSites: randomICAccess(), complications: maybeComplications(from: cathComplications))
        }

        // Willie — Coronary Intervention Specialist
        let willieId = graduatedFellowIds[1]
        for i in 0..<280 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i / 3, 156), to: Date()) ?? Date()
            let procId = ["ic-pci-stent", "ic-pci-rotablator", "ic-pci-ivl", "ic-pci-dcb"].randomElement()!
            createCase(fellowId: willieId, procedureIds: [procId], caseDate: d, caseType: .invasive, notes: pciNotes.randomElement()!, accessSites: randomICAccess(), complications: maybeComplications(from: pciComplications), useArchivedAttending: i > 240)
        }
        for i in 0..<300 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i / 3, 156), to: Date()) ?? Date()
            createCase(fellowId: willieId, procedureIds: ["ic-dx-lhc", "ic-dx-coro"], caseDate: d, caseType: .invasive, notes: cathNotes.randomElement()!, accessSites: randomICAccess(), complications: maybeComplications(from: cathComplications))
        }
        for i in 0..<150 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i / 2, 156), to: Date()) ?? Date()
            createCase(fellowId: willieId, procedureIds: ["ci-echo-tte"], caseDate: d, caseType: .noninvasive, notes: echoNotes.randomElement()!)
        }
        for i in 0..<50 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i * 3, 156), to: Date()) ?? Date()
            createCase(fellowId: willieId, procedureIds: ["ci-echo-tee"], caseDate: d, caseType: .noninvasive, notes: "TEE for PCI guidance.")
        }

        // Milhouse — Noninvasive Specialist
        let milhouseId = graduatedFellowIds[2]
        for i in 0..<400 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i / 4, 156), to: Date()) ?? Date()
            createCase(fellowId: milhouseId, procedureIds: ["ci-echo-tte"], caseDate: d, caseType: .noninvasive, notes: echoNotes.randomElement()!)
        }
        for i in 0..<100 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i, 156), to: Date()) ?? Date()
            createCase(fellowId: milhouseId, procedureIds: ["ci-echo-tee"], caseDate: d, caseType: .noninvasive, notes: "TEE structural assessment.")
        }
        for i in 0..<100 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i, 156), to: Date()) ?? Date()
            createCase(fellowId: milhouseId, procedureIds: ["ci-echo-stress"], caseDate: d, caseType: .noninvasive, notes: "Stress echo negative.")
        }
        for i in 0..<120 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i, 156), to: Date()) ?? Date()
            let procId = ["ci-nuc-spect", "ci-nuc-pet", "ci-ct-cta"].randomElement()!
            createCase(fellowId: milhouseId, procedureIds: [procId], caseDate: d, caseType: .noninvasive, notes: "Advanced imaging study.")
        }
        for i in 0..<100 {
            let d = calendar.date(byAdding: .weekOfYear, value: -min(i, 156), to: Date()) ?? Date()
            createCase(fellowId: milhouseId, procedureIds: ["ic-dx-lhc"], caseDate: d, caseType: .invasive, notes: cathNotes.randomElement()!, accessSites: randomICAccess(), complications: maybeComplications(from: cathComplications))
        }

        // =============================================
        // 10. DUTY HOURS
        // =============================================
        func academicYearStart(for pgyLevel: Int) -> Date {
            let now = Date()
            let currentYear = calendar.component(.year, from: now)
            let currentMonth = calendar.component(.month, from: now)
            let fellowshipYears = pgyLevel - 4
            let academicStartYear = currentMonth >= 7 ? currentYear - fellowshipYears : currentYear - 1 - fellowshipYears
            var components = DateComponents()
            components.year = academicStartYear
            components.month = 7
            components.day = 1
            return calendar.date(from: components) ?? now
        }

        func weeksSince(_ startDate: Date) -> Int {
            max(0, calendar.dateComponents([.weekOfYear], from: startDate, to: Date()).weekOfYear ?? 0)
        }

        let activePGYLevels = [4, 5, 6]
        for (index, fellowId) in activeFellowIds.enumerated() {
            let startDate = academicYearStart(for: activePGYLevels[index])
            let weeksInFellowship = weeksSince(startDate)

            for weekOffset in 0..<weeksInFellowship {
                let weekDate = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()) ?? Date()
                let weekBucket = CaseEntry.makeWeekBucket(for: weekDate)
                let isVacation = Int.random(in: 0..<20) == 0
                let isConference = !isVacation && Int.random(in: 0..<25) == 0
                let hours: Double = isVacation ? 0 : (isConference ? Double.random(in: 20...35) : Double.random(in: 55...75))

                let dutyEntry = DutyHoursEntry(userId: fellowId, programId: program.id, weekBucket: weekBucket, hours: hours, notes: isVacation ? "Vacation" : (isConference ? "Conference" : nil))
                modelContext.insert(dutyEntry)

                // Shift records for recent 12 weeks
                if weekOffset < 12 && !isVacation {
                    let shiftsPerWeek = isConference ? 3 : 5
                    for dayIndex in 0..<shiftsPerWeek {
                        guard let shiftDate = calendar.date(byAdding: .day, value: dayIndex, to: calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekDate))!) else { continue }
                        let startHour = Int.random(in: 6...7)
                        guard let startTime = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: shiftDate) else { continue }

                        let shiftType: DutyHoursShiftType
                        if dayIndex == 4 && Int.random(in: 0..<3) == 0 { shiftType = .call }
                        else if dayIndex == 3 && Int.random(in: 0..<5) == 0 { shiftType = .nightFloat }
                        else { shiftType = .regular }

                        let shift = DutyHoursShift(userId: fellowId, programId: program.id, shiftDate: shiftDate, startTime: startTime, shiftType: shiftType, location: .inHouse)
                        let shiftHours = shiftType == .call ? Double.random(in: 20...24) : Double.random(in: 10...14)
                        shift.clockOut(at: startTime.addingTimeInterval(shiftHours * 3600))
                        shift.breakMinutes = Int.random(in: 15...45)
                        shift.effectiveHours = shiftHours - Double(shift.breakMinutes) / 60.0
                        modelContext.insert(shift)
                    }
                }
            }
        }

        // Graduated fellows duty hours
        for fellowId in graduatedFellowIds {
            let graduationOffset = 26
            for weekOffset in graduationOffset..<(graduationOffset + 156) {
                let weekDate = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()) ?? Date()
                let weekBucket = CaseEntry.makeWeekBucket(for: weekDate)
                let isVacation = Int.random(in: 0..<20) == 0
                let hours: Double = isVacation ? 0 : Double.random(in: 55...75)
                let dutyEntry = DutyHoursEntry(userId: fellowId, programId: program.id, weekBucket: weekBucket, hours: hours, notes: isVacation ? "Vacation" : nil)
                modelContext.insert(dutyEntry)
            }
        }

        try? modelContext.save()

        // =============================================
        // 11. TEACHING FILES (Images + Videos)
        // =============================================
        addTeachingFiles(
            activeFellowIds: activeFellowIds,
            fellows: [
                (id: activeFellowIds[0], name: "Lisa Simpson"),
                (id: activeFellowIds[1], name: "Maggie Simpson"),
                (id: activeFellowIds[2], name: "Bart Simpson")
            ],
            attendingIds: attendingIds,
            attendingNames: attendingInfo.map { "\($0.first) \($0.last)" },
            programId: program.id,
            modelContext: modelContext
        )

        // =============================================
        // 12. BADGES
        // =============================================
        let allFellowIds = activeFellowIds + graduatedFellowIds
        let casesDescriptor = FetchDescriptor<CaseEntry>()
        let allCasesForBadges = (try? modelContext.fetch(casesDescriptor)) ?? []

        for fellowId in allFellowIds {
            let fellowCases = allCasesForBadges.filter {
                ($0.ownerId == fellowId || $0.fellowId == fellowId) && $0.attestationStatus == .attested && !$0.isArchived
            }.sorted { $0.createdAt > $1.createdAt }

            guard let triggeringCase = fellowCases.first else { continue }

            let badgesDescriptor = FetchDescriptor<BadgeEarned>(predicate: #Predicate<BadgeEarned> { $0.fellowId == fellowId })
            let existingBadges = (try? modelContext.fetch(badgesDescriptor)) ?? []

            let newBadges = BadgeService.shared.checkAndAwardBadges(
                for: fellowId,
                attestedCase: triggeringCase,
                allCases: allCasesForBadges,
                existingBadges: existingBadges,
                modelContext: modelContext
            )
            for earned in newBadges {
                if let badge = BadgeCatalog.badge(withId: earned.badgeId) {
                    let notification = Lumenus.Notification(
                        userId: fellowId,
                        title: "Achievement Unlocked!",
                        message: "You earned the \"\(badge.title)\" badge!",
                        notificationType: NotificationType.badgeEarned.rawValue,
                        caseId: nil
                    )
                    modelContext.insert(notification)
                }
            }
        }

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: seededKey)
        print("TestProgramSeeder: Seeded successfully. Fellow invite code: \(fellowInviteCode)")
    }

    // MARK: - Teaching Files

    private static func addTeachingFiles(
        activeFellowIds: [UUID],
        fellows: [(id: UUID, name: String)],
        attendingIds: [UUID],
        attendingNames: [String],
        programId: UUID,
        modelContext: ModelContext
    ) {
        let casesDescriptor = FetchDescriptor<CaseEntry>()
        guard let allCases = try? modelContext.fetch(casesDescriptor) else { return }

        let sampleTitles = ["RCA Lesion", "LAD Stent", "Echo View", "EP Map", "Stress ECG", "CXR Finding", "Holter Data", "LV Function", "Valve Study", "Cath Result", "ASD Closure", "PCI Result"]
        let teachingLabels = ["Teaching Example", "Interesting Case", "Classic Finding", "Rare Finding", "Good Outcome", "Complex Anatomy", "Board Review", "Unusual Approach", "Complications", "Technical Challenge"]
        let privateLabels = ["Personal Reference", "Follow-up", "To Review"]
        let fellowComments = ["Great teaching example!", "Similar to a case I had last month", "This anatomy is really well demonstrated", "Perfect example for board prep", "Can you clarify the wire position?", "Interesting approach, thanks for sharing", "I've seen this finding before on rotation", "What was the final outcome?", "Very helpful for my upcoming exam"]
        let attendingComments = ["Well documented case", "The approach looks excellent", "Would have considered alternative access", "Classic textbook finding, well captured", "Nice work on this one", "Consider reviewing the ACC guidelines for this", "This is a great discussion point for conference", "Rare finding, well identified"]

        let coronaryImages = ["DevCoronary1", "DevCoronary2", "DevCoronary3"]
        let echoImages = ["DevEcho1", "DevEcho2", "DevEcho3"]
        let ctImages = ["DevCardiacCT", "DevCT1"]
        let allDevImages = coronaryImages + echoImages + ctImages

        func devImagesForCase(_ caseEntry: CaseEntry) -> [String] {
            let tags = caseEntry.procedureTagIds
            let hasCoronary = tags.contains { $0.hasPrefix("ic-dx-") || $0.hasPrefix("ic-pci-") }
            let hasEcho = tags.contains { $0.hasPrefix("ci-echo-") }
            let hasCT = tags.contains { $0.hasPrefix("ci-ct-") }
            if hasCoronary { return coronaryImages }
            if hasEcho { return echoImages }
            if hasCT { return ctImages }
            return allDevImages
        }

        let allCommenters: [(id: UUID, name: String, role: UserRole)] =
            fellows.map { (id: $0.id, name: $0.name, role: UserRole.fellow) } +
            zip(attendingIds, attendingNames).map { (id: $0.0, name: $0.1, role: UserRole.attending) }

        for fellowInfo in fellows {
            let fellowCases = allCases.filter { $0.ownerId == fellowInfo.id || $0.fellowId == fellowInfo.id }
            guard !fellowCases.isEmpty else { continue }

            let selectedCases = fellowCases.shuffled().prefix(10)

            for (index, caseEntry) in selectedCases.enumerated() {
                let imagePool = devImagesForCase(caseEntry)
                let imageName = imagePool[index % imagePool.count]
                guard let realImage = UIImage(named: imageName) else { continue }
                guard let savedResult = MediaStorageService.shared.saveImage(realImage, forCaseId: caseEntry.id) else { continue }

                let media = CaseMedia(caseEntryId: caseEntry.id, ownerId: fellowInfo.id, ownerName: fellowInfo.name, mediaType: .image, fileName: "\(imageName)_\(index + 1).jpg", localPath: savedResult.localPath)
                media.title = sampleTitles[index % sampleTitles.count]
                media.fileSizeBytes = savedResult.fileSize
                media.contentHash = savedResult.contentHash
                media.width = savedResult.width
                media.height = savedResult.height
                media.thumbnailPath = savedResult.thumbnailPath
                media.caseDate = caseEntry.createdAt
                media.textDetectionRan = true
                media.textWasDetected = false
                media.userConfirmedNoPHI = true
                media.userConfirmedAt = caseEntry.createdAt
                media.createdAt = caseEntry.createdAt
                media.updatedAt = caseEntry.createdAt

                let isShared = index < 7
                media.isSharedWithFellowship = isShared

                if isShared {
                    let imageLabel = imageName.hasPrefix("DevCoronary") ? "Coronary Angiogram" : imageName.hasPrefix("DevEcho") ? "Echocardiogram" : "Cardiac CT"
                    var labels = [imageLabel]
                    labels += teachingLabels.shuffled().prefix(Int.random(in: 1...3))
                    media.searchTerms = labels
                    media.comment = "Teaching case - \(imageLabel)"
                } else {
                    media.searchTerms = [privateLabels.randomElement()!]
                }

                modelContext.insert(media)

                if isShared {
                    let commentCount = Int.random(in: 1...5)
                    let ownerComment = MediaComment(mediaId: media.id, authorId: fellowInfo.id, authorName: fellowInfo.name, authorRole: .fellow, text: media.comment ?? "Sharing this for the group")
                    ownerComment.createdAt = caseEntry.createdAt
                    modelContext.insert(ownerComment)

                    let otherCommenters = allCommenters.filter { $0.id != fellowInfo.id }.shuffled()
                    for ci in 0..<min(commentCount, otherCommenters.count) {
                        let commenter = otherCommenters[ci]
                        let text = commenter.role == .attending ? attendingComments.randomElement()! : fellowComments.randomElement()!
                        let comment = MediaComment(mediaId: media.id, authorId: commenter.id, authorName: commenter.name, authorRole: commenter.role, text: text)
                        comment.createdAt = caseEntry.createdAt.addingTimeInterval(Double((ci + 1) * 3600 * Int.random(in: 1...24)))
                        modelContext.insert(comment)
                    }
                }
            }

            // Video attachments: 3 per fellow
            if let videoURL = Bundle.main.url(forResource: "DevProcedureVideo1", withExtension: "mov") {
                let videoCases = fellowCases.shuffled().prefix(3)
                let videoTitles = ["Procedure", "Fluoro Clip", "Cath Review"]

                for (vIndex, caseEntry) in videoCases.enumerated() {
                    guard let savedResult = MediaStorageService.shared.saveVideoSync(from: videoURL, forCaseId: caseEntry.id) else { continue }

                    let media = CaseMedia(caseEntryId: caseEntry.id, ownerId: fellowInfo.id, ownerName: fellowInfo.name, mediaType: .video, fileName: "procedure_\(vIndex + 1).mov", localPath: savedResult.localPath)
                    media.title = videoTitles[vIndex % videoTitles.count]
                    media.fileSizeBytes = savedResult.fileSize
                    media.contentHash = savedResult.contentHash
                    media.thumbnailPath = savedResult.thumbnailPath
                    media.caseDate = caseEntry.createdAt
                    media.textDetectionRan = false
                    media.textWasDetected = false
                    media.userConfirmedNoPHI = true
                    media.userConfirmedAt = caseEntry.createdAt
                    media.createdAt = caseEntry.createdAt
                    media.updatedAt = caseEntry.createdAt

                    let isShared = vIndex < 2
                    media.isSharedWithFellowship = isShared
                    if isShared {
                        media.searchTerms = ["Procedure Video", teachingLabels.randomElement() ?? "Cardiology"]
                        media.comment = "Procedure recording for review"
                    } else {
                        media.searchTerms = [privateLabels.randomElement() ?? "Personal"]
                    }
                    modelContext.insert(media)

                    if isShared {
                        let ownerComment = MediaComment(mediaId: media.id, authorId: fellowInfo.id, authorName: fellowInfo.name, authorRole: .fellow, text: media.comment ?? "Sharing this procedure video")
                        ownerComment.createdAt = caseEntry.createdAt
                        modelContext.insert(ownerComment)

                        let otherCommenters = allCommenters.filter { $0.id != fellowInfo.id }.shuffled()
                        for ci in 0..<min(Int.random(in: 1...3), otherCommenters.count) {
                            let commenter = otherCommenters[ci]
                            let text = commenter.role == .attending ? attendingComments.randomElement()! : fellowComments.randomElement()!
                            let comment = MediaComment(mediaId: media.id, authorId: commenter.id, authorName: commenter.name, authorRole: commenter.role, text: text)
                            comment.createdAt = caseEntry.createdAt.addingTimeInterval(Double((ci + 1) * 3600 * Int.random(in: 1...24)))
                            modelContext.insert(comment)
                        }
                    }
                }
            }
        }

        try? modelContext.save()
    }
}
#endif
