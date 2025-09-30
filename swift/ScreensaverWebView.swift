//
//  ScreensaverWebView.swift
//  People.ai Screensaver
//
//  Created by People.ai on 1/6/20.
//  Copyright © 2020-2024 People.ai, Inc. All rights reserved.
//

import WebKit
import AppKit

// MARK: - Custom WebView for Screensaver
class ScreensaverWebView: WKWebView {
    
    // MARK: - Initialization
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        setupWebView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWebView()
    }
    
    private func setupWebView() {
        // Disable user interactions
        allowsMagnification = false
        allowsBackForwardNavigationGestures = false
    }
    
    // MARK: - Event Handling
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Block all mouse interactions
        return nil
    }
    
    override func mouseDown(with event: NSEvent) {
        // Do nothing to skip mouse events
    }
    
    override func keyDown(with event: NSEvent) {
        // Do nothing to skip keyboard events
    }
    
    override func keyUp(with event: NSEvent) {
        // Do nothing to skip keyboard events
    }
    
    override func scrollWheel(with event: NSEvent) {
        // Do nothing to skip scroll events
    }
    
    override func rightMouseDown(with event: NSEvent) {
        // Do nothing to skip right mouse events
    }
    
    override func otherMouseDown(with event: NSEvent) {
        // Do nothing to skip other mouse events
    }
}
