import SwiftUI
import AVFoundation
import Combine
import MediaPlayer

/// Repeat mode for playback
enum RepeatMode: String, CaseIterable {
    case off = "Off"
    case one = "Repeat One"
    case all = "Repeat All"
    
    var icon: String {
        switch self {
        case .off: return "repeat"
        case .one: return "repeat.1"
        case .all: return "repeat"
        }
    }
}

/// Core audio player manager using AVQueuePlayer for gapless playback
@MainActor
class AudioPlayerManager: ObservableObject {
    // MARK: - Published Properties
    @Published var currentTrack: Track?
    @Published var isPlaying = false {
        didSet {
            updateNowPlayingInfo()
        }
    }
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 1.0
    @Published var queue: [Track] = []
    @Published var currentIndex: Int = 0
    @Published var isShuffled = false
    @Published var repeatMode: RepeatMode = .off
    
    // Original queue (before shuffle)
    private var originalQueue: [Track] = []
    
    // MARK: - Private Properties
    private var player: AVQueuePlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var currentPlayerItem: AVPlayerItem?
    
    // MARK: - Initialization
    init() {
        setupPlayer()
        setupRemoteCommands()
    }
    
    nonisolated deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Player Setup
    private func setupPlayer() {
        player = AVQueuePlayer()
        player?.volume = volume
        
        player?.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isPlaying = status == .playing
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Remote Commands (Media Keys)
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play/Pause
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }
        
        // Next/Previous
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.nextTrack()
            }
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.previousTrack()
            }
            return .success
        }
        
        // Seek
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in
                self?.seek(to: event.positionTime)
            }
            return .success
        }
    }
    
    // MARK: - Now Playing Info
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = track.title
        info[MPMediaItemPropertyArtist] = track.artist
        info[MPMediaItemPropertyAlbumTitle] = track.album
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime().seconds
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        if let artwork = track.artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in return artwork }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    // MARK: - Shuffle & Repeat Controls
    func toggleShuffle() {
        isShuffled.toggle()
        
        if isShuffled {
            // Save original queue and shuffle
            originalQueue = queue
            let currentTrack = queue[currentIndex]
            var shuffled = queue
            shuffled.remove(at: currentIndex)
            shuffled.shuffle()
            shuffled.insert(currentTrack, at: 0)
            queue = shuffled
            currentIndex = 0
        } else {
            // Restore original queue
            if let current = currentTrack,
               let originalIndex = originalQueue.firstIndex(where: { $0.id == current.id }) {
                queue = originalQueue
                currentIndex = originalIndex
            }
        }
        
        // Remove preloaded next track and reload correct one
        // Keep current item playing, just update the queue for next track
        if let player = player, player.items().count > 1 {
            // Remove all items except current
            while player.items().count > 1 {
                if let lastItem = player.items().last, lastItem != player.currentItem {
                    player.remove(lastItem)
                } else {
                    break
                }
            }
        }
        
        // Preload the new next track
        preloadNextTrack()
    }
    
    func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .one
        case .one: repeatMode = .all
        case .all: repeatMode = .off
        }
    }
    
    // MARK: - Playback Controls
    func play(track: Track) {
        guard let url = track.fileURL else { return }
        
        removeTimeObserver()
        player?.removeAllItems()
        
        let item = AVPlayerItem(url: url)
        currentPlayerItem = item
        player?.insert(item, after: nil)
        
        currentTrack = track
        observePlayerItem(item)
        
        // Only preload next if not repeat one
        if repeatMode != .one {
            preloadNextTrack()
        }
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        
        player?.play()
        isPlaying = true
        setupTimeObserver()
        updateNowPlayingInfo() // Initial update
    }
    
    private func observePlayerItem(_ item: AVPlayerItem) {
        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .readyToPlay {
                    self?.duration = item.duration.seconds.isNaN ? 0 : item.duration.seconds
                    self?.updateNowPlayingInfo() // Update duration
                }
            }
            .store(in: &cancellables)
    }
    
    private func preloadNextTrack() {
        guard !queue.isEmpty, repeatMode != .one else { return }
        let nextIndex = (currentIndex + 1) % queue.count
        guard nextIndex != currentIndex, let url = queue[nextIndex].fileURL else { return }
        
        let nextItem = AVPlayerItem(url: url)
        if player?.items().count == 1 {
            player?.insert(nextItem, after: player?.items().first)
        }
    }
    
    @objc private func playerItemDidFinishPlaying(_ notification: Notification) {
        Task { @MainActor in
            handleTrackEnd()
        }
    }
    
    private func handleTrackEnd() {
        switch repeatMode {
        case .one:
            // Replay current track
            seek(to: 0)
            player?.play()
        case .all:
            // Move to next, loop around
            advanceToNextTrack()
        case .off:
            // Move to next, stop at end
            if currentIndex < queue.count - 1 {
                advanceToNextTrack()
            } else {
                // End of queue
                isPlaying = false
            }
        }
    }
    
    private func advanceToNextTrack() {
        guard !queue.isEmpty else { return }
        
        currentIndex = (currentIndex + 1) % queue.count
        currentTrack = queue[currentIndex]
        currentTime = 0
        
        if let currentItem = player?.currentItem {
            currentPlayerItem = currentItem
            observePlayerItem(currentItem)
            
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerItemDidFinishPlaying),
                name: .AVPlayerItemDidPlayToEndTime,
                object: currentItem
            )
        }
        
        preloadNextTrack()
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    func pause() {
        player?.pause()
    }
    
    func stop() {
        player?.pause()
        player?.removeAllItems()
        isPlaying = false
        currentTime = 0
        currentTrack = nil
        removeTimeObserver()
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }
    
    func setVolume(_ newVolume: Float) {
        volume = newVolume
        player?.volume = newVolume
    }
    
    // MARK: - Queue Management
    func nextTrack() {
        guard !queue.isEmpty else { return }
        
        // If there's a next item already queued, advance to it
        if let player = player, player.items().count > 1 {
            player.advanceToNextItem()
            advanceToNextTrack()
        } else {
            // Otherwise, play the next track directly
            currentIndex = (currentIndex + 1) % queue.count
            play(track: queue[currentIndex])
        }
    }
    
    func previousTrack() {
        guard !queue.isEmpty else { return }
        
        // If more than 3 seconds in, restart current track
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        
        currentIndex = currentIndex > 0 ? currentIndex - 1 : queue.count - 1
        play(track: queue[currentIndex])
    }
    
    func playQueue(_ tracks: [Track], startingAt index: Int = 0) {
        queue = tracks
        currentIndex = index
        if !tracks.isEmpty {
            play(track: tracks[index])
        }
    }
    
    // MARK: - Time Observer
    private func setupTimeObserver() {
        removeTimeObserver()
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
            }
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    // MARK: - Formatting Helpers
    func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

