//
//  BackgroundEffectManager.swift
//  People.ai Screensaver
//
//  Created by People.ai on 1/6/20.
//  Copyright © 2020-2024 People.ai, Inc. All rights reserved.
//

import AppKit
import CoreImage
import WebKit

// MARK: - Background Effect Manager
class BackgroundEffectManager {
    
    // MARK: - Properties
    private var imageView: NSImageView?
    private var sharedContext: CIContext?
    private var animationTimer: Timer?
    
    // MARK: - Background Effect Modes
    enum BackgroundMode: String {
        case none = "none"
        case `static` = "static"
        case dynamic = "dynamic"
    }
    
    // MARK: - Setup Background Image View
    func setupBackgroundImageView(in parentView: NSView, frame: NSRect) -> NSImageView {
        if imageView == nil {
            imageView = NSImageView(frame: frame)
            imageView?.imageScaling = .scaleAxesIndependently
            parentView.addSubview(imageView!, positioned: .below, relativeTo: parentView.subviews.first)
        }
        return imageView!
    }
    
    // MARK: - Apply Background Effects
    func applyBackgroundEffect(mode: BackgroundMode, 
                              webView: WKWebView, 
                              parentView: NSView, 
                              fillImage: String? = nil,
                              slideTime: Int = 5) {
        
        switch mode {
        case .none:
            removeBackgroundEffect()
            
        case .`static`:
            applyStaticBackground(fillImage: fillImage, parentView: parentView)
            
        case .dynamic:
            applyDynamicBackground(webView: webView, parentView: parentView, slideTime: slideTime)
        }
    }
    
    private func applyStaticBackground(fillImage: String?, parentView: NSView) {
        guard let imageURL = fillImage, !imageURL.isEmpty,
              let url = URL(string: imageURL) else {
            print("People.AI no static background image provided")
            return
        }
        
        let imageView = setupBackgroundImageView(in: parentView, frame: parentView.bounds)
        
        // Load image asynchronously
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                // Create image on main thread to avoid Sendable issues
                await MainActor.run { [weak imageView] in
                    guard let imageView = imageView else { return }
                    let image = NSImage(data: data)
                    imageView.image = image
                    print("People.AI loaded static background image: \(imageURL)")
                }
            } catch {
                print("People.AI failed to load static background image: \(error.localizedDescription)")
            }
        }
    }
    
    private func applyDynamicBackground(webView: WKWebView, parentView: NSView, slideTime: Int) {
        let imageView = setupBackgroundImageView(in: parentView, frame: parentView.bounds)
        
        // Initial image update
        performImageUpdate(webView: webView, imageView: imageView)
        
        // Set up periodic updates
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(slideTime + 1), repeats: true) { _ in
            self.performImageUpdate(webView: webView, imageView: imageView)
        }
    }
    
    private func performImageUpdate(webView: WKWebView, imageView: NSImageView) {
        guard #available(macOS 10.13, *) else {
            print("People.AI snapshot not available on this macOS version")
            return
        }
        
        let snapshotConfig = WKSnapshotConfiguration()
        snapshotConfig.snapshotWidth = NSNumber(value: webView.frame.size.width)
        
        webView.takeSnapshot(with: snapshotConfig) { [weak self] snapshotImage, error in
            guard let self = self else { return }
            
            if let error = error {
                print("People.AI snapshot error: \(error.localizedDescription)")
                return
            }
            
            guard let snapshotImage = snapshotImage else {
                print("People.AI snapshot failed: No image returned")
                return
            }
            
            print("People.AI snapshot size: \(snapshotImage.size.width) x \(snapshotImage.size.height)")
            
            // Resize and blur the image
            let resizedImage = self.resizeImage(snapshotImage, scale: 2.0)
            let blurredImage = self.convertToBlurImage(resizedImage)
            
            DispatchQueue.main.async {
                imageView.image = blurredImage
            }
        }
    }
    
    // MARK: - Image Processing
    private func resizeImage(_ image: NSImage, scale: Double) -> NSImage {
        let newSize = NSSize(width: image.size.width / scale, height: image.size.height / scale)
        
        guard newSize.width > 0 && newSize.height > 0,
              newSize.width <= 10000 && newSize.height <= 10000 else {
            print("People.AI invalid resize dimensions: \(newSize)")
            return image
        }
        
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        
        let context = NSGraphicsContext.current
        context?.imageInterpolation = .high
        
        image.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: image.size),
                  operation: .copy,
                  fraction: 1.0)
        
        resizedImage.unlockFocus()
        
        print("People.AI resized image size: \(resizedImage.size.width) x \(resizedImage.size.height)")
        return resizedImage
    }
    
    private func convertToBlurImage(_ image: NSImage) -> NSImage {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmapRep.cgImage else {
            print("People.AI failed to convert image to CGImage")
            return image
        }
        
        let inputImage = CIImage(cgImage: cgImage)
        
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else {
            print("People.AI failed to create blur filter")
            return image
        }
        
        blurFilter.setDefaults()
        blurFilter.setValue(inputImage, forKey: kCIInputImageKey)
        blurFilter.setValue(20, forKey: kCIInputRadiusKey)
        
        guard let outputImage = blurFilter.outputImage else {
            print("People.AI failed to create output image")
            return image
        }
        
        // Create shared context if needed
        if sharedContext == nil {
            sharedContext = CIContext(options: nil)
        }
        
        guard let context = sharedContext,
              let cgOutputImage = context.createCGImage(outputImage, from: inputImage.extent) else {
            print("People.AI failed to create CGImage from output")
            return image
        }
        
        let blurredImage = NSImage(cgImage: cgOutputImage, size: NSSize.zero)
        
        print("People.AI blurred image size: \(blurredImage.size.width) x \(blurredImage.size.height)")
        return blurredImage
    }
    
    // MARK: - Cleanup
    func removeBackgroundEffect() {
        animationTimer?.invalidate()
        animationTimer = nil
        
        imageView?.removeFromSuperview()
        imageView = nil
    }
    
    func cleanup() {
        removeBackgroundEffect()
        sharedContext = nil
    }
}
