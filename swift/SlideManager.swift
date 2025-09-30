//
//  SlideManager.swift
//  People.ai Screensaver
//
//  Created by People.ai on 1/6/20.
//  Copyright © 2020-2024 People.ai, Inc. All rights reserved.
//

import Foundation
import WebKit

// MARK: - Slide Manager Protocol
protocol SlideManagerDelegate: AnyObject {
    func slideManager(_ manager: SlideManager, didLoadSlide slideURL: String)
    func slideManager(_ manager: SlideManager, didFailToLoadSlide slideURL: String, error: Error)
    func slideManager(_ manager: SlideManager, didCacheSlide slideURL: String)
}

// MARK: - Slide Manager
class SlideManager {
    
    // MARK: - Properties
    weak var delegate: SlideManagerDelegate?
    private var slides: [String] = []
    private var slideCache: [String: Data] = [:]
    private var loadingSlides: Set<String> = []
    private var currentSlideIndex: Int = 0
    private var isFirstLoop: Bool = true
    
    // MARK: - Initialization
    init() {
        slideCache = [:]
        loadingSlides = []
        currentSlideIndex = 0
        isFirstLoop = true
    }
    
    // MARK: - Slide Management
    func initializeSlides(from link: String) {
        var slidesArray: [String] = []
        
        // Add base link
        slidesArray.append(link)
        
        // Add numbered slides
        for i in 1...5 {
            let slideURL = "\(link)?slide=\(i)"
            slidesArray.append(slideURL)
        }
        
        slides = slidesArray
        currentSlideIndex = 0
        isFirstLoop = true
        
        print("People.AI initialized \(slides.count) slides for background loading")
    }
    
    func getCurrentSlide() -> String? {
        guard currentSlideIndex < slides.count else { return nil }
        return slides[currentSlideIndex]
    }
    
    func getNextSlide() -> String? {
        let nextIndex = (currentSlideIndex + 1) % slides.count
        guard nextIndex < slides.count else { return nil }
        return slides[nextIndex]
    }
    
    func progressToNextSlide() {
        currentSlideIndex = (currentSlideIndex + 1) % slides.count
        
        if currentSlideIndex == 0 && isFirstLoop {
            isFirstLoop = false
            print("People.AI completed first loop, now using cache")
        }
    }
    
    // MARK: - URL Creation
    func createAutoplayURL(from link: String, time: Int, slide: Int) -> String {
        if slide > 0 {
            return "\(link)?rm=minimal&start=true&loop=true&delayms=\(time * 1000)&slide=\(slide)"
        } else {
            return "\(link)?rm=minimal&start=true&loop=true&delayms=\(time * 1000)"
        }
    }
    
    func createPreviewURL(from link: String, mode: String, slide: Int) -> String {
        return "\(link)/preview?rm=\(mode)&slide=\(slide)"
    }
    
    // MARK: - Caching
    func isSlideCached(_ slideURL: String) -> Bool {
        return slideCache[slideURL] != nil
    }
    
    func getCachedSlide(_ slideURL: String) -> Data? {
        return slideCache[slideURL]
    }
    
    func cacheSlide(_ slideURL: String, data: Data) {
        slideCache[slideURL] = data
        delegate?.slideManager(self, didCacheSlide: slideURL)
    }
    
    func clearCache() {
        slideCache.removeAll()
    }
    
    // MARK: - Background Loading
    func startBackgroundLoading(of slideURL: String) {
        guard !loadingSlides.contains(slideURL) else { return }
        guard !isSlideCached(slideURL) || isFirstLoop else { return }
        
        loadingSlides.insert(slideURL)
        
        Task {
            do {
                let data = try await loadSlideData(from: slideURL)
                await MainActor.run {
                    self.loadingSlides.remove(slideURL)
                    self.cacheSlide(slideURL, data: data)
                    print("People.AI cached slide in background: \(slideURL)")
                }
            } catch {
                await MainActor.run {
                    self.loadingSlides.remove(slideURL)
                    print("People.AI failed to preload slide: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadSlideData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw ScreensaverError.networkFailure("Invalid URL: \(urlString)")
        }
        
        let request = URLRequest(
            url: url,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 30.0
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ScreensaverError.networkFailure("HTTP error: \(response)")
        }
        
        return data
    }
    
    // MARK: - Cache Management
    func getCacheSize() -> Int {
        return slideCache.count
    }
    
    func getCacheMemoryUsage() -> Int {
        return slideCache.values.reduce(0) { $0 + $1.count }
    }
    
    func clearOldCacheEntries() {
        // Keep only the most recent 10 slides in cache
        if slideCache.count > 10 {
            let keysToRemove = Array(slideCache.keys.prefix(slideCache.count - 10))
            for key in keysToRemove {
                slideCache.removeValue(forKey: key)
            }
        }
    }
}
