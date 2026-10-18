// error_handling.hpp - Comprehensive error handling system for production use
// Copyright (c) 2025, All rights reserved.
#pragma once

#include <string>
#include <stdexcept>
#include <functional>
#include <map>
#include <vector>
#include <mutex>
#include <sstream>
#include <iostream>
#include <chrono>
#include <ctime>
#include <atomic>

#include "logging.hpp"

namespace ErrorHandling {

// Error severity levels - aligned with logging system
enum class ErrorSeverity {
    INFO,       // Informational messages that are not errors
    WARNING,    // Warnings that don't stop execution
    ERROR,      // Recoverable errors
    CRITICAL,   // Critical errors that might lead to crash
    FATAL       // Unrecoverable errors that will crash the application
};

// Error categories
enum class ErrorCategory {
    GENERAL,        // General errors
    MEMORY,         // Memory related errors (allocation, access, etc.)
    FILE_SYSTEM,    // File I/O errors
    NETWORK,        // Network-related errors
    SCRIPT,         // Script execution errors
    SECURITY,       // Security-related errors
    UI,             // UI-related errors
    HOOK,           // Hooking-related errors
    SYSTEM,         // System-level errors
    EXTERNAL_LIB    // Errors from external libraries
};

// Convert error category to string
inline std::string ErrorCategoryToString(ErrorCategory category) {
    switch (category) {
        case ErrorCategory::GENERAL: return "General";
        case ErrorCategory::MEMORY: return "Memory";
        case ErrorCategory::FILE_SYSTEM: return "FileSystem";
        case ErrorCategory::NETWORK: return "Network";
        case ErrorCategory::SCRIPT: return "Script";
        case ErrorCategory::SECURITY: return "Security";
        case ErrorCategory::UI: return "UI";
        case ErrorCategory::HOOK: return "Hook";
        case ErrorCategory::SYSTEM: return "System";
        case ErrorCategory::EXTERNAL_LIB: return "ExternalLib";
        default: return "Unknown";
    }
}

// Convert severity to string
inline std::string ErrorSeverityToString(ErrorSeverity severity) {
    switch (severity) {
        case ErrorSeverity::INFO: return "Info";
        case ErrorSeverity::WARNING: return "Warning";
        case ErrorSeverity::ERROR: return "Error";
        case ErrorSeverity::CRITICAL: return "Critical";
        case ErrorSeverity::FATAL: return "Fatal";
        default: return "Unknown";
    }
}

// Error code structure
struct ErrorCode {
    ErrorCategory category;
    int code;
    std::string message;
    
    ErrorCode(ErrorCategory cat, int c, const std::string& msg)
        : category(cat), code(c), message(msg) {}
    
    std::string ToString() const {
        std::stringstream ss;
        ss << ErrorCategoryToString(category) << ":" << code << " - " << message;
        return ss.str();
    }
};

// Pre-defined error codes
namespace ErrorCodes {
    // General errors (0-99)
    const ErrorCode SUCCESS(ErrorCategory::GENERAL, 0, "Success");
    const ErrorCode UNKNOWN_ERROR(ErrorCategory::GENERAL, 1, "Unknown error");
    const ErrorCode OPERATION_FAILED(ErrorCategory::GENERAL, 2, "Operation failed");
    const ErrorCode INVALID_ARGUMENT(ErrorCategory::GENERAL, 3, "Invalid argument");
    const ErrorCode INVALID_STATE(ErrorCategory::GENERAL, 4, "Invalid state");
    
    // Memory errors (100-199)
    const ErrorCode MEMORY_ALLOCATION_FAILED(ErrorCategory::MEMORY, 100, "Memory allocation failed");
    const ErrorCode MEMORY_ACCESS_VIOLATION(ErrorCategory::MEMORY, 101, "Memory access violation");
    const ErrorCode NULL_POINTER(ErrorCategory::MEMORY, 102, "Null pointer");
    
    // File system errors (200-299)
    const ErrorCode FILE_NOT_FOUND(ErrorCategory::FILE_SYSTEM, 200, "File not found");
    const ErrorCode FILE_ACCESS_DENIED(ErrorCategory::FILE_SYSTEM, 201, "File access denied");
    const ErrorCode FILE_READ_ERROR(ErrorCategory::FILE_SYSTEM, 202, "File read error");
    const ErrorCode FILE_WRITE_ERROR(ErrorCategory::FILE_SYSTEM, 203, "File write error");
    
    // Script errors (300-399)
    const ErrorCode SCRIPT_EXECUTION_ERROR(ErrorCategory::SCRIPT, 300, "Script execution error");
    const ErrorCode SCRIPT_SYNTAX_ERROR(ErrorCategory::SCRIPT, 301, "Script syntax error");
    const ErrorCode SCRIPT_TIMEOUT(ErrorCategory::SCRIPT, 302, "Script execution timeout");
    
    // Security errors (400-499)
    const ErrorCode SECURITY_VIOLATION(ErrorCategory::SECURITY, 400, "Security violation");
    const ErrorCode JAILBREAK_DETECTED(ErrorCategory::SECURITY, 401, "Jailbreak detected");
    const ErrorCode TAMPER_DETECTED(ErrorCategory::SECURITY, 402, "Tampering detected");
    
    // Hook errors (500-599)
    const ErrorCode HOOK_FAILED(ErrorCategory::HOOK, 500, "Hook failed");
    const ErrorCode HOOK_ALREADY_EXISTS(ErrorCategory::HOOK, 501, "Hook already exists");
    const ErrorCode HOOK_TARGET_NOT_FOUND(ErrorCategory::HOOK, 502, "Hook target not found");
    
    // UI errors (600-699)
    const ErrorCode UI_INITIALIZATION_FAILED(ErrorCategory::UI, 600, "UI initialization failed");
    const ErrorCode UI_ELEMENT_NOT_FOUND(ErrorCategory::UI, 601, "UI element not found");
    
    // System errors (700-799)
    const ErrorCode SYSTEM_CALL_FAILED(ErrorCategory::SYSTEM, 700, "System call failed");
    const ErrorCode PERMISSION_DENIED(ErrorCategory::SYSTEM, 701, "Permission denied");
    
    // External library errors (800-899)
    const ErrorCode EXTERNAL_LIB_LOAD_FAILED(ErrorCategory::EXTERNAL_LIB, 800, "External library load failed");
    const ErrorCode EXTERNAL_LIB_FUNCTION_NOT_FOUND(ErrorCategory::EXTERNAL_LIB, 801, "External library function not found");
}

// Custom exception class
class ExecutorException : public std::exception {
private:
    ErrorCode m_error;
    std::string m_details;
    std::string m_fullMessage;
    std::string m_stackTrace;
    std::chrono::system_clock::time_point m_timestamp;
    
public:
    ExecutorException(const ErrorCode& error, const std::string& details = "")
        : m_error(error), m_details(details), m_timestamp(std::chrono::system_clock::now()) {
        std::stringstream ss;
        ss << "[" << ErrorCategoryToString(m_error.category) << ":" << m_error.code << "] "
           << m_error.message;
        if (!m_details.empty()) {
            ss << " - " << m_details;
        }
        m_fullMessage = ss.str();
    }
    
    const char* what() const noexcept override {
        return m_fullMessage.c_str();
    }
    
    const ErrorCode& GetErrorCode() const {
        return m_error;
    }
    
    const std::string& GetDetails() const {
        return m_details;
    }
    
    const std::string& GetStackTrace() const {
        return m_stackTrace;
    }
    
    std::chrono::system_clock::time_point GetTimestamp() const {
        return m_timestamp;
    }
    
    void SetStackTrace(const std::string& stackTrace) {
        m_stackTrace = stackTrace;
    }
    
    std::string GetFormattedMessage() const {
        std::stringstream ss;
        auto time_t_value = std::chrono::system_clock::to_time_t(m_timestamp);
        ss << "[" << std::put_time(std::localtime(&time_t_value), "%Y-%m-%d %H:%M:%S") << "] "
           << "Error " << m_error.code << " (" << ErrorCategoryToString(m_error.category) << "): "
           << m_error.message;
        
        if (!m_details.empty()) {
            ss << " - " << m_details;
        }
        
        if (!m_stackTrace.empty()) {
            ss << "\nStack trace:\n" << m_stackTrace;
        }
        
        return ss.str();
    }
};

// Callback type for error handlers
using ErrorHandler = std::function<void(const ExecutorException&)>;

// Global error handler class
class ErrorManager {
private:
    static ErrorManager* s_instance;
    static std::mutex s_mutex;
    
    std::vector<ErrorHandler> m_handlers;
    std::vector<ExecutorException> m_errors;
    size_t m_maxErrorsStored;
    std::atomic<bool> m_crashReportingEnabled;
    std::atomic<bool> m_logEnabled;
    std::string m_crashReportPath;
    
    ErrorManager() : m_maxErrorsStored(100), m_crashReportingEnabled(true), m_logEnabled(true) {
        m_crashReportPath = FileUtils::GetLogPath() + "/crash_reports";
        FileUtils::EnsureDirectoryExists(m_crashReportPath);
    }
    
public:
    static ErrorManager& GetInstance() {
        static std::once_flag onceFlag;
        std::call_once(onceFlag, []() {
            s_instance = new ErrorManager();
        });
        return *s_instance;
    }
    
    void AddHandler(const ErrorHandler& handler) {
        std::lock_guard<std::mutex> lock(s_mutex);
        m_handlers.push_back(handler);
    }
    
    void SetMaxErrorsStored(size_t maxErrors) {
        std::lock_guard<std::mutex> lock(s_mutex);
        m_maxErrorsStored = maxErrors;
        
        // Trim error list if needed
        while (m_errors.size() > m_maxErrorsStored) {
            m_errors.erase(m_errors.begin());
        }
    }
    
    void EnableCrashReporting(bool enable) {
        m_crashReportingEnabled = enable;
    }
    
    void EnableLogging(bool enable) {
        m_logEnabled = enable;
    }
    
    void SetCrashReportPath(const std::string& path) {
        m_crashReportPath = path;
        FileUtils::EnsureDirectoryExists(m_crashReportPath);
    }
    
    void HandleError(const ErrorCode& error, const std::string& details = "") {
        ExecutorException ex(error, details);
        
        // Store the error
        {
            std::lock_guard<std::mutex> lock(s_mutex);
            m_errors.push_back(ex);
            
            // Trim error list if needed
            while (m_errors.size() > m_maxErrorsStored) {
                m_errors.erase(m_errors.begin());
            }
        }
        
        // Log the error
        if (m_logEnabled) {
            Logging::LogLevel logLevel;
            
            // Map error severity to logging level
            ErrorSeverity severity = error.category == ErrorCategory::MEMORY ? 
                ErrorSeverity::CRITICAL : ErrorSeverity::ERROR; // Default mapping
                
            switch (severity) {
                case ErrorSeverity::WARNING:
                    logLevel = Logging::LogLevel::WARNING;
                    break;
                case ErrorSeverity::ERROR:
                    logLevel = Logging::LogLevel::ERROR;
                    break;
                case ErrorSeverity::CRITICAL:
                case ErrorSeverity::FATAL:
                    logLevel = Logging::LogLevel::CRITICAL;
                    break;
                default:
                    logLevel = Logging::LogLevel::INFO;
                    break;
            }
            
            std::string errorCategory = ErrorCategoryToString(error.category);
            Logging::Logger::GetInstance().Log(logLevel, errorCategory, 
                error.message + (details.empty() ? "" : " - " + details));
        }
        
        // Call registered handlers
        std::vector<ErrorHandler> handlers;
        {
            std::lock_guard<std::mutex> lock(s_mutex);
            handlers = m_handlers;
        }
        
        for (const auto& handler : handlers) {
            try {
                handler(ex);
            } catch (...) {
                // Ignore exceptions from handlers
            }
        }
        
        // For fatal errors, generate crash report and terminate
        // Determine if this is a fatal error based on error category or other criteria
        bool isFatalError = false;
        
        // For security or memory errors, treat as fatal
        if (error.category == ErrorCategory::SECURITY && error.code >= 400) {
            isFatalError = true;
        }
        
        if (isFatalError) {
            if (m_crashReportingEnabled) {
                GenerateCrashReport(ex);
            }
            
            // In a real application, you might want to show a crash dialog
            // before terminating, or integrate with a crash reporting service
            
            std::cerr << "FATAL ERROR: " << ex.what() << std::endl;
            std::terminate();
        }
    }
    
    void ClearErrors() {
        std::lock_guard<std::mutex> lock(s_mutex);
        m_errors.clear();
    }
    
    std::vector<ExecutorException> GetErrors() const {
        std::lock_guard<std::mutex> lock(s_mutex);
        return m_errors;
    }
    
private:
    void GenerateCrashReport(const ExecutorException& ex) {
        try {
            auto time = std::chrono::system_clock::to_time_t(ex.GetTimestamp());
            std::stringstream filename;
            filename << m_crashReportPath << "/crash_" 
                    << std::put_time(std::localtime(&time), "%Y%m%d_%H%M%S") 
                    << ".log";
                    
            std::string reportPath = filename.str();
            
            std::string report = "=== CRASH REPORT ===\n";
            report += ex.GetFormattedMessage();
            report += "\n\n=== RECENT ERRORS ===\n";
            
            {
                std::lock_guard<std::mutex> lock(s_mutex);
                int count = 0;
                for (auto it = m_errors.rbegin(); it != m_errors.rend() && count < 10; ++it, ++count) {
                    report += it->GetFormattedMessage() + "\n";
                }
            }
            
            // Add system information
            report += "\n=== SYSTEM INFORMATION ===\n";
            // Add relevant system information here
            
            // Write to file
            FileUtils::WriteFile(reportPath, report);
            
            // Log the crash report location
            Logging::LogCritical("ErrorManager", "Crash report written to: " + reportPath);
        } catch (...) {
            // Ignore exceptions during crash reporting
        }
    }
};

// Initialize static members
ErrorManager* ErrorManager::s_instance = nullptr;
std::mutex ErrorManager::s_mutex;

// Utility functions for error handling
inline void ThrowError(const ErrorCode& error, const std::string& details = "") {
    ExecutorException ex(error, details);
    ErrorManager::GetInstance().HandleError(error, details);
    throw ex;
}

inline void ReportError(const ErrorCode& error, const std::string& details = "") {
    ErrorManager::GetInstance().HandleError(error, details);
}

// Macro to check conditions and throw errors
#define CHECK_ERROR(condition, error, details) \
    do { \
        if (!(condition)) { \
            ThrowError(error, details); \
        } \
    } while (0)

// Macro to check for null pointers
#define CHECK_NULL(ptr, details) \
    CHECK_ERROR((ptr) != nullptr, ErrorCodes::NULL_POINTER, details)

// Macro to check if a file exists
#define CHECK_FILE_EXISTS(path, details) \
    CHECK_ERROR(FileUtils::Exists(path), ErrorCodes::FILE_NOT_FOUND, details)

// Macro for function entry and exit tracing in debug mode
#ifdef DEBUG_BUILD
#define TRACE_FUNCTION_ENTRY() \
    Logging::LogDebug(__FUNCTION__, "Entry")

#define TRACE_FUNCTION_EXIT() \
    Logging::LogDebug(__FUNCTION__, "Exit")

#define TRACE_FUNCTION() \
    struct FunctionTracer { \
        std::string funcName; \
        FunctionTracer(const char* name) : funcName(name) { \
            Logging::LogDebug(funcName, "Entry"); \
        } \
        ~FunctionTracer() { \
            Logging::LogDebug(funcName, "Exit"); \
        } \
    } functionTracer(__FUNCTION__)
#else
#define TRACE_FUNCTION_ENTRY()
#define TRACE_FUNCTION_EXIT()
#define TRACE_FUNCTION()
#endif

// Integrity check functions for anti-tamper protection
namespace IntegrityCheck {
    // Simple function to check memory integrity of a region
    bool CheckMemoryRegion(void* address, size_t size, uint32_t expectedChecksum) {
        if (!address || size == 0) return false;
        
        // Simple checksum calculation
        uint32_t checksum = 0;
        uint8_t* ptr = static_cast<uint8_t*>(address);
        
        for (size_t i = 0; i < size; ++i) {
            checksum = ((checksum << 5) + checksum) + ptr[i]; // Simple hash function
        }
        
        return checksum == expectedChecksum;
    }
    
    // Function to check file integrity
    bool CheckFileIntegrity(const std::string& filePath, uint32_t expectedChecksum) {
        if (!FileUtils::Exists(filePath)) return false;
        
        std::string content = FileUtils::ReadFile(filePath);
        if (content.empty()) return false;
        
        uint32_t checksum = 0;
        for (char c : content) {
            checksum = ((checksum << 5) + checksum) + static_cast<uint8_t>(c);
        }
        
        return checksum == expectedChecksum;
    }
    
    // Forward declaration of tamper detection function
    // Implementation moved to a separate source file to avoid system header conflicts
    bool CheckExecutableTampering();
}

// Initialize error handling
inline void InitializeErrorHandling() {
    // Set up the error manager
    auto& errorManager = ErrorManager::GetInstance();
    
    // Set up default error handlers
    errorManager.AddHandler([](const ExecutorException& ex) {
        // Example handler that logs to console
        // Using severity for critical/fatal errors which is the appropriate enum for this
        ErrorSeverity severity = ErrorSeverity::ERROR;  // Default to ERROR
        
        if (ex.GetErrorCode().category == ErrorCategory::MEMORY) {
            severity = ErrorSeverity::CRITICAL;  // Memory errors are critical
        }
        
        if (severity == ErrorSeverity::CRITICAL || severity == ErrorSeverity::FATAL) {
            std::cerr << "CRITICAL ERROR: " << ex.GetFormattedMessage() << std::endl;
        }
    });
    
    // Enable logging integration
    errorManager.EnableLogging(true);
    
    // Initialize the crash reporting
    std::string crashDir = FileUtils::GetLogPath() + "/crashes";
    FileUtils::EnsureDirectoryExists(crashDir);
    errorManager.SetCrashReportPath(crashDir);
    
    // Log initialization
    Logging::LogInfo("ErrorHandling", "Error handling system initialized");
}

} // namespace ErrorHandling
