// PushNotificationManager.swift
// Procedus - Unified

import Foundation
import UserNotifications
import UIKit
import Combine

@MainActor
class PushNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationManager()
    
    @Published var isAuthorized = false
    @Published var deviceToken: String?
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task { await checkAuthorizationStatus() }
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            if granted { await MainActor.run { UIApplication.shared.registerForRemoteNotifications() } }
            return granted
        } catch { return false }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    func handleDeviceToken(_ token: Data) {
        deviceToken = token.map { String(format: "%02.2hhx", $0) }.joined()
    }
    
    func handleRegistrationError(_ error: Error) {
        print("Push registration error: \(error)")
    }
    
    // MARK: - Local Notifications
    
    func scheduleWeeklyLogReminder(fellowId: UUID) {
        let content = UNMutableNotificationContent()
        content.title = "Weekly Log Reminder"
        content.body = "Don't forget to log your procedures for this week!"
        content.sound = .default
        
        var dc = DateComponents()
        dc.weekday = 6 // Friday
        dc.hour = 17
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly-\(fellowId)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleAttestationReminder(caseId: UUID, fellowName: String, procedureCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Attestation Requested"
        content.body = "\(fellowName) submitted \(procedureCount) procedure(s) for attestation"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "attest-\(caseId)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func notifyAttestationComplete(caseId: UUID, status: String, fellowId: UUID) {
        let content = UNMutableNotificationContent()
        content.title = status == "attested" ? "Case Attested" : "Case Rejected"
        content.body = status == "attested" ? "Your case has been attested." : "Your case was rejected. Check for details."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "complete-\(caseId)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func notifyAttestationRejected(caseId: UUID, reason: String, fellowId: UUID) {
        let content = UNMutableNotificationContent()
        content.title = "Case Rejected"
        content.body = "Your case was rejected. Reason: \(reason.prefix(100))"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "rejected-\(caseId)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    
    func setBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        // Handle notification tap
    }
}
