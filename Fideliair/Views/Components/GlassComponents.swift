import SwiftUI

/// Reusable Liquid Glass background effect
struct GlassBackground: View {
    var opacity: Double = 0.6
    var cornerRadius: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Base blur layer
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            
            // Glass overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(opacity)
            
            // Top highlight
            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 1)
                Spacer()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// NSVisualEffectView wrapper for SwiftUI
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// Dynamic background that extracts colors from album artwork
struct AlbumArtBackground: View {
    var artwork: NSImage?
    @State private var dominantColors: [Color] = [.gray.opacity(0.3), .gray.opacity(0.1)]
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: dominantColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Noise texture overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.3)
            
            // Animated gradient orbs
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(dominantColors.first ?? .blue)
                        .blur(radius: 100)
                        .frame(width: 300, height: 300)
                        .offset(x: -100, y: -100)
                    
                    Circle()
                        .fill(dominantColors.last ?? .purple)
                        .blur(radius: 120)
                        .frame(width: 350, height: 350)
                        .offset(x: geometry.size.width - 200, y: geometry.size.height - 200)
                }
            }
        }
        .ignoresSafeArea()
        .onChange(of: artwork) { oldValue, newValue in
            if let image = newValue {
                extractColors(from: image)
            }
        }
        .animation(.easeInOut(duration: 1.0), value: dominantColors.description)
    }
    
    private func extractColors(from image: NSImage) {
        // Simple color extraction from corners of the image
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        // width and height are not needed for 1x1 sampling
        _ = cgImage.width
        _ = cgImage.height
        
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        
        // Sample center of image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        guard let data = context.data else { return }
        let pointer = data.bindMemory(to: UInt8.self, capacity: 4)
        
        let r = CGFloat(pointer[0]) / 255.0
        let g = CGFloat(pointer[1]) / 255.0
        let b = CGFloat(pointer[2]) / 255.0
        
        let primaryColor = Color(red: r, green: g, blue: b).opacity(0.6)
        let secondaryColor = Color(red: 1 - r, green: 1 - g, blue: 1 - b).opacity(0.3)
        
        withAnimation {
            dominantColors = [primaryColor, secondaryColor]
        }
    }
}

/// Animated music visualizer bars
struct MusicVisualizerView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @State private var heights: [CGFloat] = Array(repeating: 0.3, count: 5)
    @State private var animationTask: Task<Void, Never>?
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .bottom,
                        endPoint: .top
                    ))
                    .frame(width: 4, height: audioPlayer.isPlaying ? heights[index] * 20 : 4)
            }
        }
        .task(id: audioPlayer.isPlaying) {
            guard audioPlayer.isPlaying else { return }
            while !Task.isCancelled && audioPlayer.isPlaying {
                withAnimation(.easeInOut(duration: 0.15)) {
                    heights = (0..<5).map { _ in CGFloat.random(in: 0.2...1.0) }
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
    }
}

// MARK: - Native Search Field
/// NSSearchField wrapper for reliable search input on macOS
struct NativeSearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Search"
    
    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.placeholderString = placeholder
        searchField.delegate = context.coordinator
        searchField.bezelStyle = .roundedBezel
        searchField.focusRingType = .none
        return searchField
    }
    
    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String
        
        init(text: Binding<String>) {
            _text = text
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let searchField = obj.object as? NSSearchField else { return }
            text = searchField.stringValue
        }
    }
}

// MARK: - Native Text Field
/// NSTextField wrapper for reliable text input on macOS
struct NativeTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.bezelStyle = .roundedBezel
        textField.focusRingType = .default
        textField.isBordered = true
        textField.isBezeled = true
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeTextField
        
        init(_ parent: NativeTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
    }
}

#Preview {
    ZStack {
        AlbumArtBackground(artwork: nil)
        GlassBackground(opacity: 0.5, cornerRadius: 20)
            .frame(width: 300, height: 200)
    }
}

/// Close button with hover effect - High Visibility
struct CloseButton: View {
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background - High contrast dark background
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                
                // Overlay for hover
                Circle()
                    .fill(Color.white.opacity(isHovered ? 0.2 : 0))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isHovered ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("閉じる")
    }
}
