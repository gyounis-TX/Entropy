// DutyHoursComplianceService.swift
// Procedus - Unified
// ACGME-compliant duty hours compliance checking and violation detection

import Foundation
import SwiftData

// MARK: - ACGME Limits

struct ACGMELimits {
    /// Maximum weekly hours (4-week rolling average)
    static let maxWeeklyHours: Double = 80

    /// Maximum continuous duty period in hours
    static let maxContinuousDuty: Double = 24

    /// Required rest after 24-hour shift in hours
    static let requiredRestAfter24: Double = 14

    /// Minimum inter-shift rest in hours
    static let minInterShiftRest: Double = 8

    /// Recommended inter-shift rest in hours
    static let recommendedInterShiftRest: Double = 10

    /// Minimum days off per 4-week period
    static let minDaysOffPer4Weeks: Int = 4

    /// Maximum call frequency (1 in N nights)
    static let maxCallFrequency: Int = 3  // Every 3rd night max

    /// Maximum consecutive night float shifts
    static let maxConsecutiveNightFloat: Int = 6

    /// Weeks in averaging period
    static let averagingPeriodWeeks: Int = 4
}

// MARK: - Compliance Summary

struct ComplianceSummary {
    let userId: UUID
    let periodStart: Date
    let periodEnd: Date

    // Weekly hours
    let fourWeekAverageHours: Double
    let maxWeekHours: Double
    let weeklyHoursByWeek: [String: Double]  // weekBucket -> hours

    // Days off
    let daysOffCount: Int
    let daysOffRequired: Int

    // Call frequency
    let callNightsCount: Int
    let callFrequencyViolation: Bool

    // Night float
    let maxConsecutiveNightFloat: Int
    let nightFloatViolation: Bool

    // Continuous duty
    let longestShiftHours: Double
    let continuousDutyViolation: Bool

    // Inter-shift rest
    let shortestRestPeriod: Double
    let interShiftRestViolation: Bool

    // Overall status
    let isCompliant: Bool
    let violations: [DutyHoursViolationType]
    let warnings: [DutyHoursViolationType]

    /// Status color for UI
    var statusColor: String {
        if !isCompliant { return "red" }
        if !warnings.isEmpty { return "yellow" }
        return "green"
    }

    /// Status text for UI
    var statusText: String {
        if !isCompliant { return "Non-Compliant" }
        if !warnings.isEmpty { return "Warning" }
        return "Compliant"
    }
}

// MARK: - Compliance Service

final class DutyHoursComplianceService {
    static let shared = DutyHoursComplianceService()

    private init() {}

    // MARK: - Main Compliance Check

    /// Check compliance for a user over a 4-week period
    func checkCompliance(
        userId: UUID,
        shifts: [DutyHoursShift],
        simpleEntries: [DutyHoursEntry],
        endDate: Date = Date()
    ) -> ComplianceSummary {
        let calendar = Calendar.current
        let periodStart = calendar.date(byAdding: .day, value: -28, to: endDate) ?? endDate

        // Filter to relevant period
        let periodShifts = shifts.filter { shift in
            shift.userId == userId &&
            shift.shiftDate >= periodStart &&
            shift.shiftDate <= endDate
        }

        let periodSimpleEntries = simpleEntries.filter { entry in
            entry.userId == userId
        }

        // Calculate weekly hours (combining shift data and simple entries)
        let weeklyHours = calculateWeeklyHours(
            shifts: periodShifts,
            simpleEntries: periodSimpleEntries,
            periodStart: periodStart,
            periodEnd: endDate
        )

        // Calculate 4-week average
        let fourWeekAverage = calculateFourWeekAverage(weeklyHours: weeklyHours)
        let maxWeek = weeklyHours.values.max() ?? 0

        // Days off calculation
        let daysOff = countDaysOff(shifts: periodShifts, periodStart: periodStart, periodEnd: endDate)

        // Call frequency
        let callNights = countCallNights(shifts: periodShifts)
        let callFrequencyViolation = checkCallFrequencyViolation(shifts: periodShifts)

        // Night float consecutive
        let maxConsecutiveNF = countMaxConsecutiveNightFloat(shifts: periodShifts)
        let nightFloatViolation = maxConsecutiveNF > ACGMELimits.maxConsecutiveNightFloat

        // Continuous duty check
        let longestShift = periodShifts.map { $0.effectiveDurationHours }.max() ?? 0
        let continuousDutyViolation = longestShift > ACGMELimits.maxContinuousDuty

        // Inter-shift rest
        let shortestRest = calculateShortestRestPeriod(shifts: periodShifts)
        let interShiftRestViolation = shortestRest < ACGMELimits.minInterShiftRest && shortestRest > 0

        // Compile violations
        var violations: [DutyHoursViolationType] = []
        var warnings: [DutyHoursViolationType] = []

        // Weekly hours check
        if fourWeekAverage > ACGMELimits.maxWeeklyHours {
            violations.append(.weeklyHoursExceeded)
        } else if fourWeekAverage > ACGMELimits.maxWeeklyHours * 0.95 {
            warnings.append(.weeklyHoursExceeded)
        }

        // Days off check
        if daysOff < ACGMELimits.minDaysOffPer4Weeks {
            violations.append(.insufficientDaysOff)
        }

        // Call frequency
        if callFrequencyViolation {
            violations.append(.callFrequencyExceeded)
        }

        // Night float
        if nightFloatViolation {
            violations.append(.nightFloatExceeded)
        }

        // Continuous duty
        if continuousDutyViolation {
            violations.append(.continuousDutyExceeded)
        }

        // Inter-shift rest
        if interShiftRestViolation {
            violations.append(.insufficientInterShiftRest)
        } else if shortestRest < ACGMELimits.recommendedInterShiftRest && shortestRest > 0 {
            warnings.append(.insufficientInterShiftRest)
        }

        return ComplianceSummary(
            userId: userId,
            periodStart: periodStart,
            periodEnd: endDate,
            fourWeekAverageHours: fourWeekAverage,
            maxWeekHours: maxWeek,
            weeklyHoursByWeek: weeklyHours,
            daysOffCount: daysOff,
            daysOffRequired: ACGMELimits.minDaysOffPer4Weeks,
            callNightsCount: callNights,
            callFrequencyViolation: callFrequencyViolation,
            maxConsecutiveNightFloat: maxConsecutiveNF,
            nightFloatViolation: nightFloatViolation,
            longestShiftHours: longestShift,
            continuousDutyViolation: continuousDutyViolation,
            shortestRestPeriod: shortestRest,
            interShiftRestViolation: interShiftRestViolation,
            isCompliant: violations.isEmpty,
            violations: violations,
            warnings: warnings
        )
    }

    // MARK: - Helper Methods

    /// Calculate weekly hours from both shift data and simple entries
    private func calculateWeeklyHours(
        shifts: [DutyHoursShift],
        simpleEntries: [DutyHoursEntry],
        periodStart: Date,
        periodEnd: Date
    ) -> [String: Double] {
        var weeklyHours: [String: Double] = [:]

        // Get all week buckets in the period
        let calendar = Calendar.current
        var currentDate = periodStart
        while currentDate <= periodEnd {
            let bucket = currentDate.toWeekBucket()
            if weeklyHours[bucket] == nil {
                weeklyHours[bucket] = 0
            }
            currentDate = calendar.date(byAdding: .day, value: 7, to: currentDate) ?? periodEnd
        }

        // Add hours from comprehensive shifts
        for shift in shifts where shift.shiftType.countsTowardHourLimits {
            let bucket = shift.weekBucket
            weeklyHours[bucket, default: 0] += shift.effectiveHours > 0 ? shift.effectiveHours : shift.effectiveDurationHours
        }

        // Add hours from simple entries (only if no shift data for that week)
        for entry in simpleEntries {
            if weeklyHours[entry.weekBucket] == 0 || weeklyHours[entry.weekBucket] == nil {
                weeklyHours[entry.weekBucket] = entry.hours
            }
        }

        return weeklyHours
    }

    /// Calculate 4-week rolling average
    func calculateFourWeekAverage(weeklyHours: [String: Double]) -> Double {
        // Get the most recent 4 weeks
        let sortedBuckets = weeklyHours.keys.sorted().suffix(ACGMELimits.averagingPeriodWeeks)
        let recentHours = sortedBuckets.compactMap { weeklyHours[$0] }

        guard !recentHours.isEmpty else { return 0 }
        return recentHours.reduce(0, +) / Double(recentHours.count)
    }

    /// Count days off in a period
    func countDaysOff(shifts: [DutyHoursShift], periodStart: Date, periodEnd: Date) -> Int {
        let calendar = Calendar.current
        var daysOff = 0
        var datesWorked = Set<String>()

        // Track all dates that had shifts
        for shift in shifts where shift.shiftType != .dayOff {
            let dateString = shift.shiftDate.formatted(date: .numeric, time: .omitted)
            datesWorked.insert(dateString)
        }

        // Count all dates in period
        var currentDate = periodStart
        var totalDays = 0
        while currentDate <= periodEnd {
            totalDays += 1
            let dateString = currentDate.formatted(date: .numeric, time: .omitted)
            if !datesWorked.contains(dateString) {
                daysOff += 1
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? periodEnd.addingTimeInterval(86400)
        }

        // Also count explicit day off entries
        let explicitDaysOff = shifts.filter { $0.shiftType == .dayOff }.count

        return max(daysOff, explicitDaysOff)
    }

    /// Count call nights in period
    func countCallNights(shifts: [DutyHoursShift]) -> Int {
        return shifts.filter { $0.shiftType.isCallShift }.count
    }

    /// Check if call frequency exceeds limit (more than every 3rd night)
    func checkCallFrequencyViolation(shifts: [DutyHoursShift]) -> Bool {
        let callShifts = shifts.filter { $0.shiftType.isCallShift }
            .sorted { $0.shiftDate < $1.shiftDate }

        guard callShifts.count >= 2 else { return false }

        let calendar = Calendar.current
        for i in 1..<callShifts.count {
            let daysBetween = calendar.dateComponents([.day], from: callShifts[i-1].shiftDate, to: callShifts[i].shiftDate).day ?? 0
            if daysBetween < ACGMELimits.maxCallFrequency {
                return true
            }
        }

        return false
    }

    /// Count maximum consecutive night float shifts
    func countMaxConsecutiveNightFloat(shifts: [DutyHoursShift]) -> Int {
        let nightFloatShifts = shifts.filter { $0.shiftType == .nightFloat }
            .sorted { $0.shiftDate < $1.shiftDate }

        guard !nightFloatShifts.isEmpty else { return 0 }

        var maxConsecutive = 1
        var currentConsecutive = 1

        let calendar = Calendar.current
        for i in 1..<nightFloatShifts.count {
            let daysBetween = calendar.dateComponents([.day], from: nightFloatShifts[i-1].shiftDate, to: nightFloatShifts[i].shiftDate).day ?? 0
            if daysBetween == 1 {
                currentConsecutive += 1
                maxConsecutive = max(maxConsecutive, currentConsecutive)
            } else {
                currentConsecutive = 1
            }
        }

        return maxConsecutive
    }

    /// Calculate shortest rest period between shifts
    func calculateShortestRestPeriod(shifts: [DutyHoursShift]) -> Double {
        let completedShifts = shifts.filter { $0.endTime != nil }
            .sorted { ($0.endTime ?? Date()) < ($1.endTime ?? Date()) }

        guard completedShifts.count >= 2 else { return Double.infinity }

        var shortestRest = Double.infinity

        for i in 1..<completedShifts.count {
            if let prevEnd = completedShifts[i-1].endTime {
                let restHours = completedShifts[i].startTime.timeIntervalSince(prevEnd) / 3600.0
                if restHours > 0 && restHours < shortestRest {
                    shortestRest = restHours
                }
            }
        }

        return shortestRest == Double.infinity ? 0 : shortestRest
    }

    // MARK: - Violation Detection and Creation

    /// Detect and create violations for a user
    func detectAndCreateViolations(
        userId: UUID,
        programId: UUID?,
        shifts: [DutyHoursShift],
        simpleEntries: [DutyHoursEntry],
        modelContext: ModelContext
    ) -> [DutyHoursViolation] {
        let summary = checkCompliance(userId: userId, shifts: shifts, simpleEntries: simpleEntries)
        var newViolations: [DutyHoursViolation] = []

        for violationType in summary.violations {
            let (actualValue, limitValue) = getViolationValues(type: violationType, summary: summary)
            let severity = determineSeverity(type: violationType, actualValue: actualValue, limitValue: limitValue)

            let violation = DutyHoursViolation(
                userId: userId,
                programId: programId,
                weekBucket: Date().toWeekBucket(),
                violationType: violationType,
                severity: severity,
                actualValue: actualValue,
                limitValue: limitValue,
                periodStart: summary.periodStart,
                periodEnd: summary.periodEnd
            )

            modelContext.insert(violation)
            newViolations.append(violation)
        }

        try? modelContext.save()
        return newViolations
    }

    /// Get actual and limit values for a violation type
    private func getViolationValues(type: DutyHoursViolationType, summary: ComplianceSummary) -> (Double, Double) {
        switch type {
        case .weeklyHoursExceeded:
            return (summary.fourWeekAverageHours, ACGMELimits.maxWeeklyHours)
        case .continuousDutyExceeded:
            return (summary.longestShiftHours, ACGMELimits.maxContinuousDuty)
        case .insufficientRestAfter24:
            return (summary.shortestRestPeriod, ACGMELimits.requiredRestAfter24)
        case .insufficientInterShiftRest:
            return (summary.shortestRestPeriod, ACGMELimits.minInterShiftRest)
        case .insufficientDaysOff:
            return (Double(summary.daysOffCount), Double(ACGMELimits.minDaysOffPer4Weeks))
        case .callFrequencyExceeded:
            return (Double(summary.callNightsCount), Double(ACGMELimits.maxCallFrequency))
        case .nightFloatExceeded:
            return (Double(summary.maxConsecutiveNightFloat), Double(ACGMELimits.maxConsecutiveNightFloat))
        }
    }

    /// Determine violation severity
    private func determineSeverity(type: DutyHoursViolationType, actualValue: Double, limitValue: Double) -> ViolationSeverity {
        let percentOver = (actualValue - limitValue) / limitValue * 100

        switch type {
        case .weeklyHoursExceeded:
            if percentOver > 10 { return .critical }
            if percentOver > 5 { return .major }
            return .minor
        case .continuousDutyExceeded:
            if actualValue > 28 { return .critical }
            if actualValue > 26 { return .major }
            return .minor
        case .insufficientRestAfter24, .insufficientInterShiftRest:
            if actualValue < 4 { return .critical }
            if actualValue < 6 { return .major }
            return .minor
        case .insufficientDaysOff:
            if actualValue == 0 { return .critical }
            if actualValue < 2 { return .major }
            return .minor
        case .callFrequencyExceeded, .nightFloatExceeded:
            return .major
        }
    }
}

// MARK: - Date Extension for Week Bucket

extension Date {
    /// Convert date to week bucket format (e.g., "2024-W03")
    func toWeekBucket() -> String {
        let calendar = Calendar.current
        let year = calendar.component(.yearForWeekOfYear, from: self)
        let week = calendar.component(.weekOfYear, from: self)
        return String(format: "%04d-W%02d", year, week)
    }
}
