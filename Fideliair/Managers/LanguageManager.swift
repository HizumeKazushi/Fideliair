import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "English"
    case japanese = "Japanese"
    
    var id: String { self.rawValue }
    
    var locale: Locale {
        switch self {
        case .english: return Locale(identifier: "en")
        case .japanese: return Locale(identifier: "ja")
        }
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("appLanguage") var currentLanguage: AppLanguage = .japanese // Default to Japanese as per user preference
    
    func localizedString(_ key: String) -> String {
        return translations[key]?[currentLanguage] ?? key
    }
    
    // Simple dictionary-based translation system
    // In a production app, we might use Localizable.strings, 
    // but this allows instant dynamic switching without app restart.
    private let translations: [String: [AppLanguage: String]] = [
        // Sidebar
        "Library": [.english: "Library", .japanese: "ライブラリ"],
        "Playlists": [.english: "Playlists", .japanese: "プレイリスト"],
        "Google Drive": [.english: "Google Drive", .japanese: "Google Drive"],
        "Settings": [.english: "Settings", .japanese: "設定"],
        "Folders": [.english: "Folders", .japanese: "フォルダ"],
        "Scanning...": [.english: "Scanning...", .japanese: "スキャン中..."],
        "Reload Folder": [.english: "Reload Folder", .japanese: "フォルダを再読み込み"],
        "Remove Folder": [.english: "Remove Folder", .japanese: "フォルダを削除"],
        
        // Library View
        "Albums": [.english: "Albums", .japanese: "アルバム"],
        "Artists": [.english: "Artists", .japanese: "アーティスト"],
        "Songs": [.english: "Songs", .japanese: "曲"],
        "Search": [.english: "Search", .japanese: "検索"],
        "Play": [.english: "Play", .japanese: "再生"],
        "Shuffle": [.english: "Shuffle", .japanese: "シャッフル"],
        "Play All": [.english: "Play All", .japanese: "すべて再生"],
        "Add to Playlist": [.english: "Add to Playlist", .japanese: "プレイリストに追加"],
        "New Playlist...": [.english: "New Playlist...", .japanese: "新規プレイリスト..."],
        
        // Settings View
        "Appearance": [.english: "Appearance", .japanese: "外観"],
        "Audio": [.english: "Audio", .japanese: "オーディオ"],
        "About": [.english: "About", .japanese: "アプリについて"],
        "Font": [.english: "Font", .japanese: "フォント"],
        "Use System Font": [.english: "Use System Font", .japanese: "システムフォントを使用"],
        "Font Family": [.english: "Font Family", .japanese: "フォントファミリー"],
        "Text Size Scale": [.english: "Text Size Scale", .japanese: "文字サイズ"],
        "Adjust the relative size of text throughout the application.": [.english: "Adjust the relative size of text throughout the application.", .japanese: "アプリ全体の文字サイズを調整します。"],
        "Output Device": [.english: "Output Device", .japanese: "出力デバイス"],
        "Sample Rate": [.english: "Sample Rate", .japanese: "サンプルレート"],
        "Auto Sample Rate Matching": [.english: "Auto Sample Rate Matching", .japanese: "サンプルレート自動追従"],
        "Automatically adjusts the output device's sample rate to match the playing track for high-resolution playback.": [.english: "Automatically adjusts the output device's sample rate to match the playing track for high-resolution playback.", .japanese: "再生中の曲に合わせて出力デバイスのサンプルレートを自動的に変更し、ハイレゾ再生を実現します。"],
        "Language": [.english: "Language", .japanese: "言語"],
        "Select Language": [.english: "Select Language", .japanese: "言語を選択"],
        "Reset Settings": [.english: "Reset Settings", .japanese: "設定をリセット"],
        "Buy me a coffee": [.english: "Buy me a coffee", .japanese: "開発者にコーヒーを奢る"],
        "Support Development": [.english: "Support Development", .japanese: "開発を支援する"],
        
        // Google Drive
        "Connect Google Drive": [.english: "Connect Google Drive", .japanese: "Google Driveに接続"],
        "Select your Google Drive folder location\nto stream your music directly.": [.english: "Select your Google Drive folder location\nto stream your music directly.", .japanese: "Google Driveのフォルダを選択して、\nクラウド上の音楽を直接再生します。"],
        "Select Drive Folder": [.english: "Select Drive Folder", .japanese: "ドライブフォルダを選択"],
        "Disconnect": [.english: "Disconnect", .japanese: "切断"],
        "Empty Folder": [.english: "Empty Folder", .japanese: "空のフォルダ"],
        "Typically located at /Users/Shared/Google Drive\nor within /Volumes/": [.english: "Typically located at /Users/Shared/Google Drive\nor within /Volumes/", .japanese: "通常は /Users/Shared/Google Drive\nまたは /Volumes/ 内にあります"],
        
        // Now Playing
        "Unknown": [.english: "Unknown", .japanese: "不明"],
        "Unknown Artist": [.english: "Unknown Artist", .japanese: "不明なアーティスト"],
        "Not Playing": [.english: "Not Playing", .japanese: "停止中"],
    ]
}

// Helper extension for easy usage in Views
extension String {
    var localized: String {
        LanguageManager.shared.localizedString(self)
    }
}
