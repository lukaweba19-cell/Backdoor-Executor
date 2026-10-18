#include "../objc_isolation.h"


#pragma once

#include <string>
#include <vector>
#include <functional>
#include <memory>
#include <mutex>
#include <atomic>
#include <unordered_map>
#include "ScriptManager.h"
#include "../filesystem_utils.h"

namespace iOS {
    /**
     * @class ExecutionEngine
     * @brief Engine for executing Lua scripts in the Roblox environment
     * 
     * This class provides functionality to execute Lua scripts in the Roblox
     * environment, with support for various execution options and callbacks.
     */
    class ExecutionEngine {
    public:
        // Execution context structure
        struct ExecutionContext {
            bool m_isJailbroken;                                // Whether the device is jailbroken
            bool m_enableObfuscation;                           // Whether to obfuscate the script
            bool m_enableAntiDetection;                         // Whether to use anti-detection measures
            bool m_autoRetry;                                   // Whether to automatically retry on failure
            int m_maxRetries;                                   // Maximum number of retries
            int m_timeout;                                      // Timeout in milliseconds (0 for no timeout)
            std::string m_gameName;                             // Name of the game
            std::string m_placeId;                              // Place ID of the game
            std::unordered_map<std::string, std::string> m_environment;   // Environment variables for the script
            bool m_enableNamingConventions;                     // Whether to enable naming conventions
            
            ExecutionContext()
                : m_isJailbroken(false),
                  m_enableObfuscation(true),
                  m_enableAntiDetection(true),
                  m_autoRetry(true),
                  m_maxRetries(3),
                  m_timeout(5000),
                  m_gameName(""),
                  m_placeId(""),
                  m_enableNamingConventions(true) {}
        };
        
        // Execution result structure
        struct ExecutionResult {
            bool m_success;                // Whether the execution succeeded
            std::string m_error;           // Error message if execution failed
            std::string m_output;          // Output from the script
            int64_t m_executionTime;       // Execution time in milliseconds
            
            ExecutionResult(bool success = false, const std::string& error = "", 
                      int64_t executionTime = 0, const std::string& output = "")
                : m_success(success), m_error(error), m_output(output), m_executionTime(executionTime) {}
        };
        
        // Callback types
        using BeforeExecuteCallback = std::function<bool(const std::string&, const ExecutionContext&)>;
        using AfterExecuteCallback = std::function<void(const std::string&, const ExecutionResult&)>;
        using OutputCallback = std::function<void(const std::string&)>;
        
        // Constructor
        ExecutionEngine(std::shared_ptr<ScriptManager> scriptManager = nullptr);
        
        // Initialize the execution engine
        bool Initialize();
        
        // Execute a script
        ExecutionResult Execute(const std::string& script, const ExecutionContext& context = ExecutionContext());
        
        // Execute a script by name from the script manager
        ExecutionResult ExecuteByName(const std::string& scriptName, const ExecutionContext& context = ExecutionContext());
        
        // Set the default execution context
        void SetDefaultContext(const ExecutionContext& context);
        
        // Get the default execution context
        ExecutionContext GetDefaultContext() const;
        
        // Register a callback to be called before script execution
        void RegisterBeforeExecuteCallback(const BeforeExecuteCallback& callback);
        
        // Register a callback to be called after script execution
        void RegisterAfterExecuteCallback(const AfterExecuteCallback& callback);
        
        // Set the output callback function
        void SetOutputCallback(const OutputCallback& callback);
        
        // Check if the engine is currently executing a script
        bool IsExecuting() const;
        
        // Set the script manager
        void SetScriptManager(std::shared_ptr<ScriptManager> scriptManager);
        
        // Get available bypass methods
        std::vector<std::string> GetAvailableBypassMethods() const;
        
        // Check if a specific bypass method is available
        bool IsMethodAvailable(const std::string& methodName) const;
        
    private:
        // Script manager
        std::shared_ptr<ScriptManager> m_scriptManager;
        
        // Default execution context
        ExecutionContext m_defaultContext;
        
        // Callbacks
        std::vector<BeforeExecuteCallback> m_beforeCallbacks;
        std::vector<AfterExecuteCallback> m_afterCallbacks;
        OutputCallback m_outputCallback;
        
        // Execution state
        std::mutex m_executionMutex;
        std::atomic<bool> m_isExecuting;
        int m_retryCount;
        
        // Detect if device is jailbroken
        static bool IsJailbroken();
        
        // Check jailbreak status
        bool CheckJailbreakStatus();
        
        // Obfuscate a script
        std::string ObfuscateScript(const std::string& script);
        
        // Prepare a script for execution
        std::string PrepareScript(const std::string& script, const ExecutionContext& context);
        
        // Process output from script execution
        void ProcessOutput(const std::string& output);
        
        // Setup the bypass environment based on device capabilities
        bool SetupBypassEnvironment(const ExecutionContext& context);
        
        // Log script execution
        void LogExecution(const std::string& script, const ExecutionResult& result);
        
        // Generate execution environment with variables and helper functions
        std::string GenerateExecutionEnvironment(const ExecutionContext& context);
        
        // Apply naming conventions to a script
        std::string ApplyNamingConventions(const std::string& script);
    };
}
