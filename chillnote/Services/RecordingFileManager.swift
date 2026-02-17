import Foundation
import AVFoundation

extension Notification.Name {
    static let pendingRecordingsDidChange = Notification.Name("PendingRecordingsDidChange")
}

/// Manages the lifecycle of recording files with crash recovery support
/// Files are stored in a "safe" directory and cleaned up after successful transcription
final class RecordingFileManager {
    static let shared = RecordingFileManager()
    
    // MARK: - Constants
    
    private let pendingRecordingsKey = "PendingRecordings"
    private let maxFileAgeHours: TimeInterval = 24 * 7
    
    // MARK: - Directory
    
    /// Directory for pending recordings (Library/Application Support/PendingRecordings)
    /// Not backed up to iCloud, but persists across app launches
    private var pendingRecordingsDirectory: URL {
        get throws {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let recordingsDir = appSupport.appendingPathComponent("PendingRecordings", isDirectory: true)
            
            // Create directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: recordingsDir.path) {
                try FileManager.default.createDirectory(
                    at: recordingsDir,
                    withIntermediateDirectories: true
                )
            }
            
            return recordingsDir
        }
    }
    
    // MARK: - Public API
    
    /// Creates a new recording file URL.
    /// - parameter markPending: whether to immediately add this path to recovery tracking.
    func createRecordingURL(ext: String = "m4a", markPending: Bool = true) throws -> URL {
        let directory = try pendingRecordingsDirectory
        let fileName = "\(UUID().uuidString)_\(Date().timeIntervalSince1970).\(ext)"
        let fileURL = directory.appendingPathComponent(fileName)
        
        if markPending {
            markAsPending(fileURL: fileURL)
        }
        
        print("📁 Created recording at: \(fileURL.path)")
        return fileURL
    }

    /// Marks an existing recording file path as pending (for crash recovery).
    func markPending(fileURL: URL) {
        markAsPending(fileURL: fileURL)
    }
    
    /// Marks a recording as successfully processed and deletes it
    func completeRecording(fileURL: URL) {
        // Remove from pending list
        clearPending(fileURL: fileURL)
        
        // Delete the file
        try? FileManager.default.removeItem(at: fileURL)
        print("✅ Cleaned up recording: \(fileURL.lastPathComponent)")
    }
    
    /// Cancels a recording and deletes it
    func cancelRecording(fileURL: URL) {
        clearPending(fileURL: fileURL)
        try? FileManager.default.removeItem(at: fileURL)
        print("❌ Cancelled recording: \(fileURL.lastPathComponent)")
    }
    
    /// Checks for any pending recordings from previous sessions (crash recovery)
    func checkForPendingRecordings() -> [PendingRecording] {
        let pendingPaths = UserDefaults.standard.stringArray(forKey: pendingRecordingsKey) ?? []
        var validRecordings: [PendingRecording] = []
        
        for path in pendingPaths {
            let url = URL(fileURLWithPath: path)
            
            // Check if file exists and get its creation date
            if FileManager.default.fileExists(atPath: path),
               let attributes = try? FileManager.default.attributesOfItem(atPath: path),
               let creationDate = attributes[.creationDate] as? Date {
                
                validRecordings.append(PendingRecording(
                    fileURL: url,
                    createdAt: creationDate,
                    duration: recordingDuration(for: url) ?? 0
                ))
            }
        }
        
        return validRecordings
    }

    /// Returns current pending recordings after cleanup, with optional filtering and sorting.
    func pendingRecordings(excludingPath: String? = nil, sortedByNewest: Bool = false) -> [PendingRecording] {
        cleanupOldRecordings()

        var pending = checkForPendingRecordings()

        if let excludingPath {
            pending.removeAll { $0.fileURL.path == excludingPath }
        }

        if sortedByNewest {
            pending.sort { $0.createdAt > $1.createdAt }
        }

        return pending
    }
    
    /// Removes a recording from recovery tracking without deleting the file.
    func clearPendingReference(fileURL: URL) {
        clearPending(fileURL: fileURL)
    }
    
    /// Clean up old recordings (older than maxFileAgeHours)
    func cleanupOldRecordings() {
        guard let directory = try? pendingRecordingsDirectory else { return }
        
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        let now = Date()
        var cleanedCount = 0
        
        for fileURL in files {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let creationDate = attributes[.creationDate] as? Date else {
                continue
            }
            
            let ageInHours = now.timeIntervalSince(creationDate) / 3600
            
            if ageInHours > maxFileAgeHours {
                try? fileManager.removeItem(at: fileURL)
                clearPending(fileURL: fileURL)
                cleanedCount += 1
                print("🧹 Cleaned up old recording: \(fileURL.lastPathComponent)")
            }
        }
        
        if cleanedCount > 0 {
            print("🧹 Total cleaned: \(cleanedCount) old recordings")
        }
    }
    
    // MARK: - Private Helpers
    
    private func markAsPending(fileURL: URL) {
        var pending = UserDefaults.standard.stringArray(forKey: pendingRecordingsKey) ?? []
        let path = fileURL.path
        
        if !pending.contains(path) {
            pending.append(path)
            UserDefaults.standard.set(pending, forKey: pendingRecordingsKey)
            print("🔒 Marked as pending: \(fileURL.lastPathComponent)")
            NotificationCenter.default.post(name: .pendingRecordingsDidChange, object: nil)
        }
    }
    
    private func clearPending(fileURL: URL) {
        var pending = UserDefaults.standard.stringArray(forKey: pendingRecordingsKey) ?? []
        let path = fileURL.path
        
        if let index = pending.firstIndex(of: path) {
            pending.remove(at: index)
            UserDefaults.standard.set(pending, forKey: pendingRecordingsKey)
            print("🔓 Cleared pending: \(fileURL.lastPathComponent)")
            NotificationCenter.default.post(name: .pendingRecordingsDidChange, object: nil)
        }
    }

    private func recordingDuration(for fileURL: URL) -> TimeInterval? {
        guard let audioPlayer = try? AVAudioPlayer(contentsOf: fileURL) else {
            return nil
        }
        let seconds = audioPlayer.duration
        guard seconds.isFinite, seconds > 0 else { return nil }
        return seconds
    }
}

// MARK: - Data Types

struct PendingRecording: Identifiable {
    let id = UUID()
    let fileURL: URL
    let createdAt: Date
    let duration: TimeInterval
    
    var fileName: String {
        fileURL.lastPathComponent
    }
    
    var durationText: String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
