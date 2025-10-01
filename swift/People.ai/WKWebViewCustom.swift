//
//  WKWebViewCustom.swift
//  People.ai
//
//  Created by People.ai on 1/21/20.
//  Copyright © 2020-2022 People.ai, Inc. All rights reserved.
//

import AppKit
import WebKit

class WKWebViewCustom: WKWebView {
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
    
    override func mouseDown(with event: NSEvent) {
        // do nothing to skip any mouse event
    }
    
    override func keyDown(with event: NSEvent) {
        // do nothing to skip any keyboard event
    }
    
    override func keyUp(with event: NSEvent) {
        // do nothing to skip any keyboard event
    }
}
