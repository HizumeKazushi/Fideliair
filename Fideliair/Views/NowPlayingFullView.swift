import SwiftUI
import AppKit

// Notification for closing Now Playing view
extension Notification.Name {
    static let closeNowPlaying = Notification.Name("closeNowPlaying")
    static let showNowPlaying = Notification.Name("showNowPlaying")
}

/// Full-screen Now Playing overlay - Apple Music style
struct NowPlayingFullView: View {
    @Binding var isShowing: Bool
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @StateObject private var lyricsService = LyricsService()
    @State private var dragOffset: CGFloat = 0
    @State private var eventMonitor: Any?
    @State private var scrollMonitor: Any?
    @State private var viewMode: ViewMode = .none
    
    enum ViewMode {
        case none
        case lyrics
        case queue
    }
    
    var body: some View {
        ZStack {
            // Full background
            Color.black.ignoresSafeArea()
            
            // Blurred album art background
            if let artwork = audioPlayer.currentTrack?.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 80)
                    .opacity(0.6)
                    .ignoresSafeArea()
            }
            
            // Dark overlay for readability
            Color.black.opacity(0.3).ignoresSafeArea()
            
            // Main content
            VStack(spacing: 0) {
                // Top placeholder to keep spacing consistent & protect from window controls
                Color.clear.frame(height: 80)
                
                // Main content area
                GeometryReader { geo in
                    ZStack {
                        let showTwoColumn = viewMode != .none
                        
                        if showTwoColumn {
                            // Two-column layout
                            HStack(spacing: 60) {
                                // Left side - Album Art & Controls
                                VStack(spacing: 30) {
                                    Spacer()
                                    
                                    albumArtSection(geo: geo, maxArtSize: min(geo.size.height - 250, 320))
                                    
                                    playbackControlsSection
                                        .frame(width: min(geo.size.height - 250, 320))
                                    
                                    // Toggle Buttons (Moved here)
                                    HStack(spacing: 20) {
                                        Button(action: { 
                                            withAnimation { 
                                                viewMode = (viewMode == .lyrics) ? .none : .lyrics 
                                            } 
                                        }) {
                                            Image(systemName: "quote.bubble.fill")
                                                .font(.zen(.title2))
                                                .foregroundColor(viewMode == .lyrics ? .white : .white.opacity(0.4))
                                                .padding(10)
                                                .background(viewMode == .lyrics ? Color.white.opacity(0.2) : Color.clear)
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .help("Show Lyrics")
                                        
                                        Button(action: { 
                                            withAnimation { 
                                                viewMode = (viewMode == .queue) ? .none : .queue 
                                            } 
                                        }) {
                                            Image(systemName: "list.bullet")
                                                .font(.zen(.title2))
                                                .foregroundColor(viewMode == .queue ? .white : .white.opacity(0.4))
                                                .padding(10)
                                                .background(viewMode == .queue ? Color.white.opacity(0.2) : Color.clear)
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .help("Show Up Next")
                                    }
                                    
                                    Spacer()
                                }
                                .frame(width: geo.size.width * 0.35)
                                
                                // Right side - Lyrics/Queue (centered vertically)
                                VStack(spacing: 0) {
                                    // Content (Replaced ZStack for simple switch)
                                    ZStack {
                                        if viewMode == .lyrics {
                                            if let lyrics = lyricsService.currentLyrics, !lyrics.lines.isEmpty {
                                                AppleMusicLyricsView(
                                                    lyrics: lyrics,
                                                    currentTime: audioPlayer.currentTime,
                                                    onSeek: { audioPlayer.seek(to: $0) }
                                                )
                                            } else {
                                                ContentUnavailableView("No Lyrics", systemImage: "music.mic.slash")
                                                    .foregroundColor(.white.opacity(0.6))
                                            }
                                        } else {
                                            UpNextQueueView()
                                                .padding(.top, 270) // Push Queue down specific amount
                                        }
                                    }
                                    .frame(maxHeight: .infinity)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .padding(.horizontal, 40)
                        } else {
                            // Centered layout when no lyrics (and mode is .lyrics)
                            VStack(spacing: 30) {
                                Spacer()
                                
                                // Centered album artwork & Controls
                                albumArtwork
                                    .frame(width: min(geo.size.height - 250, 400), height: min(geo.size.height - 250, 400))
                                
                                VStack(spacing: 8) {
                                    Text(audioPlayer.currentTrack?.title ?? "Unknown")
                                        .font(.zen(.title).bold())
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                    
                                    Text(audioPlayer.currentTrack?.artist ?? "Unknown Artist")
                                        .font(.zen(.title3))
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    // Audio Quality Badge (Centered)
                                    if let track = audioPlayer.currentTrack, track.isLossless || track.isHiRes {
                                        HStack(spacing: 8) {
                                            // Main Badge
                                            Text(track.qualityBadge)
                                                .font(.zen(size: 12, weight: .bold))
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.white.opacity(0.9))
                                                .cornerRadius(5)
                                            
                                            // Tech Details
                                            if !track.technicalDetails.isEmpty {
                                                Text(track.technicalDetails)
                                                    .font(.zen(size: 12, weight: .medium))
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                        }
                                        .padding(.top, 6)
                                    }
                                }
                                .frame(maxWidth: 400)
                                
                                playbackControlsSection
                                    .frame(width: 400)
                                
                                // Add Toggle Buttons here too
                                HStack(spacing: 20) {
                                    Button(action: { 
                                        withAnimation { 
                                            viewMode = (viewMode == .lyrics) ? .none : .lyrics 
                                        } 
                                    }) {
                                        Image(systemName: "quote.bubble.fill")
                                            .font(.zen(.title2))
                                            .foregroundColor(viewMode == .lyrics ? .white : .white.opacity(0.4))
                                            .padding(10)
                                            .background(viewMode == .lyrics ? Color.white.opacity(0.2) : Color.clear)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Show Lyrics")
                                    
                                    Button(action: { 
                                        withAnimation { 
                                            viewMode = (viewMode == .queue) ? .none : .queue 
                                        } 
                                    }) {
                                        Image(systemName: "list.bullet")
                                            .font(.zen(.title2))
                                            .foregroundColor(viewMode == .queue ? .white : .white.opacity(0.4))
                                            .padding(10)
                                            .background(viewMode == .queue ? Color.white.opacity(0.2) : Color.clear)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Show Up Next")
                                }
                                .padding(.top, 10)
                                
                                if lyricsService.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(1.0)
                                        .padding(.top, 10)
                                }
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            
            // Now Playing Header with close hint
            VStack {
                VStack(spacing: 4) {
                    // Visual indicator for swipe down
                    Capsule()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 40, height: 5)
                        .padding(.top, 10)
                    
                    Text("NOW PLAYING")
                        .font(.zen(.caption2).bold())
                        .foregroundColor(.white.opacity(0.5))
                    Text(audioPlayer.currentTrack?.album ?? "")
                        .font(.zen(.caption))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(.top, 30)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow dragging down
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    // Close if dragged more than 100 points
                    if value.translation.height > 100 {
                        closeView()
                    } else {
                        // Snap back with smooth spring
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            loadLyrics()
            setupKeyboardMonitor()
            setupScrollMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeNowPlaying)) { _ in
            closeView()
        }
        .onChange(of: audioPlayer.currentTrack?.id) { _, _ in loadLyrics() }
    }
    
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Don't intercept if user is typing in a text field
            if let window = NSApp.keyWindow,
               let firstResponder = window.firstResponder,
               firstResponder is NSTextView || firstResponder is NSTextField {
                return event // Let text input work normally
            }
            
            if event.keyCode == 125 { // Down arrow key
                NotificationCenter.default.post(name: .closeNowPlaying, object: nil)
                return nil // Consume the event
            }
            return event
        }
    }
    
    private func removeKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }
    
    private func setupScrollMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            // Detect significant scroll down
            if event.scrollingDeltaY < -30 {
                closeView()
                return nil
            }
            return event
        }
    }
    
    private func closeView() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9, blendDuration: 0)) {
            dragOffset = 0
            isShowing = false
        }
    }
    
    private var playbackControlsSection: some View {
        VStack(spacing: 12) {
            // Progress bar
            ProgressSliderView()
            
            // Playback controls
            HStack(spacing: 30) {
                // Shuffle button
                Button(action: { audioPlayer.toggleShuffle() }) {
                    Image(systemName: "shuffle")
                        .font(.zen(.title3))
                        .foregroundColor(audioPlayer.isShuffled ? .blue : .white.opacity(0.7))
                }
                .buttonStyle(.plain)
                
                Button(action: { audioPlayer.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.zen(.title2))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Button(action: { audioPlayer.togglePlayPause() }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Button(action: { audioPlayer.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                // Repeat button
                Button(action: { audioPlayer.toggleRepeat() }) {
                    Image(systemName: audioPlayer.repeatMode.icon)
                        .font(.title3)
                        .foregroundColor(audioPlayer.repeatMode != .off ? .blue : .white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var albumArtwork: some View {
        Group {
            if let artwork = audioPlayer.currentTrack?.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
        }
    }
    
    @ViewBuilder
    private func albumArtSection(geo: GeometryProxy, maxArtSize: CGFloat) -> some View {
        VStack(spacing: 20) {
            albumArtwork
                .frame(width: maxArtSize, height: maxArtSize)
            
            VStack(spacing: 4) {
                Text(audioPlayer.currentTrack?.title ?? "Unknown")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text(audioPlayer.currentTrack?.artist ?? "Unknown Artist")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                
                // Audio Quality Badge
                if let track = audioPlayer.currentTrack, track.isLossless || track.isHiRes {
                    HStack(spacing: 8) {
                        // Main Badge
                        Text(track.qualityBadge)
                            .font(.zen(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(5)
                        
                        // Tech Details
                        if !track.technicalDetails.isEmpty {
                            Text(track.technicalDetails)
                                .font(.zen(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .frame(maxWidth: maxArtSize)
        }
    }
    
    private func loadLyrics() {
        guard let track = audioPlayer.currentTrack else { return }
        Task { await lyricsService.fetchLyrics(for: track) }
    }
}

/// Apple Music-style lyrics view with smooth scrolling
struct AppleMusicLyricsView: View {
    let lyrics: Lyrics
    let currentTime: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    @State private var previousIndex: Int?
    
    private var currentIndex: Int? {
        lyrics.currentLineIndex(for: currentTime)
    }
    
    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .center, spacing: 16) {
                        // Dynamic Top Padding to center the first line
                        Color.clear.frame(height: geo.size.height / 2 - 50)
                        
                        ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { index, line in
                            LyricLineView(
                                text: line.text,
                                isInstrumental: line.isInstrumental,
                                isActive: index == currentIndex,
                                isPast: index < (currentIndex ?? 0)
                            )
                            .id("line-\(index)")
                            .onTapGesture { onSeek(line.timestamp) }
                        }
                        
                        // Dynamic Bottom Padding to center the last line
                        Color.clear.frame(height: geo.size.height / 2 - 50)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                }
                .mask(
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom)
                            .frame(height: 100)
                        Color.white
                        LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 120)
                    }
                )
                .onChange(of: currentIndex) { oldValue, newValue in
                    guard let index = newValue, index != previousIndex else { return }
                    previousIndex = index
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0)) {
                        proxy.scrollTo("line-\(index)", anchor: .center)
                    }
                }
                // Add scroll on initial appear / lyrics change
                .onChange(of: lyrics.id) { _, _ in
                    // Delay slightly to let layout finish
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        if let index = currentIndex {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0)) {
                                proxy.scrollTo("line-\(index)", anchor: .center)
                            }
                        }
                    }
                }
                // Also scroll on appear
                .onAppear {
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        if let index = currentIndex {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0)) {
                                proxy.scrollTo("line-\(index)", anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Single lyric line view with Apple Music animation
struct LyricLineView: View {
    let text: String
    let isInstrumental: Bool
    let isActive: Bool
    let isPast: Bool
    
    var body: some View {
        Group {
            if isInstrumental {
                Image(systemName: "music.note")
                    .font(.zen(size: isActive ? 24 : 18))
            } else {
                Text(text)
                    .font(.zen(size: isActive ? 28 : 20, weight: isActive ? .bold : .medium))
            }
        }
        .foregroundColor(.white)
        .opacity(isActive ? 1.0 : (isPast ? 0.4 : 0.5))
        .blur(radius: isActive ? 0 : 1.5)
        .scaleEffect(isActive ? 1.0 : 0.92, anchor: .center)
        .multilineTextAlignment(.center)
        .lineSpacing(6)
        .padding(.vertical, isActive ? 14 : 8)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: isActive)
        .shadow(color: isActive ? .black.opacity(0.4) : .clear, radius: 6, x: 0, y: 3)
    }
}

/// Progress slider
struct ProgressSliderView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .frame(height: 4)
                    
                    // Progress
                    Capsule()
                        .fill(.white)
                        .frame(width: progressWidth(geo.size.width), height: 4)
                    
                    // Thumb
                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                        .offset(x: max(0, progressWidth(geo.size.width) - (isDragging ? 8 : 6)))
                        .shadow(radius: 3)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let progress = max(0, min(1, value.location.x / geo.size.width))
                            audioPlayer.seek(to: progress * audioPlayer.duration)
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.2)) { isDragging = false }
                        }
                )
            }
            .frame(height: 16)
            
            // Time labels
            HStack {
                Text(formatTime(audioPlayer.currentTime))
                Spacer()
                Text(formatTime(audioPlayer.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: 500)
    }
    
    private func progressWidth(_ total: CGFloat) -> CGFloat {
        guard audioPlayer.duration > 0 else { return 0 }
        return CGFloat(audioPlayer.currentTime / audioPlayer.duration) * total
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}



/// Up Next Queue View
struct UpNextQueueView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    
    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Text("Up Next")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(height: 40)
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                
                if audioPlayer.queue.isEmpty {
                    Spacer()
                    Text("Queue is empty")
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(audioPlayer.queue.enumerated()), id: \.element.id) { index, track in
                                    HStack(spacing: 12) {
                                        // Animation bars for playing track
                                        if index == audioPlayer.currentIndex && audioPlayer.isPlaying {
                                            PlayingIndicatorView()
                                                .frame(width: 16, height: 16)
                                        } else {
                                            Text("\(index + 1)")
                                                .font(.caption.monospacedDigit())
                                                .foregroundColor(.white.opacity(0.5))
                                                .frame(width: 16)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(track.title)
                                                .font(.system(size: 14, weight: index == audioPlayer.currentIndex ? .bold : .medium))
                                                .foregroundColor(index == audioPlayer.currentIndex ? .blue : .white)
                                                .lineLimit(1)
                                            
                                            Text(track.artist)
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.7))
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(trackStringDuration(track.duration))
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(
                                        index == audioPlayer.currentIndex ? Color.white.opacity(0.1) : Color.clear
                                    )
                                    .cornerRadius(8)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        playTrack(at: index)
                                    }
                                    .id(index)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        }
                        // Removed explicit height frame, let it fill remaining space via VStack layout
                        .onAppear {
                            // Scroll to current track
                            Task {
                                try? await Task.sleep(nanoseconds: 200_000_000)
                                withAnimation {
                                    proxy.scrollTo(audioPlayer.currentIndex, anchor: .top)
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(Color.black.opacity(0.4))
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
    
    // ... existing helpers ...
    
    private func playTrack(at index: Int) {
        let track = audioPlayer.queue[index]
        audioPlayer.currentIndex = index
        audioPlayer.play(track: track)
    }
    
    private func trackStringDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Simple animated playing indicator
struct PlayingIndicatorView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.blue)
                    .frame(width: 3, height: isAnimating ? 12 : 4)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever()
                        .delay(Double(i) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    NowPlayingFullView(isShowing: .constant(true))
        .environmentObject(AudioPlayerManager())
}


