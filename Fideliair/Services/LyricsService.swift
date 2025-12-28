import SwiftUI

/// Lyrics service for fetching synchronized lyrics from APIs
@MainActor
class LyricsService: ObservableObject {
    @Published var currentLyrics: Lyrics?
    @Published var isLoading = false
    @Published var error: String?
    
    private var cache: [String: Lyrics] = [:]
    
    // MARK: - Fetch Lyrics
    func fetchLyrics(for track: Track) async {
        let cacheKey = "\(track.artist)-\(track.title)"
        
        // Check cache first
        if let cached = cache[cacheKey] {
            currentLyrics = cached
            return
        }
        
        isLoading = true
        error = nil
        
        // Try to load from local .lrc file first
        if let lyrics = loadLocalLyrics(for: track) {
            cache[cacheKey] = lyrics
            currentLyrics = lyrics
            isLoading = false
            return
        }
        
        // Try LRCLIB API (free, open)
        if let lyrics = await fetchFromLRCLIB(artist: track.artist, title: track.title) {
            cache[cacheKey] = lyrics
            currentLyrics = lyrics
            isLoading = false
            return
        }
        
        // No lyrics found
        currentLyrics = nil
        isLoading = false
    }
    
    // MARK: - Local Lyrics
    private func loadLocalLyrics(for track: Track) -> Lyrics? {
        guard let url = track.fileURL else { return nil }
        
        // Look for .lrc file with same name
        let lrcURL = url.deletingPathExtension().appendingPathExtension("lrc")
        
        guard FileManager.default.fileExists(atPath: lrcURL.path),
              let content = try? String(contentsOf: lrcURL, encoding: .utf8) else {
            return nil
        }
        
        return Lyrics.parse(lrc: content)
    }
    
    // MARK: - LRCLIB API
    private func fetchFromLRCLIB(artist: String, title: String) async -> Lyrics? {
        // Use search endpoint for better results (handle feat., etc.)
        let baseURL = "https://lrclib.net/api/search"
        
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: title)
        ]
        
        guard let url = components?.url else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let decoder = JSONDecoder()
            // Search returns an array of matches
            let searchResults = try decoder.decode([LRCLIBResponse].self, from: data)
            
            // Filter and sort results
            // 1. Prefer synced lyrics
            // 2. Prefer instrumental matches if specified (not handled here but good to know)
            // 3. Pick the first valid result
            
            if let bestMatch = searchResults.first(where: { $0.syncedLyrics != nil && !$0.syncedLyrics!.isEmpty }) {
                return Lyrics.parse(lrc: bestMatch.syncedLyrics!)
            } else if let plainMatch = searchResults.first(where: { $0.plainLyrics != nil && !$0.plainLyrics!.isEmpty }) {
                // Return plain lyrics converted to non-synced format
                let lines = plainMatch.plainLyrics!.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                    .enumerated()
                    .map { LyricLine(timestamp: 0, text: $0.element) }
                return Lyrics(lines: lines)
            }
            
            return nil
        } catch {
            print("LRCLIB fetch error: \(error)")
            return nil
        }
    }
    
    // MARK: - Clear Cache
    func clearCache() {
        cache.removeAll()
        currentLyrics = nil
    }
}

// MARK: - API Response Models
struct LRCLIBResponse: Codable {
    let id: Int?
    let name: String?
    let trackName: String?
    let artistName: String?
    let albumName: String?
    let duration: Double?
    let instrumental: Bool?
    let plainLyrics: String?
    let syncedLyrics: String?
}
