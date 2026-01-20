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
    }
    
    struct ProcedureCountRow {
        let category: String
        let procedure: String
        let count: Int
    }
    
    // MARK: - CSV Export
    
    func exportToCSV(rows: [CaseExportRow], filename: String) -> URL? {
        var csv = "Fellow,Attending,Facility,Week,Procedures,Count,Access Sites,Complications,Outcome,Status,Attested,Created\n"
        for row in rows {
            csv += "\(escape(row.fellowName)),\(escape(row.attendingName)),\(escape(row.facilityName)),\(row.weekBucket),\(escape(row.procedures)),\(row.procedureCount),\(escape(row.accessSites)),\(escape(row.complications)),\(row.outcome),\(row.attestationStatus),\(row.attestedDate),\(row.createdDate)\n"
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
        var content = "Fellow\tAttending\tFacility\tWeek\tProcedures\tCount\tAccess Sites\tComplications\tOutcome\tStatus\tAttested\tCreated\n"
        for row in rows {
            content += "\(row.fellowName)\t\(row.attendingName)\t\(row.facilityName)\t\(row.weekBucket)\t\(row.procedures)\t\(row.procedureCount)\t\(row.accessSites)\t\(row.complications)\t\(row.outcome)\t\(row.attestationStatus)\t\(row.attestedDate)\t\(row.createdDate)\n"
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
