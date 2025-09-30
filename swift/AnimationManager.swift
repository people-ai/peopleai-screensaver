//
//  AnimationManager.swift
//  People.ai Screensaver
//
//  Created by People.ai on 1/6/20.
//  Copyright © 2020-2024 People.ai, Inc. All rights reserved.
//

import AppKit
import QuartzCore

// MARK: - Animation Manager
class AnimationManager {
    
    // MARK: - Properties
    private let slideTransitionDuration: TimeInterval = 0.8
    private var currentSlideAnimation: NSViewAnimation?
    
    // MARK: - Slide Transition Animation
    func animateSlideTransition(for webView: NSView, completion: @escaping () -> Void) {
        // Ensure webView is visible
        webView.isHidden = false
        webView.alphaValue = 1.0
        
        // Stop any existing animation
        currentSlideAnimation?.stop()
        currentSlideAnimation = nil
        
        // Get current frame
        let currentFrame = webView.frame
        let startFrame = currentFrame
        let endFrame = currentFrame
        
        // Animation parameters
        let zoomFactor: CGFloat = 1.02
        let fadeAlpha: CGFloat = 0.9
        
        // Create view animation
        let animationDict: [NSViewAnimation.Key: Any] = [
            NSViewAnimation.Key.target: webView,
            NSViewAnimation.Key.startFrame: NSValue(rect: startFrame),
            NSViewAnimation.Key.endFrame: NSValue(rect: endFrame),
            NSViewAnimation.Key.effect: NSViewAnimation.EffectName.fadeIn
        ]
        
        currentSlideAnimation = NSViewAnimation(viewAnimations: [animationDict])
        currentSlideAnimation?.duration = slideTransitionDuration * 0.6
        currentSlideAnimation?.animationCurve = .easeInOut
        currentSlideAnimation?.animationBlockingMode = .nonblocking
        
        // Create Core Animation for scale and fade
        createCoreAnimations(for: webView, zoomFactor: zoomFactor, fadeAlpha: fadeAlpha)
        
        // Start animation
        currentSlideAnimation?.start()
        
        // Clean up after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + slideTransitionDuration * 0.6) {
            self.cleanupAnimations(for: webView)
            webView.alphaValue = 1.0
            webView.isHidden = false
            completion()
        }
    }
    
    private func createCoreAnimations(for webView: NSView, zoomFactor: CGFloat, fadeAlpha: CGFloat) {
        webView.wantsLayer = true
        
        guard let layer = webView.layer else { return }
        
        // Scale animation
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = zoomFactor
        scaleAnimation.duration = slideTransitionDuration * 0.3
        scaleAnimation.autoreverses = true
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // Fade animation
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 1.0
        fadeAnimation.toValue = fadeAlpha
        fadeAnimation.duration = slideTransitionDuration * 0.2
        fadeAnimation.autoreverses = true
        fadeAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // Add animations to layer
        layer.add(scaleAnimation, forKey: "slideScale")
        layer.add(fadeAnimation, forKey: "slideFade")
    }
    
    private func cleanupAnimations(for webView: NSView) {
        webView.layer?.removeAnimation(forKey: "slideScale")
        webView.layer?.removeAnimation(forKey: "slideFade")
        currentSlideAnimation = nil
    }
    
    // MARK: - Fade Animation
    func fadeIn(_ view: NSView, duration: TimeInterval = 0.5, completion: (() -> Void)? = nil) {
        view.alphaValue = 0.0
        view.isHidden = false
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            view.animator().alphaValue = 1.0
        }, completionHandler: completion)
    }
    
    func fadeOut(_ view: NSView, duration: TimeInterval = 0.5, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            view.animator().alphaValue = 0.0
        }, completionHandler: {
            view.isHidden = true
            completion?()
        })
    }
    
    // MARK: - Scale Animation
    func scaleIn(_ view: NSView, fromScale: CGFloat = 0.8, duration: TimeInterval = 0.5, completion: (() -> Void)? = nil) {
        view.wantsLayer = true
        view.layer?.transform = CATransform3DMakeScale(fromScale, fromScale, 1.0)
        view.isHidden = false
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view.layer?.transform = CATransform3DIdentity
        }, completionHandler: completion)
    }
    
    func scaleOut(_ view: NSView, toScale: CGFloat = 0.8, duration: TimeInterval = 0.5, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            view.layer?.transform = CATransform3DMakeScale(toScale, toScale, 1.0)
        }, completionHandler: {
            view.isHidden = true
            completion?()
        })
    }
    
    // MARK: - Combined Animations
    func slideInFromLeft(_ view: NSView, duration: TimeInterval = 0.6, completion: (() -> Void)? = nil) {
        let originalFrame = view.frame
        let startFrame = NSRect(x: -originalFrame.width, y: originalFrame.origin.y, 
                               width: originalFrame.width, height: originalFrame.height)
        
        view.frame = startFrame
        view.isHidden = false
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view.animator().frame = originalFrame
        }, completionHandler: completion)
    }
    
    func slideOutToRight(_ view: NSView, duration: TimeInterval = 0.6, completion: (() -> Void)? = nil) {
        let originalFrame = view.frame
        let endFrame = NSRect(x: originalFrame.origin.x + originalFrame.width, y: originalFrame.origin.y,
                              width: originalFrame.width, height: originalFrame.height)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            view.animator().frame = endFrame
        }, completionHandler: {
            view.isHidden = true
            view.frame = originalFrame
            completion?()
        })
    }
    
    // MARK: - Cleanup
    func stopAllAnimations(for view: NSView) {
        currentSlideAnimation?.stop()
        currentSlideAnimation = nil
        
        view.layer?.removeAllAnimations()
        view.alphaValue = 1.0
        view.isHidden = false
    }
}
