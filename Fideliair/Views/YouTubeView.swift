import SwiftUI
import WebKit

struct YouTubeView: NSViewRepresentable {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        
        // Use Safari User Agent to bypass both "unsupported browser" and "secure app" checks
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3 Safari/605.1.15"
        
        // Load YouTube Music
        if let url = URL(string: "https://music.youtube.com") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Updates can be handled here if needed
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: YouTubeView
        
        init(_ parent: YouTubeView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            
            // Allow YouTube and Google (login) domains
            let allowedHosts = ["youtube.com", "google.com", "accounts.google.com", "gstatic.com"]
            if let host = url.host {
                for allowed in allowedHosts {
                    if host.contains(allowed) {
                        decisionHandler(.allow)
                        return
                    }
                }
            }
            
            // Allow about:blank etc
            if url.scheme == "about" || url.scheme == "blob" {
                decisionHandler(.allow)
                return
            }
            
            print("Blocked navigation to: \(url.absoluteString)")
            decisionHandler(.cancel)
        }
    }
}
