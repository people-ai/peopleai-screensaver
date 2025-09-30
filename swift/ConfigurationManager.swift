//
//  ConfigurationManager.swift
//  People.ai Screensaver
//
//  Created by People.ai on 1/6/20.
//  Copyright © 2020-2024 People.ai, Inc. All rights reserved.
//

import Foundation
import ScreenSaver

// MARK: - Configuration Model
struct ScreensaverConfiguration: Codable {
    let slidesUrl: String?
    let stayOnSlideTime: Int?
    let resetSlidesWhenStarted: Bool?
    let maxSlides: Int?
    let zoomForFullScreen: Bool?
    let viewRefreshTime: Double?
    let fillEmptySpace: Bool?
    let dynamic: Bool?
    let emptySpaceFillImage: String?
    let emptySpaceFillMode: String?
    
    enum CodingKeys: String, CodingKey {
        case slidesUrl = "slidesUrl"
        case stayOnSlideTime = "stayOnSlideTime"
        case resetSlidesWhenStarted = "resetSlidesWhenStarted"
        case maxSlides = "maxSlides"
        case zoomForFullScreen = "zoomForFullScreen"
        case viewRefreshTime = "viewRefreshTime"
        case fillEmptySpace = "fillEmptySpace"
        case dynamic = "dynamic"
        case emptySpaceFillImage = "emptySpaceFillImage"
        case emptySpaceFillMode = "emptySpaceFillMode"
    }
}

// MARK: - Configuration Manager
class ConfigurationManager {
    
    // MARK: - Properties
    private let moduleName: String
    private let userDefaults: UserDefaults
    
    // MARK: - Initialization
    init() {
        self.moduleName = Bundle(for: PeopleScreensaverView.self).bundleIdentifier ?? "com.peopleai.screensaver"
        self.userDefaults = UserDefaults(suiteName: moduleName) ?? UserDefaults.standard
    }
    
    // MARK: - Configuration Loading
    func loadConfiguration() -> ScreensaverConfiguration {
        return ScreensaverConfiguration(
            slidesUrl: userDefaults.string(forKey: "slidesUrl"),
            stayOnSlideTime: userDefaults.object(forKey: "stayOnSlideTime") as? Int,
            resetSlidesWhenStarted: userDefaults.object(forKey: "resetSlidesWhenStarted") as? Bool,
            maxSlides: userDefaults.object(forKey: "maxSlides") as? Int,
            zoomForFullScreen: userDefaults.object(forKey: "zoomForFullScreen") as? Bool,
            viewRefreshTime: userDefaults.object(forKey: "viewRefreshTime") as? Double,
            fillEmptySpace: userDefaults.object(forKey: "fillEmptySpace") as? Bool,
            dynamic: userDefaults.object(forKey: "dynamic") as? Bool,
            emptySpaceFillImage: userDefaults.string(forKey: "emptySpaceFillImage"),
            emptySpaceFillMode: userDefaults.string(forKey: "emptySpaceFillMode")
        )
    }
    
    // MARK: - Current Slide Management
    func getCurrentSlide() -> Int {
        return UserDefaults.standard.integer(forKey: "currentSlideKey")
    }
    
    func setCurrentSlide(_ slide: Int) {
        UserDefaults.standard.set(slide, forKey: "currentSlideKey")
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Validation
    func validateConfiguration(_ config: ScreensaverConfiguration) -> [String] {
        var errors: [String] = []
        
        if let url = config.slidesUrl, url.isEmpty {
            errors.append("Slides URL is empty")
        }
        
        if let time = config.stayOnSlideTime, time < 1 {
            errors.append("Stay on slide time must be at least 1 second")
        }
        
        if let refreshTime = config.viewRefreshTime, refreshTime < 1.0 {
            errors.append("View refresh time must be at least 1.0 second")
        }
        
        return errors
    }
    
    // MARK: - Default Values
    func getDefaultConfiguration() -> ScreensaverConfiguration {
        return ScreensaverConfiguration(
            slidesUrl: nil,
            stayOnSlideTime: 5,
            resetSlidesWhenStarted: true,
            maxSlides: 5,
            zoomForFullScreen: false,
            viewRefreshTime: 30.0,
            fillEmptySpace: false,
            dynamic: false,
            emptySpaceFillImage: nil,
            emptySpaceFillMode: "none"
        )
    }
}
