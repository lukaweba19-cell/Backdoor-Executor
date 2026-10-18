// logging.hpp - Production-grade logging system for iOS executor
#pragma once

#include <string>
#include <sstream>
#include <iostream>
#include <fstream>
#include <vector>
#include <mutex>
#include <ctime>
#include <iomanip>
#include <memory>
#include <chrono>
#include "filesystem_utils.h"

namespace Logging {

// Log severity levels
enum class LogLevel {
    DEBUG,
    INFO,
    WARNING,
    ERROR,
    CRITICAL
};

// Convert LogLevel to string
inline std::string LogLevelToString(LogLevel level) {
    switch (level) {
        case LogLevel::DEBUG:    return "DEBUG";
        case LogLevel::INFO:     return "INFO";
        case LogLevel::WARNING:  return "WARNING";
        case LogLevel::ERROR:    return "ERROR";
        case LogLevel::CRITICAL: return "CRITICAL";
        default:                 return "UNKNOWN";
    }
}

// Log message structure
struct LogMessage {
    LogLevel level;
    std::string category;
    std::string message;
    std::chrono::system_clock::time_point timestamp;
    
    // Create a formatted timestamp string
    std::string FormattedTimestamp() const {
        auto time_t_value = std::chrono::system_clock::to_time_t(timestamp);
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            timestamp.time_since_epoch()).count() % 1000;
            
        std::stringstream ss;
        ss << std::put_time(std::localtime(&time_t_value), "%Y-%m-%d %H:%M:%S");
        ss << '.' << std::setfill('0') << std::setw(3) << ms;
        return ss.str();
    }
    
    // Format the log message
    std::string Format() const {
        std::stringstream ss;
        ss << FormattedTimestamp() << " [" << LogLevelToString(level) << "] ";
        if (!category.empty()) {
            ss << category << ": ";
        }
        ss << message;
        return ss.str();
    }
};

// Forward declaration of Logger class
class Logger;

// Log sink interface
class LogSink {
public:
    virtual ~LogSink() = default;
    virtual void Log(const LogMessage& message) = 0;
};

// Console log sink
class ConsoleSink : public LogSink {
public:
    void Log(const LogMessage& message) override {
        std::string formattedMessage = message.Format();
        if (message.level >= LogLevel::ERROR) {
            std::cerr << formattedMessage << std::endl;
        } else {
            std::cout << formattedMessage << std::endl;
        }
    }
};

// File log sink
class FileSink : public LogSink {
private:
    std::string m_filePath;
    std::ofstream m_outFile;
    mutable std::mutex m_mutex;
    
public:
    FileSink(const std::string& filePath) : m_filePath(filePath) {
        // Ensure directory exists
        std::string dirPath = FileUtils::GetDirectoryName(filePath);
        if (!dirPath.empty()) {
            FileUtils::EnsureDirectoryExists(dirPath);
        }
        
        // Open the file
        m_outFile.open(filePath, std::ios::app);
        
        // Write a separator on startup
        if (m_outFile.is_open()) {
            std::time_t now = std::time(nullptr);
            m_outFile << "\n==== Log started at " << std::put_time(std::localtime(&now), "%Y-%m-%d %H:%M:%S") << " ====\n\n";
            m_outFile.flush();
        }
    }
    
    ~FileSink() {
        if (m_outFile.is_open()) {
            m_outFile.close();
        }
    }
    
    void Log(const LogMessage& message) override {
        if (!m_outFile.is_open()) {
            return;
        }
        
        std::lock_guard<std::mutex> lock(m_mutex);
        m_outFile << message.Format() << std::endl;
        m_outFile.flush();
    }
};

// In-memory circular buffer sink for recent logs
class MemorySink : public LogSink {
private:
    std::vector<LogMessage> m_buffer;
    size_t m_capacity;
    mutable std::mutex m_mutex;
    
public:
    MemorySink(size_t capacity = 1000) : m_capacity(capacity) {
        m_buffer.reserve(capacity);
    }
    
    void Log(const LogMessage& message) override {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        if (m_buffer.size() >= m_capacity) {
            m_buffer.erase(m_buffer.begin());
        }
        
        m_buffer.push_back(message);
    }
    
    std::vector<LogMessage> GetMessages() const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_buffer;
    }
    
    void Clear() {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_buffer.clear();
    }
};

// Main logger class
class Logger {
private:
    LogLevel m_minLevel;
    std::vector<std::shared_ptr<LogSink>> m_sinks;
    mutable std::mutex m_mutex;
    
    // Singleton instance
    static std::unique_ptr<Logger> s_instance;
    static std::mutex s_instanceMutex;
    
    // Private constructor for singleton
    Logger() : m_minLevel(LogLevel::INFO) {}
    
public:
    // Get the singleton instance
    static Logger& GetInstance() {
        std::lock_guard<std::mutex> lock(s_instanceMutex);
        if (!s_instance) {
            s_instance = std::unique_ptr<Logger>(new Logger());
            
            // Add default console sink
            s_instance->AddSink(std::make_shared<ConsoleSink>());
        }
        
        return *s_instance;
    }
    
    // Delete the copy constructor and assignment operator
    Logger(const Logger&) = delete;
    Logger& operator=(const Logger&) = delete;
    
    // Set the minimum log level
    void SetMinLevel(LogLevel level) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_minLevel = level;
    }
    
    // Get the minimum log level
    LogLevel GetMinLevel() const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_minLevel;
    }
    
    // Add a sink
    void AddSink(std::shared_ptr<LogSink> sink) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_sinks.push_back(sink);
    }
    
    // Clear all sinks
    void ClearSinks() {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_sinks.clear();
    }
    
    // Log a message
    void Log(LogLevel level, const std::string& category, const std::string& message) {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        if (level < m_minLevel) {
            return;
        }
        
        LogMessage logMessage{
            level,
            category,
            message,
            std::chrono::system_clock::now()
        };
        
        for (auto& sink : m_sinks) {
            sink->Log(logMessage);
        }
    }
    
    // Convenience methods for each log level
    void Debug(const std::string& category, const std::string& message) {
        Log(LogLevel::DEBUG, category, message);
    }
    
    void Info(const std::string& category, const std::string& message) {
        Log(LogLevel::INFO, category, message);
    }
    
    void Warning(const std::string& category, const std::string& message) {
        Log(LogLevel::WARNING, category, message);
    }
    
    void Error(const std::string& category, const std::string& message) {
        Log(LogLevel::ERROR, category, message);
    }
    
    void Critical(const std::string& category, const std::string& message) {
        Log(LogLevel::CRITICAL, category, message);
    }
    
    // Initialize with file logging
    static void InitializeWithFileLogging(const std::string& logDir = "") {
        auto& logger = GetInstance();
        
        // Determine log file path
        std::string logPath;
        if (logDir.empty()) {
            logPath = FileUtils::GetLogPath();
        } else {
            logPath = logDir;
        }
        
        // Create file name with timestamp
        auto now = std::chrono::system_clock::now();
        auto time_t_now = std::chrono::system_clock::to_time_t(now);
        std::stringstream ss;
        ss << "executor_" << std::put_time(std::localtime(&time_t_now), "%Y%m%d_%H%M%S") << ".log";
        
        std::string filePath = FileUtils::JoinPaths(logPath, ss.str());
        
        // Add file sink
        logger.AddSink(std::make_shared<FileSink>(filePath));
        
        // Log initialization
        logger.Info("System", "Logging initialized with file: " + filePath);
    }
};

// Static members defined in logging.cpp

// Convenience global functions
inline void LogDebug(const std::string& category, const std::string& message) {
    Logger::GetInstance().Debug(category, message);
}

inline void LogInfo(const std::string& category, const std::string& message) {
    Logger::GetInstance().Info(category, message);
}

inline void LogWarning(const std::string& category, const std::string& message) {
    Logger::GetInstance().Warning(category, message);
}

inline void LogError(const std::string& category, const std::string& message) {
    Logger::GetInstance().Error(category, message);
}

inline void LogCritical(const std::string& category, const std::string& message) {
    Logger::GetInstance().Critical(category, message);
}

// Macro for easy function entry/exit logging (use at beginning of function)
#define LOG_FUNCTION_ENTRY() \
    LogDebug(__FUNCTION__, "Entry")

// Macro for easy function exit logging (use before return)
#define LOG_FUNCTION_EXIT() \
    LogDebug(__FUNCTION__, "Exit")

// Macro for easy error logging with error code
#define LOG_ERROR_CODE(category, message, code) \
    LogError(category, message + " (Error code: " + std::to_string(code) + ")")

// Macro for easy exception logging
#define LOG_EXCEPTION(category, e) \
    LogError(category, "Exception: " + std::string(e.what()))

} // namespace Logging
