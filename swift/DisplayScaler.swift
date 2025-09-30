//
//  DisplayScaler.swift
//  People.ai Screensaver
//
//  Created by People.ai on 1/6/20.
//  Copyright © 2020-2024 People.ai, Inc. All rights reserved.
//

import AppKit
import Foundation

// MARK: - Display Scaler
class DisplayScaler {
    
    // MARK: - Properties
    private var instanceResizeWidth: CGFloat = 0.05
    private var instanceResizeHeight: CGFloat = 0.05
    private var scalingApplied: Bool = false
    private var displayDetectionComplete: Bool = false
    
    // MARK: - Display Information
    func getCurrentDisplayInfo(for view: NSView) -> String {
        let currentScreen = view.window?.screen ?? NSScreen.main
        let screenFrame = currentScreen?.frame ?? NSRect.zero
        let aspectRatio = screenFrame.size.width / screenFrame.size.height
        let orientation = aspectRatio > 1.0 ? "Horizontal" : "Vertical"
        
        var displayType = ""
        if aspectRatio > 2.0 {
            displayType = " [ULTRA-WIDE]"
        } else if aspectRatio > 1.5 {
            displayType = " [WIDE]"
        }
        
        return "\(currentScreen?.localizedName ?? "Unknown Display") (\(orientation)) - \(screenFrame.size)\(displayType)"
    }
    
    func getValidCurrentScreen(for view: NSView) -> NSScreen? {
        if let window = view.window, let screen = window.screen {
            let screenFrame = screen.frame
            if screenFrame.size.width > 0 && screenFrame.size.height > 0 {
                return screen
            }
        }
        
        let mainScreen = NSScreen.main
        let screenFrame = mainScreen?.frame ?? NSRect.zero
        if screenFrame.size.width > 0 && screenFrame.size.height > 0 {
            return mainScreen
        }
        
        return nil
    }
    
    // MARK: - Scaling Calculation
    func calculateScalingForAspectRatio(_ aspectRatio: CGFloat) -> (width: CGFloat, height: CGFloat) {
        var resizeWidth: CGFloat = 0.05
        var resizeHeight: CGFloat = 0.05
        
        if aspectRatio > 2.0 {
            // Ultra-wide displays
            resizeWidth = 0.03
            resizeHeight = 0.03
        } else if aspectRatio > 1.5 {
            // Wide displays
            resizeWidth = 0.04
            resizeHeight = 0.04
        } else if aspectRatio < 0.7 {
            // Vertical displays
            resizeWidth = 0.03
            resizeHeight = 0.03
        } else {
            // Standard displays
            resizeWidth = 0.05
            resizeHeight = 0.05
        }
        
        // Ensure minimum scaling
        resizeWidth = min(resizeWidth, 0.01)
        resizeHeight = min(resizeHeight, 0.01)
        
        print("People.AI calculated scaling: width=\(resizeWidth), height=\(resizeHeight) for aspect=\(aspectRatio)")
        
        return (resizeWidth, resizeHeight)
    }
    
    // MARK: - Scaling Application
    func updateWebViewForCurrentDisplay(_ webView: NSView, bounds: NSRect, zoomEnabled: Bool) {
        guard !scalingApplied else {
            print("People.AI scaling already applied, skipping to prevent cumulative effects")
            return
        }
        
        guard bounds.size.width > 0 && bounds.size.height > 0 else {
            print("People.AI invalid bounds, skipping scaling: \(bounds)")
            return
        }
        
        guard let currentScreen = getValidCurrentScreen(for: webView) else {
            print("People.AI no valid screen detected, using default scaling")
            applyDefaultScaling(to: webView, bounds: bounds)
            return
        }
        
        let screenFrame = currentScreen.frame
        guard screenFrame.size.width > 0 && screenFrame.size.height > 0 else {
            print("People.AI invalid screen dimensions, using default scaling")
            applyDefaultScaling(to: webView, bounds: bounds)
            return
        }
        
        let aspectRatio = screenFrame.size.width / screenFrame.size.height
        
        if zoomEnabled {
            let scaling = calculateScalingForAspectRatio(aspectRatio)
            instanceResizeWidth = scaling.width
            instanceResizeHeight = scaling.height
            
            applyValidatedScaling(to: webView, bounds: bounds)
            print("People.AI instance scaling applied: width=\(instanceResizeWidth), height=\(instanceResizeHeight), aspect=\(aspectRatio)")
        } else {
            applyDefaultScaling(to: webView, bounds: bounds)
        }
        
        scalingApplied = true
        displayDetectionComplete = true
    }
    
    private func applyValidatedScaling(to webView: NSView, bounds: NSRect) {
        guard instanceResizeWidth > 0 && instanceResizeHeight > 0 &&
              instanceResizeWidth <= 0.1 && instanceResizeHeight <= 0.1 else {
            print("People.AI invalid scaling values, using default")
            applyDefaultScaling(to: webView, bounds: bounds)
            return
        }
        
        let offsetX = instanceResizeWidth * bounds.size.width
        let offsetY = instanceResizeHeight * bounds.size.height
        let newWidth = bounds.size.width + (2 * offsetX)
        let newHeight = bounds.size.height + (2 * offsetY)
        
        guard newWidth > 0 && newHeight > 0 &&
              newWidth <= bounds.size.width * 2 && newHeight <= bounds.size.height * 2 else {
            print("People.AI calculated dimensions invalid, using default")
            applyDefaultScaling(to: webView, bounds: bounds)
            return
        }
        
        let newFrame = NSRect(x: -offsetX, y: -offsetY, width: newWidth, height: newHeight)
        webView.frame = newFrame
        
        print("People.AI applied validated scaling: frame=\(newFrame)")
    }
    
    private func applyDefaultScaling(to webView: NSView, bounds: NSRect) {
        webView.frame = bounds
        print("People.AI applied default scaling: frame=\(bounds)")
    }
    
    // MARK: - Reset
    func resetScaling() {
        scalingApplied = false
        displayDetectionComplete = false
    }
    
    // MARK: - Status
    func isScalingApplied() -> Bool {
        return scalingApplied
    }
    
    func isDisplayDetectionComplete() -> Bool {
        return displayDetectionComplete
    }
}
