import SwiftUI
import WebKit

/// Hosts the exported Figma Make bundle locally while the native feature bridge is added.
struct FigmaMakeWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.965, green: 0.945, blue: 0.922, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        loadBundle(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard webView.url == nil else { return }
        loadBundle(in: webView)
    }

    private func loadBundle(in webView: WKWebView) {
        guard let bundleURL = Bundle.main.url(forResource: "FigmaMakeWeb", withExtension: nil),
              let cssURL = Bundle.main.urls(
                  forResourcesWithExtension: "css",
                  subdirectory: "FigmaMakeWeb/assets"
              )?.first,
              let scriptURL = Bundle.main.urls(
                  forResourcesWithExtension: "js",
                  subdirectory: "FigmaMakeWeb/assets"
              )?.first,
              let css = try? String(contentsOf: cssURL, encoding: .utf8),
              let script = try? String(contentsOf: scriptURL, encoding: .utf8) else {
            assertionFailure("Figma Make web bundle is missing from the App resources")
            return
        }

        let html = """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="UTF-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
          <style>html, body { height: 100%; margin: 0; } #root { height: 100%; }</style>
          <style>\(css)</style>
        </head>
        <body>
          <div id="root"></div>
          <script>\(script)</script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: bundleURL)
    }
}
