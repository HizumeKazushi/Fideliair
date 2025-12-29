import SwiftUI
import Combine

/// Manages access to Google Drive via local mount point
@MainActor
class GoogleDriveManager: ObservableObject {
    @Published var isConnected = false
    @Published var driveRootURL: URL?
    @AppStorage("googleDrivePath") private var savedDrivePath: String = ""
    
    init() {
        if !savedDrivePath.isEmpty {
            let url = URL(fileURLWithPath: savedDrivePath)
            if FileManager.default.fileExists(atPath: url.path) {
                print("Restoring Google Drive path: \(url.path)")
                self.driveRootURL = url
                self.isConnected = true
            }
        }
    }
    
    /// Connect to a local folder (Google Drive mount)
    func connect(to url: URL) {
        // Security scoping is less critical if user selects via NSOpenPanel which grants permission,
        // but for persistence we assume standard file access.
        // For Sandbox apps, we'd need Security-Scoped Bookmarks, 
        // but assuming we are building a standard macOS app for now or using user-selected folder.
        
        self.driveRootURL = url
        self.savedDrivePath = url.path
        self.isConnected = true
        print("Connected to Drive at: \(url.path)")
    }
    
    /// Disconnect
    func disconnect() {
        self.driveRootURL = nil
        self.savedDrivePath = ""
        self.isConnected = false
    }
    
    /// List contents of a directory
    func contents(of url: URL) -> [DriveItem] {
        guard url.startAccessingSecurityScopedResource() else {
            // Try without security scope if it fails or isn't needed
            return listFiles(at: url)
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return listFiles(at: url)
    }
    
    private func listFiles(at url: URL) -> [DriveItem] {
        do {
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .localizedNameKey]
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles])
            
            return contents.compactMap { url -> DriveItem? in
                // Filter invisible files/folders safely
                if url.lastPathComponent.hasPrefix(".") { return nil }
                
                let resources = try? url.resourceValues(forKeys: Set(resourceKeys))
                let isDirectory = resources?.isDirectory ?? false
                let name = resources?.localizedName ?? url.lastPathComponent
                
                // Allow folders or audio files
                if isDirectory {
                    return DriveItem(id: url.path, name: name, url: url, isFolder: true)
                } else if isAudioFile(url) {
                    return DriveItem(id: url.path, name: name, url: url, isFolder: false)
                }
                return nil
            }.sorted { 
                // Folders first, then alphabetical
                if $0.isFolder && !$1.isFolder { return true }
                if !$0.isFolder && $1.isFolder { return false }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        } catch {
            print("Error listing contents: \(error)")
            return []
        }
    }
    
    private func isAudioFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mp3", "m4a", "flac", "wav", "aiff", "aac", "alac"].contains(ext)
    }
}

struct DriveItem: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
    let isFolder: Bool
}
