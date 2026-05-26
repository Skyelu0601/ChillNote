import Foundation
import AVFoundation
import OSLog

extension Notification.Name {
    static let pendingRecordingsDidChange = Notification.Name("PendingRecordingsDidChange")
    /// Posted after a pending recording is successfully saved as a Note.
    /// userInfo key "noteID": UUID of the newly created Note.
    static let pendingRecordingNoteCreated = Notification.Name("PendingRecordingNoteCreated")
}

/// Manages the lifecycle of recording files with crash recovery support
/// Files are stored in a "safe" directory and cleaned up after successful transcription
final class RecordingFileManager {
    static let shared = RecordingFileManager()
    private static let logger = Logger(subsystem: "com.chillnote.app", category: "recording-files")
    
    // MARK: - Constants
    
    private let pendingRecordingsKey = "PendingRecordings"
    /// Maps fileURL.path → Note UUID string for crash-recovery linking.
    private let pendingNoteIDsKey = "PendingRecordingNoteIDs"
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
        
        Self.logger.debug("Created recording at \(fileURL.path, privacy: .private)")
        return fileURL
    }

    /// Marks an existing recording file path as pending (for crash recovery).
    func markPending(fileURL: URL) {
        markAsPending(fileURL: fileURL)
    }

    /// Associates a Note ID with a pending recording so it can be found on recovery.
    func setNoteID(_ noteID: UUID, for fileURL: URL) {
        var mapping = noteIDMapping()
        mapping[fileURL.path] = noteID.uuidString
        UserDefaults.standard.set(mapping, forKey: pendingNoteIDsKey)
        Self.logger.debug("Linked note \(noteID.uuidString, privacy: .private) to recording \(fileURL.lastPathComponent, privacy: .private)")
    }

    /// Returns the Note ID previously linked to this recording file, if any.
    func noteID(for fileURL: URL) -> UUID? {
        guard let uuidString = noteIDMapping()[fileURL.path] else { return nil }
        return UUID(uuidString: uuidString)
    }
    
    /// Marks a recording as successfully processed and deletes it
    func completeRecording(fileURL: URL) {
        // Remove from pending list
        clearPending(fileURL: fileURL)
        
        // Delete the file
        removeRecordingFile(fileURL, action: "complete")
        Self.logger.debug("Cleaned up recording \(fileURL.lastPathComponent, privacy: .private)")
    }
    
    /// Cancels a recording and deletes it
    func cancelRecording(fileURL: URL) {
        clearPending(fileURL: fileURL)
        removeRecordingFile(fileURL, action: "cancel")
        Self.logger.debug("Cancelled recording \(fileURL.lastPathComponent, privacy: .private)")
    }
    
    /// Checks for any pending recordings from previous sessions (crash recovery)
    func checkForPendingRecordings() -> [PendingRecording] {
        let pendingPaths = UserDefaults.standard.stringArray(forKey: pendingRecordingsKey) ?? []
        var validRecordings: [PendingRecording] = []
        
        for path in pendingPaths {
            let url = URL(fileURLWithPath: path)

            guard FileManager.default.fileExists(atPath: path) else {
                Self.logger.debug("Pending recording no longer exists: \(url.lastPathComponent, privacy: .private)")
                continue
            }

            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: path)
                guard let creationDate = attributes[.creationDate] as? Date else {
                    Self.logger.warning("Pending recording has no creation date: \(url.lastPathComponent, privacy: .private)")
                    continue
                }

                validRecordings.append(PendingRecording(
                    fileURL: url,
                    createdAt: creationDate,
                    duration: recordingDuration(for: url) ?? 0
                ))
            } catch {
                Self.logger.error("Unable to read pending recording attributes: \(error.localizedDescription, privacy: .public)")
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
        let directory: URL
        do {
            directory = try pendingRecordingsDirectory
        } catch {
            Self.logger.error("Unable to resolve pending recordings directory: \(error.localizedDescription, privacy: .public)")
            return
        }
        
        let fileManager = FileManager.default
        let files: [URL]
        do {
            files = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            Self.logger.error("Unable to list pending recordings: \(error.localizedDescription, privacy: .public)")
            return
        }
        
        let now = Date()
        var cleanedCount = 0
        
        for fileURL in files {
            let attributes: [FileAttributeKey: Any]
            do {
                attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            } catch {
                Self.logger.error("Unable to read recording attributes during cleanup: \(error.localizedDescription, privacy: .public)")
                continue
            }

            guard let creationDate = attributes[.creationDate] as? Date else {
                Self.logger.warning("Recording has no creation date during cleanup: \(fileURL.lastPathComponent, privacy: .private)")
                continue
            }
            
            let ageInHours = now.timeIntervalSince(creationDate) / 3600
            
            if ageInHours > maxFileAgeHours {
                removeRecordingFile(fileURL, action: "cleanup")
                clearPending(fileURL: fileURL)
                cleanedCount += 1
                Self.logger.debug("Cleaned up old recording \(fileURL.lastPathComponent, privacy: .private)")
            }
        }
        
        if cleanedCount > 0 {
            Self.logger.info("Cleaned up \(cleanedCount, privacy: .public) old recordings")
        }
    }
    
    // MARK: - Private Helpers
    
    private func markAsPending(fileURL: URL) {
        var pending = UserDefaults.standard.stringArray(forKey: pendingRecordingsKey) ?? []
        let path = fileURL.path
        
        if !pending.contains(path) {
            pending.append(path)
            UserDefaults.standard.set(pending, forKey: pendingRecordingsKey)
            Self.logger.debug("Marked recording as pending \(fileURL.lastPathComponent, privacy: .private)")
            NotificationCenter.default.post(name: .pendingRecordingsDidChange, object: nil)
        }
    }
    
    private func clearPending(fileURL: URL) {
        var pending = UserDefaults.standard.stringArray(forKey: pendingRecordingsKey) ?? []
        let path = fileURL.path
        
        if let index = pending.firstIndex(of: path) {
            pending.remove(at: index)
            UserDefaults.standard.set(pending, forKey: pendingRecordingsKey)

            // Also remove the noteID link
            var mapping = noteIDMapping()
            mapping.removeValue(forKey: path)
            UserDefaults.standard.set(mapping, forKey: pendingNoteIDsKey)

            Self.logger.debug("Cleared pending recording \(fileURL.lastPathComponent, privacy: .private)")
            NotificationCenter.default.post(name: .pendingRecordingsDidChange, object: nil)
        }
    }

    private func noteIDMapping() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: pendingNoteIDsKey) as? [String: String] ?? [:]
    }

    private func removeRecordingFile(_ fileURL: URL, action: String) {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch CocoaError.fileNoSuchFile {
            Self.logger.debug("Recording already removed during \(action, privacy: .public): \(fileURL.lastPathComponent, privacy: .private)")
        } catch {
            Self.logger.error("Failed to remove recording during \(action, privacy: .public): \(error.localizedDescription, privacy: .public)")
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
