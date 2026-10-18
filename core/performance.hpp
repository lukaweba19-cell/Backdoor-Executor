// performance.hpp - Performance monitoring and profiling system
// Copyright (c) 2025, All rights reserved.
#pragma once

#include <string>
#include <chrono>
#include <vector>
#include <map>
#include <mutex>
#include <atomic>
#include <memory>
#include <sstream>
#include <iomanip>
#include <algorithm>
#include <thread>
#include <functional>

#include "logging.hpp"
#include "filesystem_utils.h"

namespace Performance {

// Performance metrics to track
struct Metric {
    std::string name;
    std::string category;
    double totalTime;      // in milliseconds
    double minTime;        // in milliseconds
    double maxTime;        // in milliseconds
    double avgTime;        // in milliseconds
    uint64_t callCount;
    double lastTime;       // in milliseconds
    std::chrono::system_clock::time_point lastCall;
    
    Metric(const std::string& n = "", const std::string& cat = "")
        : name(n), category(cat), totalTime(0), minTime(std::numeric_limits<double>::max()),
          maxTime(0), avgTime(0), callCount(0), lastTime(0) {}
    
    void Update(double time) {
        totalTime += time;
        minTime = std::min(minTime, time);
        maxTime = std::max(maxTime, time);
        callCount++;
        avgTime = totalTime / callCount;
        lastTime = time;
        lastCall = std::chrono::system_clock::now();
    }
    
    std::string ToString() const {
        std::stringstream ss;
        ss << std::fixed << std::setprecision(3);
        ss << name << " (" << category << "): ";
        ss << "avg=" << avgTime << "ms, ";
        ss << "min=" << minTime << "ms, ";
        ss << "max=" << maxTime << "ms, ";
        ss << "total=" << totalTime << "ms, ";
        ss << "calls=" << callCount;
        return ss.str();
    }
};

// Performance profiler class to time code sections
class Profiler {
private:
    static std::mutex s_metricsMutex;
    static std::map<std::string, Metric> s_metrics;
    static std::atomic<bool> s_enabled;
    static std::atomic<bool> s_autoLogEnabled;
    static std::atomic<uint64_t> s_autoLogThreshold; // in milliseconds
    static std::thread s_backgroundThread;
    static std::atomic<bool> s_shouldRun;
    static std::string s_reportPath;
    
public:
    // Enable or disable profiling
    static void Enable(bool enable = true) {
        s_enabled = enable;
    }
    
    // Check if profiling is enabled
    static bool IsEnabled() {
        return s_enabled;
    }
    
    // Enable auto-logging of slow operations
    static void EnableAutoLogging(bool enable = true, uint64_t thresholdMs = 100) {
        s_autoLogEnabled = enable;
        s_autoLogThreshold = thresholdMs;
    }
    
    // Start the background monitoring thread
    static void StartMonitoring(uint64_t intervalMs = 60000) { // Default: monitor every minute
        if (s_backgroundThread.joinable()) {
            StopMonitoring();
        }
        
        s_shouldRun = true;
        s_backgroundThread = std::thread([intervalMs]() {
            while (s_shouldRun) {
                // Save report periodically
                SaveReport();
                
                // Sleep for the specified interval
                std::this_thread::sleep_for(std::chrono::milliseconds(intervalMs));
            }
        });
    }
    
    // Stop the background monitoring thread
    static void StopMonitoring() {
        if (s_backgroundThread.joinable()) {
            s_shouldRun = false;
            s_backgroundThread.join();
        }
    }
    
    // Set path for performance reports
    static void SetReportPath(const std::string& path) {
        s_reportPath = path;
        FileUtils::EnsureDirectoryExists(path);
    }
    
    // Get all metrics
    static std::vector<Metric> GetMetrics() {
        std::lock_guard<std::mutex> lock(s_metricsMutex);
        std::vector<Metric> metrics;
        metrics.reserve(s_metrics.size());
        
        for (const auto& pair : s_metrics) {
            metrics.push_back(pair.second);
        }
        
        return metrics;
    }
    
    // Get metrics by category
    static std::vector<Metric> GetMetricsByCategory(const std::string& category) {
        std::lock_guard<std::mutex> lock(s_metricsMutex);
        std::vector<Metric> metrics;
        
        for (const auto& pair : s_metrics) {
            if (pair.second.category == category) {
                metrics.push_back(pair.second);
            }
        }
        
        return metrics;
    }
    
    // Reset all metrics
    static void ResetMetrics() {
        std::lock_guard<std::mutex> lock(s_metricsMutex);
        s_metrics.clear();
    }
    
    // Save performance report to file
    static void SaveReport(const std::string& customPath = "") {
        if (!s_enabled) return;
        
        try {
            // Use custom path or default path
            std::string reportPath;
            if (!customPath.empty()) {
                reportPath = customPath;
                FileUtils::EnsureDirectoryExists(FileUtils::GetDirectoryName(reportPath));
            } else if (!s_reportPath.empty()) {
                // Create filename with timestamp
                auto now = std::chrono::system_clock::now();
                auto time_t_now = std::chrono::system_clock::to_time_t(now);
                std::stringstream ss;
                ss << s_reportPath << "/perf_" 
                   << std::put_time(std::localtime(&time_t_now), "%Y%m%d_%H%M%S")
                   << ".txt";
                reportPath = ss.str();
            } else {
                reportPath = FileUtils::GetLogPath() + "/performance.txt";
            }
            
            // Get all metrics and sort by category
            std::vector<Metric> metrics = GetMetrics();
            std::sort(metrics.begin(), metrics.end(), [](const Metric& a, const Metric& b) {
                if (a.category != b.category) {
                    return a.category < b.category;
                }
                return a.avgTime > b.avgTime; // Sort by descending average time within category
            });
            
            // Generate report
            std::stringstream report;
            report << "========================================\n";
            
            // Store time in a variable before taking its address
            auto now = std::chrono::system_clock::now();
            time_t time_now = std::chrono::system_clock::to_time_t(now);
            report << "Performance Report - " << std::put_time(std::localtime(&time_now), "%Y-%m-%d %H:%M:%S") << "\n";
            
            report << "========================================\n\n";
            
            std::string currentCategory = "";
            for (const auto& metric : metrics) {
                if (metric.category != currentCategory) {
                    if (!currentCategory.empty()) {
                        report << "\n";
                    }
                    currentCategory = metric.category;
                    report << "== " << currentCategory << " ==\n";
                }
                
                report << metric.ToString() << "\n";
            }
            
            // Add summary
            report << "\n========================================\n";
            report << "Summary:\n";
            report << "  - Total metrics: " << metrics.size() << "\n";
            
            std::map<std::string, int> categoryCounts;
            for (const auto& metric : metrics) {
                categoryCounts[metric.category]++;
            }
            
            report << "  - Categories: " << categoryCounts.size() << "\n";
            for (const auto& pair : categoryCounts) {
                report << "    - " << pair.first << ": " << pair.second << " metrics\n";
            }
            
            // Write to file
            FileUtils::WriteFile(reportPath, report.str());
            
            Logging::LogInfo("Performance", "Performance report saved to: " + reportPath);
        } catch (const std::exception& ex) {
            Logging::LogError("Performance", "Failed to save performance report: " + std::string(ex.what()));
        }
    }
    
    // Log performance report to logger
    static void LogReport() {
        if (!s_enabled) return;
        
        try {
            // Get all metrics and sort by category
            std::vector<Metric> metrics = GetMetrics();
            std::sort(metrics.begin(), metrics.end(), [](const Metric& a, const Metric& b) {
                if (a.category != b.category) {
                    return a.category < b.category;
                }
                return a.avgTime > b.avgTime; // Sort by descending average time
            });
            
            // Log report header
            Logging::LogInfo("Performance", "Performance Report");
            
            // Log metrics by category
            std::string currentCategory = "";
            for (const auto& metric : metrics) {
                if (metric.category != currentCategory) {
                    currentCategory = metric.category;
                    Logging::LogInfo("Performance", "Category: " + currentCategory);
                }
                
                Logging::LogInfo("Performance", "  " + metric.ToString());
            }
            
            // Log summary
            Logging::LogInfo("Performance", "Total metrics: " + std::to_string(metrics.size()));
        } catch (const std::exception& ex) {
            Logging::LogError("Performance", "Failed to log performance report: " + std::string(ex.what()));
        }
    }
    
    // Record timing for an operation
    static void RecordTiming(const std::string& name, const std::string& category, double timeMs) {
        if (!s_enabled) return;
        
        try {
            // Update metrics
            {
                std::lock_guard<std::mutex> lock(s_metricsMutex);
                
                std::string key = category + "::" + name;
                auto it = s_metrics.find(key);
                
                if (it == s_metrics.end()) {
                    // Create new metric
                    Metric metric(name, category);
                    metric.Update(timeMs);
                    s_metrics[key] = metric;
                } else {
                    // Update existing metric
                    it->second.Update(timeMs);
                }
            }
            
            // Auto log slow operations
            if (s_autoLogEnabled && timeMs > s_autoLogThreshold) {
                Logging::LogWarning("Performance", 
                    "Slow operation detected: " + category + "::" + name + " took " + 
                    std::to_string(timeMs) + "ms (threshold: " + std::to_string(s_autoLogThreshold) + "ms)");
            }
        } catch (const std::exception& ex) {
            Logging::LogError("Performance", "Failed to record timing: " + std::string(ex.what()));
        }
    }
};

// Static members defined in performance.cpp

// ScopedTimer class for automatic timing of code sections
class ScopedTimer {
private:
    std::string m_name;
    std::string m_category;
    std::chrono::high_resolution_clock::time_point m_start;
    bool m_enabled;
    
public:
    ScopedTimer(const std::string& name, const std::string& category = "Default")
        : m_name(name), m_category(category), m_enabled(Profiler::IsEnabled()) {
        if (m_enabled) {
            m_start = std::chrono::high_resolution_clock::now();
        }
    }
    
    ~ScopedTimer() {
        if (m_enabled) {
            auto end = std::chrono::high_resolution_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - m_start);
            double timeMs = duration.count() / 1000.0;
            
            Profiler::RecordTiming(m_name, m_category, timeMs);
        }
    }
};

// Function timer template for timing function calls
template<typename Func, typename... Args>
auto TimedFunction(const std::string& name, const std::string& category, Func&& func, Args&&... args) {
    ScopedTimer timer(name, category);
    return std::forward<Func>(func)(std::forward<Args>(args)...);
}

// Initialize the performance monitoring system
inline void InitializePerformanceMonitoring(bool enableProfiling = true, 
                                          bool enableAutoLogging = true,
                                          uint64_t autoLogThresholdMs = 100,
                                          uint64_t monitoringIntervalMs = 60000) {
    // Create performance report directory
    std::string perfPath = FileUtils::GetLogPath() + "/performance";
    FileUtils::EnsureDirectoryExists(perfPath);
    
    // Configure profiler
    Profiler::SetReportPath(perfPath);
    Profiler::Enable(enableProfiling);
    Profiler::EnableAutoLogging(enableAutoLogging, autoLogThresholdMs);
    
    // Start monitoring thread if profiling is enabled
    if (enableProfiling) {
        Profiler::StartMonitoring(monitoringIntervalMs);
    }
    
    Logging::LogInfo("Performance", "Performance monitoring initialized");
}

// Convenience macro for timing a scope with auto name from function
#define PROFILE_FUNCTION() Performance::ScopedTimer _profiler_timer_func(__FUNCTION__, "Function")

// Convenience macro for timing a scope with custom name
#define PROFILE_SCOPE(name, category) Performance::ScopedTimer _profiler_timer_##name(#name, category)

// Convenience macro for timing a block with custom name
#define PROFILE_BLOCK(name, category) \
    { \
        Performance::ScopedTimer _profiler_timer_block(name, category);

#define END_PROFILE_BLOCK() \
    }

} // namespace Performance
