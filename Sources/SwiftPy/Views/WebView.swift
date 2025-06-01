//
//  WebView.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-06-01.
//

import WebKit
import SwiftUI

#if canImport(UIKit)
struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#endif

@available(macOS 14.4, iOS 17.4, *)
struct WebViewSyntax: ViewSyntax {
    let url: URL

    var body: some View {
        WebView(url: url)
    }

    static func build(view: PyAPI.Reference, context: PythonViewContext) throws -> WebViewSyntax {
        guard let url = try URL(string: view.castAttribute("url")) else {
            throw PythonError.ValueError("Invalid url")
        }
        return WebViewSyntax(url: url)
    }
}
