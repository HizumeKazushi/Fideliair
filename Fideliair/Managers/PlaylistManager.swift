import SwiftUI
import Combine

/// Manages playlist persistence using JSON storage
@MainActor
class PlaylistManager: ObservableObject {
    @Published var playlists: [Playlist] = []
    
    private let fileURL: URL
    
    init() {
        // ~/Library/Application Support/Fideliair/playlists.json
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Fideliair", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        
        self.fileURL = appDir.appendingPathComponent("playlists.json")
        
        loadPlaylists()
    }
    
    // MARK: - Persistence
    
    func loadPlaylists() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let stored = try JSONDecoder().decode([StoredPlaylist].self, from: data)
            
            // Convert stored playlists to Playlist objects
            self.playlists = stored.map { $0.toPlaylist() }
        } catch {
            print("Failed to load playlists: \(error)")
        }
    }
    
    func savePlaylists() {
        do {
            let stored = playlists.map { StoredPlaylist(from: $0) }
            let data = try JSONEncoder().encode(stored)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save playlists: \(error)")
        }
    }
    
    // MARK: - Playlist Operations
    
    func createPlaylist(name: String, tracks: [Track] = []) -> Playlist {
        var playlist = Playlist(name: name)
        playlist.tracks = tracks
        playlists.append(playlist)
        savePlaylists()
        return playlist
    }
    
    func deletePlaylist(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        savePlaylists()
    }
    
    func renamePlaylist(_ playlist: Playlist, to newName: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].name = newName
        playlists[index].modifiedDate = Date()
        savePlaylists()
    }
    
    // MARK: - Track Operations
    
    func addTrack(_ track: Track, to playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        
        // Avoid duplicates
        guard !playlists[index].tracks.contains(where: { $0.id == track.id }) else { return }
        
        playlists[index].tracks.append(track)
        playlists[index].modifiedDate = Date()
        savePlaylists()
    }
    
    func addTracks(_ tracks: [Track], to playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        
        for track in tracks {
            if !playlists[index].tracks.contains(where: { $0.id == track.id }) {
                playlists[index].tracks.append(track)
            }
        }
        playlists[index].modifiedDate = Date()
        savePlaylists()
    }
    
    func removeTrack(_ track: Track, from playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].tracks.removeAll { $0.id == track.id }
        playlists[index].modifiedDate = Date()
        savePlaylists()
    }
    
    func moveTrack(in playlist: Playlist, from source: IndexSet, to destination: Int) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].tracks.move(fromOffsets: source, toOffset: destination)
        playlists[index].modifiedDate = Date()
        savePlaylists()
    }
}

// MARK: - Stored Models (Codable)

/// Lightweight codable version of Playlist for JSON storage
private struct StoredPlaylist: Codable {
    let id: UUID
    var name: String
    var trackPaths: [String] // Store file paths instead of full Track objects
    var createdDate: Date
    var modifiedDate: Date
    
    init(from playlist: Playlist) {
        self.id = playlist.id
        self.name = playlist.name
        self.trackPaths = playlist.tracks.compactMap { $0.fileURL?.path }
        self.createdDate = playlist.createdDate
        self.modifiedDate = playlist.modifiedDate
    }
    
    func toPlaylist() -> Playlist {
        var playlist = Playlist(id: id, name: name)
        playlist.createdDate = createdDate
        playlist.modifiedDate = modifiedDate
        
        // Tracks will be populated when LibraryManager scans
        // For now, store paths as placeholder tracks
        playlist.tracks = trackPaths.compactMap { path in
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            
            // Create minimal track with just URL - metadata will be loaded separately
            return Track(
                id: UUID(),
                title: url.deletingPathExtension().lastPathComponent,
                artist: "Unknown",
                album: "Unknown",
                duration: 0,
                fileURL: url
            )
        }
        
        return playlist
    }
}
