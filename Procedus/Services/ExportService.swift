// ExportService.swift
// Procedus - Unified
// Export service matching original Procedus format

import Foundation
import UIKit
import SwiftUI

class ExportService {
    static let shared = ExportService()
    private init() {}
    
    struct CaseExportRow {
        let fellowName: String
        let attendingName: String
        let facilityName: String
        let weekBucket: String
        let procedures: String
        let procedureCount: Int
        let accessSites: String
        let complications: String
        let outcome: String
        let attestationStatus: String
        let attestedDate: String
        let createdDate: String
        let procedureDate: String
    }
    
    struct ProcedureCountRow {
        let category: String
        let procedure: String
        let count: Int
    }
    
    // MARK: - CSV Export
    
    func exportToCSV(rows: [CaseExportRow], filename: String) -> URL? {
        var csv = "Fellow,Attending,Facility,Week,Procedure Date,Procedures,Count,Access Sites,Complications,Outcome,Status,Attested,Created\n"
        for row in rows {
            csv += "\(escape(row.fellowName)),\(escape(row.attendingName)),\(escape(row.facilityName)),\(row.weekBucket),\(row.procedureDate),\(escape(row.procedures)),\(row.procedureCount),\(escape(row.accessSites)),\(escape(row.complications)),\(row.outcome),\(row.attestationStatus),\(row.attestedDate),\(row.createdDate)\n"
        }
        return saveFile(csv, filename: "\(filename).csv")
    }
    
    func exportProcedureCountsToCSV(rows: [ProcedureCountRow], filename: String) -> URL? {
        var csv = "Category,Procedure,Count\n"
        for row in rows { csv += "\(row.category),\(escape(row.procedure)),\(row.count)\n" }
        return saveFile(csv, filename: "\(filename).csv")
    }
    
    // MARK: - Excel Export
    
    func exportToExcel(rows: [CaseExportRow], filename: String) -> URL? {
        var content = "Fellow\tAttending\tFacility\tWeek\tProcedure Date\tProcedures\tCount\tAccess Sites\tComplications\tOutcome\tStatus\tAttested\tCreated\n"
        for row in rows {
            content += "\(row.fellowName)\t\(row.attendingName)\t\(row.facilityName)\t\(row.weekBucket)\t\(row.procedureDate)\t\(row.procedures)\t\(row.procedureCount)\t\(row.accessSites)\t\(row.complications)\t\(row.outcome)\t\(row.attestationStatus)\t\(row.attestedDate)\t\(row.createdDate)\n"
        }
        return saveFile(content, filename: "\(filename).xls")
    }
    
    func exportProcedureCountsToExcel(rows: [ProcedureCountRow], fellowName: String, totalCases: Int, dateRange: String) -> URL? {
        var content = "PROCEDUS PROCEDURE COUNT REPORT\nFellow: \(fellowName)\nDate Range: \(dateRange)\nTotal Cases: \(totalCases)\n\nCategory\tProcedure\tCount\n"
        for row in rows { content += "\(row.category)\t\(row.procedure)\t\(row.count)\n" }
        return saveFile(content, filename: "\(fellowName.replacingOccurrences(of: " ", with: "_"))_counts.xls")
    }
    
    // MARK: - ACGME Format
    
    func exportACGMEFormat(fellowName: String, rows: [CaseExportRow], procedureCounts: [String: Int]) -> URL? {
        var content = "ACGME PROCEDURE LOG REPORT\n================================\n\n"
        content += "Fellow: \(fellowName)\nGenerated: \(Date().formatted())\nTotal Cases: \(rows.count)\n\n"
        content += "PROCEDURE SUMMARY\n-----------------\n"
        for (proc, count) in procedureCounts.sorted(by: { $0.value > $1.value }) {
            content += "\(proc): \(count)\n"
        }
        content += "\n\nDETAILED CASE LOG\n-----------------\n\n"
        for (i, row) in rows.enumerated() {
            content += "Case \(i+1)\n  Date: \(row.weekBucket)\n  Attending: \(row.attendingName)\n  Facility: \(row.facilityName)\n  Procedures: \(row.procedures)\n  Outcome: \(row.outcome)\n\n"
        }
        return saveFile(content, filename: "\(fellowName.replacingOccurrences(of: " ", with: "_"))_ACGME.txt")
    }
    
    // MARK: - PDF Export
    
    func exportToPDF(rows: [CaseExportRow], fellowName: String, title: String) -> URL? {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 40
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 18)]
            title.draw(at: CGPoint(x: 40, y: y), withAttributes: attrs)
            y += 30
            let subAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10)]
            "Fellow: \(fellowName) | Cases: \(rows.count)".draw(at: CGPoint(x: 40, y: y), withAttributes: subAttrs)
            y += 30
            for row in rows {
                if y > 750 { ctx.beginPage(); y = 40 }
                "\(row.weekBucket) | \(row.attendingName) | \(row.procedures)".draw(at: CGPoint(x: 40, y: y), withAttributes: subAttrs)
                y += 14
            }
        }
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(fellowName)_log.pdf")
        try? data.write(to: url)
        return url
    }
    
    func exportProcedureCountsToPDF(rows: [ProcedureCountRow], fellowName: String, dateRange: String) -> URL? {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 40
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 18)]
            "Procedure Count Report".draw(at: CGPoint(x: 40, y: y), withAttributes: attrs)
            y += 30
            let subAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10)]
            "Fellow: \(fellowName) | Range: \(dateRange)".draw(at: CGPoint(x: 40, y: y), withAttributes: subAttrs)
            y += 30
            for row in rows {
                if y > 750 { ctx.beginPage(); y = 40 }
                "\(row.category) | \(row.procedure) | \(row.count)".draw(at: CGPoint(x: 40, y: y), withAttributes: subAttrs)
                y += 14
            }
        }
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(fellowName)_counts.pdf")
        try? data.write(to: url)
        return url
    }
    
    // MARK: - Evaluation Summary Export

    struct EvaluationExportData {
        let fellowName: String
        let dateRange: String
        let totalEvaluations: Int
        let fieldMetrics: [FieldMetric]
        let comments: [CommentEntry]

        struct FieldMetric {
            let title: String
            let fieldType: String  // "checkbox" or "rating"
            let average: Double?   // nil for checkbox, 1-5 for rating
            let count: Int
            let total: Int         // total cases evaluated
            let percentage: Double // for checkbox: % checked, for rating: average as %
        }

        struct CommentEntry {
            let comment: String
            let attendingName: String
            let date: Date
            let formattedDate: String
        }
    }

    func exportEvaluationSummaryToCSV(_ data: EvaluationExportData, filename: String) -> URL? {
        var csv = "EVALUATION SUMMARY REPORT\n"
        csv += "Fellow,\(escape(data.fellowName))\n"
        csv += "Date Range,\(data.dateRange)\n"
        csv += "Total Evaluations,\(data.totalEvaluations)\n\n"

        csv += "METRICS\n"
        csv += "Field,Type,Value,Count\n"
        for metric in data.fieldMetrics {
            let value: String
            if metric.fieldType == "rating", let avg = metric.average {
                value = String(format: "%.1f/5.0", avg)
            } else {
                value = "\(metric.count)/\(metric.total) (\(Int(metric.percentage))%)"
            }
            csv += "\(escape(metric.title)),\(metric.fieldType),\(value),\(metric.count)\n"
        }

        csv += "\nCOMMENTS\n"
        csv += "Date,Attending,Comment\n"
        for comment in data.comments {
            csv += "\(comment.formattedDate),\(escape(comment.attendingName)),\(escape(comment.comment))\n"
        }

        return saveFile(csv, filename: filename)
    }

    func exportEvaluationSummaryToExcel(_ data: EvaluationExportData, filename: String) -> URL? {
        var content = "EVALUATION SUMMARY REPORT\n"
        content += "Fellow:\t\(data.fellowName)\n"
        content += "Date Range:\t\(data.dateRange)\n"
        content += "Total Evaluations:\t\(data.totalEvaluations)\n\n"

        content += "METRICS\n"
        content += "Field\tType\tValue\tCount\n"
        for metric in data.fieldMetrics {
            let value: String
            if metric.fieldType == "rating", let avg = metric.average {
                value = String(format: "%.1f/5.0", avg)
            } else {
                value = "\(metric.count)/\(metric.total) (\(Int(metric.percentage))%)"
            }
            content += "\(metric.title)\t\(metric.fieldType)\t\(value)\t\(metric.count)\n"
        }

        content += "\nCOMMENTS\n"
        content += "Date\tAttending\tComment\n"
        for comment in data.comments {
            content += "\(comment.formattedDate)\t\(comment.attendingName)\t\(comment.comment)\n"
        }

        return saveFile(content, filename: filename)
    }

    func exportEvaluationSummaryToPDF(_ data: EvaluationExportData, filename: String) -> URL? {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 40

            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 18)]
            let headerAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 14)]
            let subAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11)]
            let smallAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10)]

            // Title
            "Evaluation Summary Report".draw(at: CGPoint(x: 40, y: y), withAttributes: titleAttrs)
            y += 30

            // Fellow info
            "Fellow: \(data.fellowName)".draw(at: CGPoint(x: 40, y: y), withAttributes: subAttrs)
            y += 18
            "Date Range: \(data.dateRange)".draw(at: CGPoint(x: 40, y: y), withAttributes: subAttrs)
            y += 18
            "Total Evaluations: \(data.totalEvaluations)".draw(at: CGPoint(x: 40, y: y), withAttributes: subAttrs)
            y += 30

            // Metrics section
            "Performance Metrics".draw(at: CGPoint(x: 40, y: y), withAttributes: headerAttrs)
            y += 22

            for metric in data.fieldMetrics {
                if y > 720 { ctx.beginPage(); y = 40 }
                let value: String
                if metric.fieldType == "rating", let avg = metric.average {
                    value = String(format: "%.1f / 5.0 ★", avg)
                } else {
                    value = "\(metric.count) / \(metric.total) cases (\(Int(metric.percentage))%)"
                }
                "• \(metric.title): \(value)".draw(at: CGPoint(x: 50, y: y), withAttributes: subAttrs)
                y += 16
            }

            y += 20

            // Comments section
            if !data.comments.isEmpty {
                if y > 680 { ctx.beginPage(); y = 40 }
                "Evaluation Comments".draw(at: CGPoint(x: 40, y: y), withAttributes: headerAttrs)
                y += 22

                for comment in data.comments {
                    if y > 720 { ctx.beginPage(); y = 40 }
                    "\(comment.formattedDate) - \(comment.attendingName):".draw(at: CGPoint(x: 50, y: y), withAttributes: smallAttrs)
                    y += 14

                    // Word wrap long comments
                    let words = comment.comment.split(separator: " ")
                    var line = ""
                    for word in words {
                        let testLine = line.isEmpty ? String(word) : "\(line) \(word)"
                        if testLine.count > 80 {
                            if y > 720 { ctx.beginPage(); y = 40 }
                            "  \(line)".draw(at: CGPoint(x: 50, y: y), withAttributes: smallAttrs)
                            y += 12
                            line = String(word)
                        } else {
                            line = testLine
                        }
                    }
                    if !line.isEmpty {
                        if y > 720 { ctx.beginPage(); y = 40 }
                        "  \(line)".draw(at: CGPoint(x: 50, y: y), withAttributes: smallAttrs)
                        y += 12
                    }
                    y += 8
                }
            }
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return url
    }

    // MARK: - Evaluation Log Export

    struct EvaluationLogRow {
        let fellowName: String
        let caseDate: String
        let attendingName: String
        let evaluatedBy: String      // "Attending" or "Proxy (Admin)"
        let attestorName: String
        let procedures: String
        let attestationDate: String
        let comment: String
        let ratings: [String: String]  // field title -> value
    }

    func exportEvaluationLogToCSV(rows: [EvaluationLogRow], filename: String) -> URL? {
        // Get all unique rating field names
        var allFields: [String] = []
        for row in rows {
            for key in row.ratings.keys where !allFields.contains(key) {
                allFields.append(key)
            }
        }
        allFields.sort()

        var csv = "Case Date,Attending,Evaluated By,Attestor,Procedures,Attestation Date,Comment"
        for field in allFields {
            csv += ",\(escape(field))"
        }
        csv += "\n"

        for row in rows {
            csv += "\(row.caseDate),\(escape(row.attendingName)),\(row.evaluatedBy),\(escape(row.attestorName)),\(escape(row.procedures)),\(row.attestationDate),\(escape(row.comment))"
            for field in allFields {
                csv += ",\(row.ratings[field] ?? "")"
            }
            csv += "\n"
        }

        return saveFile(csv, filename: "\(filename).csv")
    }

    func exportEvaluationLogToExcel(rows: [EvaluationLogRow], fellowName: String, dateRange: String) -> URL? {
        // Get all unique rating field names
        var allFields: [String] = []
        for row in rows {
            for key in row.ratings.keys where !allFields.contains(key) {
                allFields.append(key)
            }
        }
        allFields.sort()

        var content = "EVALUATION LOG REPORT\n"
        content += "Fellow:\t\(fellowName)\n"
        content += "Date Range:\t\(dateRange)\n"
        content += "Total Cases:\t\(rows.count)\n\n"

        content += "Case Date\tAttending\tEvaluated By\tAttestor\tProcedures\tAttestation Date\tComment"
        for field in allFields {
            content += "\t\(field)"
        }
        content += "\n"

        for row in rows {
            content += "\(row.caseDate)\t\(row.attendingName)\t\(row.evaluatedBy)\t\(row.attestorName)\t\(row.procedures)\t\(row.attestationDate)\t\(row.comment)"
            for field in allFields {
                content += "\t\(row.ratings[field] ?? "")"
            }
            content += "\n"
        }

        let safeName = fellowName.replacingOccurrences(of: " ", with: "_")
        return saveFile(content, filename: "\(safeName)_eval_log.xls")
    }

    func exportEvaluationLogToPDF(rows: [EvaluationLogRow], fellowName: String, dateRange: String) -> URL? {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 792, height: 612)  // Landscape for more columns
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 40

            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16)]
            let headerAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 9)]
            let subAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10)]
            let smallAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8)]

            // Title
            "Evaluation Log Report".draw(at: CGPoint(x: 40, y: y), withAttributes: titleAttrs)
            y += 24

            // Fellow info
            "Fellow: \(fellowName)  |  Date Range: \(dateRange)  |  Total Cases: \(rows.count)".draw(at: CGPoint(x: 40, y: y), withAttributes: subAttrs)
            y += 30

            // Column headers
            "Date".draw(at: CGPoint(x: 40, y: y), withAttributes: headerAttrs)
            "Attending".draw(at: CGPoint(x: 100, y: y), withAttributes: headerAttrs)
            "Evaluated By".draw(at: CGPoint(x: 200, y: y), withAttributes: headerAttrs)
            "Procedures".draw(at: CGPoint(x: 300, y: y), withAttributes: headerAttrs)
            "Comment".draw(at: CGPoint(x: 550, y: y), withAttributes: headerAttrs)
            y += 16

            // Draw line
            ctx.cgContext.setStrokeColor(UIColor.gray.cgColor)
            ctx.cgContext.setLineWidth(0.5)
            ctx.cgContext.move(to: CGPoint(x: 40, y: y))
            ctx.cgContext.addLine(to: CGPoint(x: 752, y: y))
            ctx.cgContext.strokePath()
            y += 8

            for row in rows {
                if y > 560 { ctx.beginPage(); y = 40 }

                let evaluatorInfo = row.evaluatedBy == "Proxy (Admin)" ? "Proxy" : "Attg"
                row.caseDate.draw(at: CGPoint(x: 40, y: y), withAttributes: smallAttrs)
                row.attendingName.draw(at: CGPoint(x: 100, y: y), withAttributes: smallAttrs)
                evaluatorInfo.draw(at: CGPoint(x: 200, y: y), withAttributes: smallAttrs)

                // Truncate procedures if too long
                let procDisplay = row.procedures.count > 35 ? String(row.procedures.prefix(32)) + "..." : row.procedures
                procDisplay.draw(at: CGPoint(x: 300, y: y), withAttributes: smallAttrs)

                // Truncate comment if too long
                let commentDisplay = row.comment.count > 30 ? String(row.comment.prefix(27)) + "..." : row.comment
                commentDisplay.draw(at: CGPoint(x: 550, y: y), withAttributes: smallAttrs)

                y += 14
            }
        }

        let safeName = fellowName.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName)_eval_log.pdf")
        try? data.write(to: url)
        return url
    }

    // MARK: - Duty Hours Export

    struct DutyHoursRow {
        let weekBucket: String
        let weekLabel: String
        let hours: Double
        let notes: String
    }

    func exportDutyHoursToCSV(rows: [DutyHoursRow], filename: String) -> URL? {
        var csv = "Week,Date Range,Hours,Notes\n"
        for row in rows {
            csv += "\(row.weekBucket),\(escape(row.weekLabel)),\(row.hours),\(escape(row.notes))\n"
        }
        return saveFile(csv, filename: "\(filename).csv")
    }

    func exportDutyHoursToExcel(rows: [DutyHoursRow], fellowName: String, dateRange: String) -> URL? {
        var content = "DUTY HOURS REPORT\n"
        content += "Fellow:\t\(fellowName)\n"
        content += "Date Range:\t\(dateRange)\n"
        content += "Total Weeks:\t\(rows.count)\n"

        let totalHours = rows.reduce(0.0) { $0 + $1.hours }
        let avgHours = rows.isEmpty ? 0 : totalHours / Double(rows.count)
        content += "Total Hours:\t\(String(format: "%.0f", totalHours))\n"
        content += "Average Hours/Week:\t\(String(format: "%.1f", avgHours))\n\n"

        content += "Week\tDate Range\tHours\tNotes\n"
        for row in rows {
            content += "\(row.weekBucket)\t\(row.weekLabel)\t\(row.hours)\t\(row.notes)\n"
        }

        let safeName = fellowName.replacingOccurrences(of: " ", with: "_")
        return saveFile(content, filename: "\(safeName)_duty_hours.xls")
    }

    func exportDutyHoursToPDF(rows: [DutyHoursRow], fellowName: String, dateRange: String) -> URL? {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let totalHours = rows.reduce(0.0) { $0 + $1.hours }
        let avgHours = rows.isEmpty ? 0 : totalHours / Double(rows.count)

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 40

            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 18)]
            let headerAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 11)]
            let subAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11)]
            let smallAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10)]

            // Title
            "Duty Hours Report".draw(at: CGPoint(x: 40, y: y), withAttributes: titleAttrs)
            y += 30

            // Fellow info
            "Fellow: \(fellowName)".draw(at: CGPoint(x: 40, y: y), withAttributes: subAttrs)
            y += 18
            "Date Range: \(dateRange)".draw(at: CGPoint(x: 40, y: y), withAttributes: subAttrs)
            y += 18
            "Total Hours: \(String(format: "%.0f", totalHours))  |  Average: \(String(format: "%.1f", avgHours)) hrs/week".draw(at: CGPoint(x: 40, y: y), withAttributes: subAttrs)
            y += 30

            // Column headers
            "Date Range".draw(at: CGPoint(x: 40, y: y), withAttributes: headerAttrs)
            "Hours".draw(at: CGPoint(x: 350, y: y), withAttributes: headerAttrs)
            y += 18

            // Draw line
            ctx.cgContext.setStrokeColor(UIColor.gray.cgColor)
            ctx.cgContext.setLineWidth(0.5)
            ctx.cgContext.move(to: CGPoint(x: 40, y: y))
            ctx.cgContext.addLine(to: CGPoint(x: 572, y: y))
            ctx.cgContext.strokePath()
            y += 10

            for row in rows {
                if y > 720 { ctx.beginPage(); y = 40 }
                row.weekLabel.draw(at: CGPoint(x: 40, y: y), withAttributes: smallAttrs)
                String(format: "%.0f", row.hours).draw(at: CGPoint(x: 350, y: y), withAttributes: smallAttrs)
                y += 16
            }
        }

        let safeName = fellowName.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName)_duty_hours.pdf")
        try? data.write(to: url)
        return url
    }

    // MARK: - ACGME Duty Hours Export (Comprehensive)

    struct ACGMEDutyHoursExportData {
        let fellowName: String
        let pgyLevel: Int
        let programName: String
        let periodStart: Date
        let periodEnd: Date
        let complianceSummary: ComplianceSummary
        let shifts: [DutyHoursShift]
        let violations: [DutyHoursViolation]
    }

    func exportACGMEDutyHoursToCSV(_ data: ACGMEDutyHoursExportData, filename: String) -> URL? {
        var csv = "ACGME DUTY HOURS COMPLIANCE REPORT\n"
        csv += "Fellow,\(escape(data.fellowName))\n"
        csv += "PGY Level,\(data.pgyLevel)\n"
        csv += "Program,\(escape(data.programName))\n"
        csv += "Period,\(data.periodStart.formatted(date: .abbreviated, time: .omitted)) - \(data.periodEnd.formatted(date: .abbreviated, time: .omitted))\n"
        csv += "Generated,\(Date().formatted())\n\n"

        // Compliance Summary
        csv += "COMPLIANCE SUMMARY\n"
        csv += "Status,\(data.complianceSummary.statusText)\n"
        csv += "4-Week Average Hours,\(String(format: "%.1f", data.complianceSummary.fourWeekAverageHours))\n"
        csv += "Maximum Week Hours,\(String(format: "%.1f", data.complianceSummary.maxWeekHours))\n"
        csv += "Days Off,\(data.complianceSummary.daysOffCount) (Minimum: \(data.complianceSummary.daysOffRequired))\n"
        csv += "Longest Shift,\(String(format: "%.1f", data.complianceSummary.longestShiftHours)) hours\n"
        csv += "Shortest Rest Period,\(String(format: "%.1f", data.complianceSummary.shortestRestPeriod)) hours\n"
        csv += "Call Nights,\(data.complianceSummary.callNightsCount)\n"
        csv += "Max Consecutive Night Float,\(data.complianceSummary.maxConsecutiveNightFloat)\n\n"

        // Weekly Hours Breakdown
        csv += "WEEKLY HOURS BREAKDOWN\n"
        csv += "Week,Hours,Status\n"
        for (week, hours) in data.complianceSummary.weeklyHoursByWeek.sorted(by: { $0.key > $1.key }) {
            let status = hours > 80 ? "OVER LIMIT" : (hours > 76 ? "WARNING" : "OK")
            csv += "\(week),\(String(format: "%.1f", hours)),\(status)\n"
        }
        csv += "\n"

        // Shift Log
        csv += "SHIFT LOG\n"
        csv += "Date,Type,Location,Start Time,End Time,Duration (hrs),Break (min),Notes\n"
        for shift in data.shifts.sorted(by: { $0.shiftDate > $1.shiftDate }) {
            let endTime = shift.endTime?.formatted(date: .omitted, time: .shortened) ?? "In Progress"
            csv += "\(shift.shiftDate.formatted(date: .numeric, time: .omitted)),"
            csv += "\(shift.shiftType.displayName),"
            csv += "\(shift.location.displayName),"
            csv += "\(shift.startTime.formatted(date: .omitted, time: .shortened)),"
            csv += "\(endTime),"
            csv += "\(String(format: "%.1f", shift.effectiveDurationHours)),"
            csv += "\(shift.breakMinutes),"
            csv += "\(escape(shift.notes ?? ""))\n"
        }
        csv += "\n"

        // Violations
        if !data.violations.isEmpty {
            csv += "VIOLATION HISTORY\n"
            csv += "Date,Type,Severity,Actual Value,Limit Value,Resolved\n"
            for violation in data.violations.sorted(by: { $0.detectedAt > $1.detectedAt }) {
                csv += "\(violation.detectedAt.formatted(date: .numeric, time: .omitted)),"
                csv += "\(violation.violationType.displayName),"
                csv += "\(violation.severity.rawValue),"
                csv += "\(String(format: "%.1f", violation.actualValue)),"
                csv += "\(String(format: "%.1f", violation.limitValue)),"
                csv += "\(violation.isResolved ? "Yes" : "No")\n"
            }
        }

        return saveFile(csv, filename: "\(filename).csv")
    }

    func exportACGMEDutyHoursToExcel(_ data: ACGMEDutyHoursExportData, filename: String) -> URL? {
        var content = "ACGME DUTY HOURS COMPLIANCE REPORT\n\n"
        content += "Fellow:\t\(data.fellowName)\n"
        content += "PGY Level:\t\(data.pgyLevel)\n"
        content += "Program:\t\(data.programName)\n"
        content += "Period:\t\(data.periodStart.formatted(date: .abbreviated, time: .omitted)) - \(data.periodEnd.formatted(date: .abbreviated, time: .omitted))\n"
        content += "Generated:\t\(Date().formatted())\n\n"

        // Compliance Summary
        content += "COMPLIANCE SUMMARY\n"
        content += "Status:\t\(data.complianceSummary.statusText)\n"
        content += "4-Week Average Hours:\t\(String(format: "%.1f", data.complianceSummary.fourWeekAverageHours))\t(Limit: 80)\n"
        content += "Maximum Week Hours:\t\(String(format: "%.1f", data.complianceSummary.maxWeekHours))\n"
        content += "Days Off:\t\(data.complianceSummary.daysOffCount)\t(Minimum: \(data.complianceSummary.daysOffRequired))\n"
        content += "Longest Shift:\t\(String(format: "%.1f", data.complianceSummary.longestShiftHours)) hours\t(Limit: 24)\n"
        content += "Shortest Rest Period:\t\(String(format: "%.1f", data.complianceSummary.shortestRestPeriod)) hours\t(Minimum: 8)\n"
        content += "Call Nights:\t\(data.complianceSummary.callNightsCount)\n"
        content += "Max Consecutive Night Float:\t\(data.complianceSummary.maxConsecutiveNightFloat)\t(Limit: 6)\n\n"

        // ACGME Requirements Checklist
        content += "ACGME REQUIREMENTS CHECKLIST\n"
        content += "Requirement\tACGME Ref\tStatus\n"
        content += "80-Hour Weekly Limit\tVI.F.1\t\(data.complianceSummary.fourWeekAverageHours <= 80 ? "PASS" : "FAIL")\n"
        content += "24-Hour Continuous Duty\tVI.F.3\t\(data.complianceSummary.longestShiftHours <= 24 ? "PASS" : "FAIL")\n"
        content += "8-Hour Inter-Shift Rest\tVI.F.4\t\(!data.complianceSummary.interShiftRestViolation ? "PASS" : "FAIL")\n"
        content += "4 Days Off per 4 Weeks\tVI.F.5\t\(data.complianceSummary.daysOffCount >= 4 ? "PASS" : "FAIL")\n"
        content += "Call Frequency (Q3)\tVI.F.6\t\(!data.complianceSummary.callFrequencyViolation ? "PASS" : "FAIL")\n"
        content += "Night Float Limit\tVI.F.7\t\(!data.complianceSummary.nightFloatViolation ? "PASS" : "FAIL")\n\n"

        // Weekly Hours Breakdown
        content += "WEEKLY HOURS BREAKDOWN\n"
        content += "Week\tHours\tStatus\n"
        for (week, hours) in data.complianceSummary.weeklyHoursByWeek.sorted(by: { $0.key > $1.key }) {
            let status = hours > 80 ? "OVER LIMIT" : (hours > 76 ? "WARNING" : "OK")
            content += "\(week)\t\(String(format: "%.1f", hours))\t\(status)\n"
        }
        content += "\n"

        // Shift Log
        content += "SHIFT LOG\n"
        content += "Date\tType\tLocation\tStart\tEnd\tDuration\tBreak\tNotes\n"
        for shift in data.shifts.sorted(by: { $0.shiftDate > $1.shiftDate }) {
            let endTime = shift.endTime?.formatted(date: .omitted, time: .shortened) ?? "In Progress"
            content += "\(shift.shiftDate.formatted(date: .numeric, time: .omitted))\t"
            content += "\(shift.shiftType.displayName)\t"
            content += "\(shift.location.displayName)\t"
            content += "\(shift.startTime.formatted(date: .omitted, time: .shortened))\t"
            content += "\(endTime)\t"
            content += "\(String(format: "%.1f", shift.effectiveDurationHours))\t"
            content += "\(shift.breakMinutes)\t"
            content += "\(shift.notes ?? "")\n"
        }

        let safeName = data.fellowName.replacingOccurrences(of: " ", with: "_")
        return saveFile(content, filename: "\(safeName)_ACGME_duty_hours.xls")
    }

    func exportACGMEDutyHoursToPDF(_ data: ACGMEDutyHoursExportData, filename: String) -> URL? {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let pdfData = renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 40

            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 18)]
            let headerAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 14)]
            let subHeaderAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 11)]
            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11)]
            let smallAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9)]
            let passAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: UIColor.systemGreen]
            let failAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: UIColor.systemRed]

            // Title
            "ACGME Duty Hours Compliance Report".draw(at: CGPoint(x: 40, y: y), withAttributes: titleAttrs)
            y += 30

            // Fellow info
            "Fellow: \(data.fellowName) (PGY-\(data.pgyLevel))".draw(at: CGPoint(x: 40, y: y), withAttributes: bodyAttrs)
            y += 16
            "Program: \(data.programName)".draw(at: CGPoint(x: 40, y: y), withAttributes: bodyAttrs)
            y += 16
            "Period: \(data.periodStart.formatted(date: .abbreviated, time: .omitted)) - \(data.periodEnd.formatted(date: .abbreviated, time: .omitted))".draw(at: CGPoint(x: 40, y: y), withAttributes: bodyAttrs)
            y += 16
            "Generated: \(Date().formatted())".draw(at: CGPoint(x: 40, y: y), withAttributes: bodyAttrs)
            y += 30

            // Compliance Status Box
            let statusColor = data.complianceSummary.isCompliant ? UIColor.systemGreen : UIColor.systemRed
            ctx.cgContext.setFillColor(statusColor.withAlphaComponent(0.1).cgColor)
            ctx.cgContext.fill(CGRect(x: 40, y: y - 5, width: 532, height: 40))
            ctx.cgContext.setStrokeColor(statusColor.cgColor)
            ctx.cgContext.setLineWidth(2)
            ctx.cgContext.stroke(CGRect(x: 40, y: y - 5, width: 532, height: 40))

            let statusAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: statusColor]
            "Overall Status: \(data.complianceSummary.statusText.uppercased())".draw(at: CGPoint(x: 50, y: y + 5), withAttributes: statusAttrs)
            y += 50

            // Key Metrics
            "Key Metrics".draw(at: CGPoint(x: 40, y: y), withAttributes: headerAttrs)
            y += 22

            let metricsX: [CGFloat] = [50, 200, 350, 500]
            "Weekly Avg:".draw(at: CGPoint(x: metricsX[0], y: y), withAttributes: smallAttrs)
            "\(String(format: "%.1f", data.complianceSummary.fourWeekAverageHours)) hrs".draw(at: CGPoint(x: metricsX[0], y: y + 12), withAttributes: subHeaderAttrs)

            "Days Off:".draw(at: CGPoint(x: metricsX[1], y: y), withAttributes: smallAttrs)
            "\(data.complianceSummary.daysOffCount) days".draw(at: CGPoint(x: metricsX[1], y: y + 12), withAttributes: subHeaderAttrs)

            "Longest Shift:".draw(at: CGPoint(x: metricsX[2], y: y), withAttributes: smallAttrs)
            "\(String(format: "%.1f", data.complianceSummary.longestShiftHours)) hrs".draw(at: CGPoint(x: metricsX[2], y: y + 12), withAttributes: subHeaderAttrs)

            "Min Rest:".draw(at: CGPoint(x: metricsX[3], y: y), withAttributes: smallAttrs)
            "\(String(format: "%.1f", data.complianceSummary.shortestRestPeriod)) hrs".draw(at: CGPoint(x: metricsX[3], y: y + 12), withAttributes: subHeaderAttrs)

            y += 45

            // ACGME Requirements
            "ACGME Requirements".draw(at: CGPoint(x: 40, y: y), withAttributes: headerAttrs)
            y += 20

            let requirements: [(String, String, Bool)] = [
                ("80-Hour Weekly Limit (VI.F.1)", String(format: "%.1f hrs", data.complianceSummary.fourWeekAverageHours), data.complianceSummary.fourWeekAverageHours <= 80),
                ("24-Hour Continuous Duty (VI.F.3)", String(format: "%.1f hrs", data.complianceSummary.longestShiftHours), data.complianceSummary.longestShiftHours <= 24),
                ("8-Hour Inter-Shift Rest (VI.F.4)", String(format: "%.1f hrs", data.complianceSummary.shortestRestPeriod), !data.complianceSummary.interShiftRestViolation),
                ("4 Days Off per 4 Weeks (VI.F.5)", "\(data.complianceSummary.daysOffCount) days", data.complianceSummary.daysOffCount >= 4),
                ("Call Frequency Q3 (VI.F.6)", "\(data.complianceSummary.callNightsCount) nights", !data.complianceSummary.callFrequencyViolation),
                ("Night Float Limit (VI.F.7)", "\(data.complianceSummary.maxConsecutiveNightFloat) consecutive", !data.complianceSummary.nightFloatViolation)
            ]

            for (req, value, passed) in requirements {
                if y > 720 { ctx.beginPage(); y = 40 }
                req.draw(at: CGPoint(x: 50, y: y), withAttributes: smallAttrs)
                value.draw(at: CGPoint(x: 350, y: y), withAttributes: smallAttrs)
                (passed ? "PASS" : "FAIL").draw(at: CGPoint(x: 500, y: y), withAttributes: passed ? passAttrs : failAttrs)
                y += 16
            }

            y += 20

            // Weekly Hours Chart (simple text version)
            if y > 600 { ctx.beginPage(); y = 40 }
            "Weekly Hours".draw(at: CGPoint(x: 40, y: y), withAttributes: headerAttrs)
            y += 20

            for (week, hours) in data.complianceSummary.weeklyHoursByWeek.sorted(by: { $0.key > $1.key }).prefix(8) {
                if y > 720 { ctx.beginPage(); y = 40 }
                week.draw(at: CGPoint(x: 50, y: y), withAttributes: smallAttrs)

                // Draw bar
                let barWidth = min(300, (hours / 100) * 300)
                let barColor = hours > 80 ? UIColor.systemRed : (hours > 76 ? UIColor.systemOrange : UIColor.systemGreen)
                ctx.cgContext.setFillColor(barColor.cgColor)
                ctx.cgContext.fill(CGRect(x: 150, y: y, width: barWidth, height: 12))

                String(format: "%.0f hrs", hours).draw(at: CGPoint(x: 460, y: y), withAttributes: smallAttrs)
                y += 18
            }

            // Recent Shifts (new page if needed)
            ctx.beginPage()
            y = 40
            "Recent Shifts".draw(at: CGPoint(x: 40, y: y), withAttributes: headerAttrs)
            y += 20

            // Column headers
            "Date".draw(at: CGPoint(x: 50, y: y), withAttributes: subHeaderAttrs)
            "Type".draw(at: CGPoint(x: 140, y: y), withAttributes: subHeaderAttrs)
            "Location".draw(at: CGPoint(x: 260, y: y), withAttributes: subHeaderAttrs)
            "Time".draw(at: CGPoint(x: 350, y: y), withAttributes: subHeaderAttrs)
            "Duration".draw(at: CGPoint(x: 480, y: y), withAttributes: subHeaderAttrs)
            y += 16

            // Draw line
            ctx.cgContext.setStrokeColor(UIColor.gray.cgColor)
            ctx.cgContext.setLineWidth(0.5)
            ctx.cgContext.move(to: CGPoint(x: 40, y: y))
            ctx.cgContext.addLine(to: CGPoint(x: 572, y: y))
            ctx.cgContext.strokePath()
            y += 8

            for shift in data.shifts.sorted(by: { $0.shiftDate > $1.shiftDate }).prefix(30) {
                if y > 720 { ctx.beginPage(); y = 40 }

                shift.shiftDate.formatted(date: .numeric, time: .omitted).draw(at: CGPoint(x: 50, y: y), withAttributes: smallAttrs)
                shift.shiftType.displayName.draw(at: CGPoint(x: 140, y: y), withAttributes: smallAttrs)
                shift.location.displayName.draw(at: CGPoint(x: 260, y: y), withAttributes: smallAttrs)

                let timeRange = "\(shift.startTime.formatted(date: .omitted, time: .shortened)) - \(shift.endTime?.formatted(date: .omitted, time: .shortened) ?? "Active")"
                timeRange.draw(at: CGPoint(x: 350, y: y), withAttributes: smallAttrs)

                String(format: "%.1f hrs", shift.effectiveDurationHours).draw(at: CGPoint(x: 480, y: y), withAttributes: smallAttrs)
                y += 14
            }
        }

        let safeName = data.fellowName.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName)_ACGME_duty_hours.pdf")
        try? pdfData.write(to: url)
        return url
    }

    // MARK: - Program-Wide Duty Hours Summary Export

    struct ProgramDutyHoursSummary {
        let programName: String
        let periodStart: Date
        let periodEnd: Date
        let fellowSummaries: [FellowSummaryRow]

        struct FellowSummaryRow {
            let fellowName: String
            let pgyLevel: Int
            let avgWeeklyHours: Double
            let daysOff: Int
            let totalShifts: Int
            let isCompliant: Bool
            let violationCount: Int
            let warningCount: Int
        }
    }

    func exportProgramDutyHoursSummaryToCSV(_ data: ProgramDutyHoursSummary, filename: String) -> URL? {
        var csv = "PROGRAM DUTY HOURS SUMMARY\n"
        csv += "Program,\(escape(data.programName))\n"
        csv += "Period,\(data.periodStart.formatted(date: .abbreviated, time: .omitted)) - \(data.periodEnd.formatted(date: .abbreviated, time: .omitted))\n"
        csv += "Generated,\(Date().formatted())\n\n"

        csv += "Fellow,PGY,Avg Weekly Hours,Days Off,Total Shifts,Status,Violations,Warnings\n"
        for row in data.fellowSummaries.sorted(by: { !$0.isCompliant && $1.isCompliant }) {
            csv += "\(escape(row.fellowName)),"
            csv += "\(row.pgyLevel),"
            csv += "\(String(format: "%.1f", row.avgWeeklyHours)),"
            csv += "\(row.daysOff),"
            csv += "\(row.totalShifts),"
            csv += "\(row.isCompliant ? "Compliant" : "Non-Compliant"),"
            csv += "\(row.violationCount),"
            csv += "\(row.warningCount)\n"
        }

        return saveFile(csv, filename: "\(filename).csv")
    }

    private func escape(_ s: String) -> String {
        s.contains(",") || s.contains("\"") ? "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\"" : s
    }

    private func saveFile(_ content: String, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

class ShareSheetPresenter {
    static func present(url: URL) {
        DispatchQueue.main.async {
            let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                if let pop = vc.popoverPresentationController {
                    pop.sourceView = root.view
                    pop.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
                }
                root.present(vc, animated: true)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
