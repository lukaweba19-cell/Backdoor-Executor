// Diagnostic.hpp - Runtime diagnostics system for iOS Roblox Executor
#pragma once

#include <string>
#include <vector>
#include <map>
#include <functional>
#include <chrono>
#include <memory>
#include <mutex>

namespace Diagnostics {

// Diagnostic test result
struct TestResult {
    std::string name;
    bool success;
    std::string details;
    double durationMs;
};

// System information
struct SystemInfo {
    std::string deviceModel;
    std::string osVersion;
    std::string appVersion;
    std::string jailbreakType;
    bool isDebugBuild;
    std::map<std::string, bool> features;
    std::map<std::string, std::string> additionalInfo;
};

// Callback types
using DiagnosticCallback = std::function<void(const std::vector<TestResult>&)>;
using SystemInfoCallback = std::function<void(const SystemInfo&)>;

/**
 * @class DiagnosticSystem
 * @brief Provides runtime diagnostics for the executor
 */
class DiagnosticSystem {
public:
    // Initialize the diagnostic system
    static bool Initialize();
    
    // Run all diagnostic tests
    static std::vector<TestResult> RunAllTests();
    
    // Run a specific test by name
    static TestResult RunTest(const std::string& testName);
    
    // Get system information
    static SystemInfo GetSystemInfo();
    
    // Register callback for diagnostic results
    static void RegisterDiagnosticCallback(DiagnosticCallback callback);
    
    // Register callback for system info updates
    static void RegisterSystemInfoCallback(SystemInfoCallback callback);
    
    // Log diagnostic data to file
    static bool LogToFile(const std::string& filePath);
    
    // Generate a full diagnostic report (HTML format)
    static std::string GenerateReport();
    
    // Export diagnostic data as JSON
    static std::string ExportAsJson();
    
private:
    // Individual diagnostic tests
    static TestResult TestLuaVMIntegration();
    static TestResult TestMemoryAccess();
    static TestResult TestHookFunctionality();
    static TestResult TestFileSystem();
    static TestResult TestUIInjection();
    static TestResult TestSecurityFeatures();
    static TestResult TestNetworkConnectivity();
    static TestResult TestAIFeatures();
    
    // System information gathering
    static void GatherSystemInfo();
    
    // Helper method to run a test and measure execution time
    static TestResult RunTestWithTiming(const std::string& name, 
                                       std::function<TestResult()> testFunc);
    
    // Private members
    static std::mutex s_mutex;
    static std::vector<DiagnosticCallback> s_diagnosticCallbacks;
    static std::vector<SystemInfoCallback> s_systemInfoCallbacks;
    static SystemInfo s_systemInfo;
    static std::map<std::string, std::function<TestResult()>> s_testFunctions;
};

} // namespace Diagnostics
