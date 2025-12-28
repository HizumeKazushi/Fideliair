import SwiftUI
import AppKit

/// Metadata search service with album art fetching
@MainActor
class MetadataSearchService: ObservableObject {
    @Published var searchResults: [MetadataSearchResult] = []
    @Published var isSearching = false
    @Published var error: String?
    
    // MARK: - Search Methods
    
    /// Search using query string
    func search(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        error = nil
        
        await searchMusicBrainz(query: query)
        
        isSearching = false
    }
    
    /// Search using title and artist
    func search(title: String, artist: String) async {
        let query = "\(title) \(artist)".trimmingCharacters(in: .whitespaces)
        await search(query: query)
    }
    
    /// Search from filename
    func searchFromFilename(_ filename: String) async {
        // Remove extension
        let name = (filename as NSString).deletingPathExtension
        
        // Common patterns: "Artist - Title", "01 Title", "01. Title", etc.
        var cleanedName = name
        
        // Remove track numbers at start (01, 01., 01 -, etc.)
        let trackNumberPattern = #"^\d{1,3}[\.\-\s]*"#
        if let regex = try? NSRegularExpression(pattern: trackNumberPattern) {
            let range = NSRange(cleanedName.startIndex..., in: cleanedName)
            cleanedName = regex.stringByReplacingMatches(in: cleanedName, range: range, withTemplate: "")
        }
        
        // Try to split "Artist - Title" pattern
        if cleanedName.contains(" - ") {
            let parts = cleanedName.components(separatedBy: " - ")
            if parts.count >= 2 {
                let artist = parts[0].trimmingCharacters(in: .whitespaces)
                let title = parts[1...].joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                await search(title: title, artist: artist)
                return
            }
        }
        
        // Replace underscores with spaces
        cleanedName = cleanedName.replacingOccurrences(of: "_", with: " ")
        
        await search(query: cleanedName)
    }
    
    // MARK: - MusicBrainz API
    
    private func searchMusicBrainz(query: String) async {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://musicbrainz.org/ws/2/recording?query=\(encodedQuery)&limit=10&fmt=json"
        
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Fideliair/1.0 (contact@fideliair.app)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                error = "Search failed"
                return
            }
            
            let mbResponse = try JSONDecoder().decode(MusicBrainzResponse.self, from: data)
            
            var results: [MetadataSearchResult] = []
            
            for recording in mbResponse.recordings {
                let artistName = recording.artistCredit?.first?.name ?? "Unknown Artist"
                let release = recording.releases?.first
                let albumName = release?.title ?? ""
                let year = extractYear(from: release?.date)
                let releaseId = release?.id
                
                let result = MetadataSearchResult(
                    id: recording.id,
                    title: recording.title,
                    artist: artistName,
                    album: albumName,
                    year: year,
                    releaseId: releaseId,
                    source: "MusicBrainz"
                )
                results.append(result)
            }
            
            searchResults = results
            
            // Auto-fetch artwork for first 5 results
            await fetchArtworkForResults()
            
        } catch {
            self.error = error.localizedDescription
            print("MusicBrainz search error: \(error)")
        }
    }
    
    /// Fetch artwork for first 5 results that have releaseId
    private func fetchArtworkForResults() async {
        for i in 0..<min(5, searchResults.count) {
            if let releaseId = searchResults[i].releaseId {
                if let artwork = await fetchAlbumArt(releaseId: releaseId) {
                    searchResults[i].artwork = artwork
                }
            }
        }
    }
    
    // MARK: - Cover Art Archive API
    
    /// Fetch album artwork from Cover Art Archive
    func fetchAlbumArt(releaseId: String) async -> NSImage? {
        let urlString = "https://coverartarchive.org/release/\(releaseId)/front-250"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Fideliair/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            return NSImage(data: data)
        } catch {
            print("Cover Art fetch error: \(error)")
            return nil
        }
    }
    
    private func extractYear(from dateString: String?) -> Int? {
        guard let date = dateString, date.count >= 4 else { return nil }
        return Int(date.prefix(4))
    }
}

// MARK: - Search Result Model

struct MetadataSearchResult: Identifiable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let year: Int?
    let releaseId: String?
    let source: String
    var artwork: NSImage? = nil
}

// MARK: - MusicBrainz Response Models

struct MusicBrainzResponse: Codable {
    let recordings: [MBRecording]
}

struct MBRecording: Codable {
    let id: String
    let title: String
    let artistCredit: [MBArtistCredit]?
    let releases: [MBRelease]?
    
    enum CodingKeys: String, CodingKey {
        case id, title
        case artistCredit = "artist-credit"
        case releases
    }
}

struct MBArtistCredit: Codable {
    let name: String
}

struct MBRelease: Codable {
    let id: String
    let title: String
    let date: String?
}
