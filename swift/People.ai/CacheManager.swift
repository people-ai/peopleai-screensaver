//
//  CacheManager.swift
//  People.ai
//
//  Created by People.ai on 1/6/20.
//  Copyright © 2020-2022 People.ai, Inc. All rights reserved.
//  Thread-safe cache management with LRU eviction
//

import Foundation
import os.log

/// Thread-safe cache manager using Swift Actor for automatic serialization
actor CacheManager {
    
    // MARK: - Properties
    private var cache: [String: Data] = [:]
    private var accessOrder: [String] = [] // For LRU tracking
    private let maxEntries = 25
    
    // MARK: - Logging
    private static let logger = OSLog(subsystem: "ai.people.screensaver", category: "cache")
    
    // MARK: - Public Interface
    
    /// Get cached data for a key
    func get(_ key: String) async -> Data? {
        guard let data = cache[key] else {
            return nil
        }
        
        // Update access order for LRU tracking
        updateAccessOrder(for: key)
        
        os_log("Cache hit for key: %{public}@", log: Self.logger, type: .info, key)
        return data
    }
    
    /// Set cached data for a key
    func set(_ key: String, value: Data) async {
        // Check if we need to evict entries
        if cache.count >= maxEntries && cache[key] == nil {
            await evictLRU()
        }
        
        cache[key] = value
        updateAccessOrder(for: key)
        
        os_log("Cache set for key: %{public}@ (size: %d bytes, total entries: %d)", 
               log: Self.logger, type: .info, key, value.count, cache.count)
    }
    
    /// Clear all cached data
    func clear() async {
        cache.removeAll()
        accessOrder.removeAll()
        
        os_log("Cache cleared", log: Self.logger, type: .info)
    }
    
    /// Get current cache statistics
    func getStats() async -> (count: Int, maxEntries: Int, totalSize: Int) {
        let totalSize = cache.values.reduce(0) { $0 + $1.count }
        return (count: cache.count, maxEntries: maxEntries, totalSize: totalSize)
    }
    
    // MARK: - Private Methods
    
    /// Update access order for LRU tracking
    private func updateAccessOrder(for key: String) {
        // Remove key from current position if it exists
        accessOrder.removeAll { $0 == key }
        // Add to end (most recently used)
        accessOrder.append(key)
    }
    
    /// Evict least recently used entry
    private func evictLRU() async {
        guard !accessOrder.isEmpty else { return }
        
        let keyToEvict = accessOrder.removeFirst()
        cache.removeValue(forKey: keyToEvict)
        
        os_log("Evicted LRU entry: %{public}@", log: Self.logger, type: .info, keyToEvict)
    }
}

// MARK: - Cache Key Normalization
extension CacheManager {
    
    /// Create a normalized cache key by stripping volatile URL parameters
    static func normalizeKey(from url: String) -> String {
        guard let urlComponents = URLComponents(string: url) else {
            return url
        }
        
        // Remove volatile parameters that change between requests
        let volatileParams = ["timestamp", "t", "time", "cache", "nocache", "random", "r"]
        
        let filteredQueryItems = urlComponents.queryItems?.filter { queryItem in
            !volatileParams.contains(queryItem.name.lowercased())
        }
        
        var normalizedComponents = urlComponents
        normalizedComponents.queryItems = filteredQueryItems
        
        return normalizedComponents.url?.absoluteString ?? url
    }
}