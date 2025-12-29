import SwiftUI

/// Google Drive view (placeholder for Phase 3)
/// Google Drive view with local mount integration
struct GoogleDriveView: View {
    @StateObject private var manager = GoogleDriveManager()
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @State private var showingFolderPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Google Drive")
                    .font(.zen(.title).bold())
                
                Spacer()
                
                if manager.isConnected {
                    Button(action: { manager.disconnect() }) {
                        Text("Disconnect".localized)
                            .font(.zen(.caption))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding()
            .background(GlassBackground(opacity: 0.3))
            
            // Content
            if let rootURL = manager.driveRootURL, manager.isConnected {
                CloudBrowserView(rootURL: rootURL)
                    .environmentObject(manager)
            } else {
                // Connect state
                VStack(spacing: 24) {
                    Image(systemName: "externaldrive.fill.badge.icloud")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 8) {
                        Text("Connect Google Drive".localized)
                            .font(.zen(.title2).bold())
                        
                        Text("Select your Google Drive folder location\nto stream your music directly.".localized)
                            .font(.zen(.body))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button(action: {
                        showingFolderPicker = true
                    }) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            Text("Select Drive Folder".localized)
                        }
                        .font(.zen(.headline))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Text("Typically located at /Users/Shared/Google Drive\nor within /Volumes/".localized)
                        .font(.zen(.caption))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.top, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                manager.connect(to: url)
            }
        }
    }
}

#Preview {
    GoogleDriveView()
        .frame(width: 600, height: 400)
}
