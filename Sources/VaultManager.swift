import Foundation
import UserNotifications

class VaultManager {
    static let shared = VaultManager()
    
    private let vaultPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("ConversationVault")
    
    init() {
        if !FileManager.default.fileExists(atPath: vaultPath.path) {
            try? FileManager.default.createDirectory(at: vaultPath, withIntermediateDirectories: true)
        }
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            }
        }
    }
    
    func createSession() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let sessionName = formatter.string(from: Date()) + "_Session"
        let sessionPath = vaultPath.appendingPathComponent(sessionName)
        try? FileManager.default.createDirectory(at: sessionPath, withIntermediateDirectories: true)
        return sessionPath
    }
    
    func saveSession(sessionPath: URL, jsonString: String) {
        let jsonPath = sessionPath.appendingPathComponent("result.json")
        try? jsonString.write(to: jsonPath, atomically: true, encoding: .utf8)
        
        print("Session saved to vault at: \(sessionPath.path)")
        sendNotification(sessionName: sessionPath.lastPathComponent)
    }
    
    private func sendNotification(sessionName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Conversation Capture"
        content.body = "Session summary saved: \(sessionName)"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \\(error)")
            }
        }
    }
}
