import SwiftUI
import AVFoundation

// MARK: - Track Model
struct Track: Identifiable, Hashable {
    let id: UUID
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var fileURL: URL?
    var artwork: NSImage?
    var trackNumber: Int?
    var discNumber: Int?
    var genre: String?
    var year: Int?
    var isFavorite: Bool = false
    
    // Extended metadata
    var albumArtist: String?
    var composer: String?
    var copyright: String?
    var bpm: Int?
    var comment: String?
    var lyrics: String?
    var bitrate: Int?
    var sampleRate: Int?
    var channels: Int?
    var encoder: String?
    
    // For Google Drive tracks
    var googleDriveFileId: String?
    var isCloudTrack: Bool { googleDriveFileId != nil }
    var isCached: Bool = false
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Album Model
struct Album: Identifiable {
    let id: UUID
    var name: String
    var artist: String
    var tracks: [Track]
    var artwork: NSImage?
    var year: Int?
    var genre: String?
    
    var duration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }
    
    var trackCount: Int {
        tracks.count
    }
}

// MARK: - Artist Model
struct Artist: Identifiable, Hashable {
    let id: UUID
    var name: String
    var albums: [Album]
    var artwork: NSImage?
    
    var trackCount: Int {
        albums.reduce(0) { $0 + $1.trackCount }
    }
    
    var albumCount: Int {
        albums.count
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Artist, rhs: Artist) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Playlist Model
struct Playlist: Identifiable, Hashable {
    let id: UUID
    var name: String
    var tracks: [Track]
    var createdDate: Date
    var modifiedDate: Date
    var artwork: NSImage?
    
    var duration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }
    
    init(id: UUID = UUID(), name: String, tracks: [Track] = []) {
        self.id = id
        self.name = name
        self.tracks = tracks
        self.createdDate = Date()
        self.modifiedDate = Date()
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Lyrics Model
struct LyricLine: Identifiable {
    let id: UUID
    var timestamp: TimeInterval
    var text: String
    
    init(timestamp: TimeInterval, text: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.text = text
    }
}

struct Lyrics: Identifiable {
    let id = UUID()
    var lines: [LyricLine]
    var isSynced: Bool { !lines.isEmpty && lines.first?.timestamp != nil }
    
    init(lines: [LyricLine] = []) {
        self.lines = lines.sorted { $0.timestamp < $1.timestamp }
    }
    
    /// Parse LRC format lyrics
    static func parse(lrc: String) -> Lyrics {
        var lines: [LyricLine] = []
        let pattern = #"\[(\d{2}):(\d{2})\.(\d{2,3})\](.+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        
        for line in lrc.components(separatedBy: .newlines) {
            guard let match = regex?.firstMatch(
                in: line,
                range: NSRange(line.startIndex..., in: line)
            ) else { continue }
            
            guard let minRange = Range(match.range(at: 1), in: line),
                  let secRange = Range(match.range(at: 2), in: line),
                  let msRange = Range(match.range(at: 3), in: line),
                  let textRange = Range(match.range(at: 4), in: line) else { continue }
            
            let minutes = Double(line[minRange]) ?? 0
            let seconds = Double(line[secRange]) ?? 0
            let milliseconds = Double(line[msRange]) ?? 0
            let msMultiplier = line[msRange].count == 2 ? 10 : 1
            
            let timestamp = minutes * 60 + seconds + (milliseconds * Double(msMultiplier)) / 1000
            let text = String(line[textRange]).trimmingCharacters(in: .whitespaces)
            
            lines.append(LyricLine(timestamp: timestamp, text: text))
        }
        
        return Lyrics(lines: lines)
    }
    
    /// Get the current line index for a given time
    func currentLineIndex(for time: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        
        for (index, line) in lines.enumerated().reversed() {
            if time >= line.timestamp {
                return index
            }
        }
        return 0
    }
}
