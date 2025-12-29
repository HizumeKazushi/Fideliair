import SwiftUI

/// Sidebar view with Liquid Glass styling
struct SidebarView: View {
    @Binding var selectedItem: SidebarItem
    @EnvironmentObject var libraryManager: LibraryManager
    @ObservedObject var languageManager = LanguageManager.shared // Observe language
    @State private var showingFolderPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App title
            Text("Fideliair")
                .font(.zen(size: 24, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 20)
            
            // Navigation items
            VStack(spacing: 4) {
                ForEach(SidebarItem.allCases, id: \.self) { item in
                    SidebarItemView(
                        item: item,
                        isSelected: selectedItem == item
                    )
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedItem = item
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            
            Divider()
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
            
            // Library folders section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Folders".localized)
                        .font(.zen(.caption))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // Reload all button
                    Button(action: {
                        Task {
                            await libraryManager.scanAllLibraries()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.zen(.caption))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Reload all folders")
                    
                    // Add folder button
                    Button(action: { showingFolderPicker = true }) {
                        Image(systemName: "plus")
                            .font(.zen(.caption))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Add folder")
                }
                .padding(.horizontal, 20)
                
                ForEach(libraryManager.libraryPaths, id: \.self) { path in
                    FolderRowView(
                        path: path,
                        onReload: {
                            Task {
                                await libraryManager.scanDirectory(path)
                            }
                        },
                        onRemove: {
                            libraryManager.removeLibraryPath(path)
                        }
                    )
                }
            }
            
            Spacer()
            
            // Scanning indicator
            if libraryManager.isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Scanning...".localized)
                        .font(.zen(.caption))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .frame(maxHeight: .infinity)
        .background(
            GlassBackground(opacity: 0.6)
        )
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                libraryManager.addLibraryPath(url)
            }
        }
    }
}

/// Individual sidebar item with hover effects
struct SidebarItemView: View {
    let item: SidebarItem
    let isSelected: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.zen(size: 16, weight: .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 24)
            
            Text(item.rawValue.localized) // Localized
                .font(.zen(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isSelected
                        ? AnyShapeStyle(LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                          ))
                        : AnyShapeStyle(isHovered ? Color.white.opacity(0.1) : Color.clear)
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

/// Folder row with reload and removal options
struct FolderRowView: View {
    let path: URL
    var onReload: (() -> Void)? = nil
    let onRemove: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.zen(.caption))
                .foregroundStyle(.secondary)
            
            Text(path.lastPathComponent)
                .font(.zen(.caption))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            // Action buttons (visible on hover)
            if isHovered {
                HStack(spacing: 6) {
                    Button(action: { onReload?() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.zen(.caption2))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Reload folder")
                    
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.zen(.caption))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove folder")
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button(action: { onReload?() }) {
                Label("Reload Folder".localized, systemImage: "arrow.clockwise")
            }
            
            Divider()
            
            Button(role: .destructive, action: onRemove) {
                Label("Remove Folder".localized, systemImage: "trash")
            }
        }
    }
}

#Preview {
    SidebarView(selectedItem: .constant(.library))
        .environmentObject(LibraryManager())
        .frame(width: 220, height: 600)
}

