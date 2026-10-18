
#include "../../objc_isolation.h"
#pragma once

#include <string>
#include <memory>
#include <functional>
#include <vector>
#include <unordered_map>
#include "WebKitExploit.h"
#include "MethodSwizzlingExploit.h"
#include "DynamicMessageDispatcher.h"
#include "LoadstringSupport.h"

namespace iOS {
namespace AdvancedBypass {

    /**
     * @class ExecutionIntegration
     * @brief Integrates all execution methods with loadstring support
     * 
     * This class provides a unified interface for script execution across all
     * advanced bypass methods. It automatically selects the best execution method
     * based on device capabilities and ensures consistent loadstring functionality.
     */
    class ExecutionIntegration {
    public:
        // Execution result structure
        struct ExecutionResult {
            bool m_success;              // Execution succeeded
            std::string m_error;         // Error message if failed
            std::string m_output;        // Output captured from execution
            uint64_t m_executionTime;    // Execution time in milliseconds
            std::string m_methodUsed;    // Execution method that was used
            
            ExecutionResult()
                : m_success(false), m_executionTime(0) {}
                
            ExecutionResult(bool success, const std::string& error = "", 
                           const std::string& output = "", uint64_t time = 0,
                           const std::string& method = "")
                : m_success(success), m_error(error), m_output(output),
                  m_executionTime(time), m_methodUsed(method) {}
        };
        
        // Execution method enumeration
        enum class Method {
            WebKit,               // WebKit process execution
            MethodSwizzling,      // Method swizzling execution
            DynamicMessage,       // Dynamic message dispatch
            AutoSelect,           // Automatically select best method
            FallbackChain         // Try all methods in succession
        };
        
        // Callback for execution output
        using OutputCallback = std::function<void(const std::string&)>;
        
    private:
        // Member variables with consistent m_ prefix
        Method m_primaryMethod;                // Primary execution method
        std::shared_ptr<WebKitExploit> m_webKit;                  // WebKit exploit instance
        std::shared_ptr<MethodSwizzlingExploit> m_methodSwizzling; // Method swizzling exploit instance
        std::shared_ptr<DynamicMessageDispatcher> m_dynamicMessage; // Dynamic message dispatcher instance
        std::shared_ptr<LoadstringSupport> m_loadstring;           // Loadstring support instance
        OutputCallback m_outputCallback;        // Callback for execution output
        bool m_loadstringInjected;              // Whether loadstring has been injected
        std::vector<Method> m_fallbackChain;    // Chain of methods to try
        std::unordered_map<std::string, std::string> m_scriptCache; // Cache of script results
        
        // Private methods
        bool InitializeMethod(Method method);
        ExecutionResult ExecuteWithMethod(const std::string& script, Method method);
        Method DetermineBestMethod();
        std::string InjectLoadstringSupport(const std::string& script);
        void ProcessOutput(const std::string& output);
        
    public:
        /**
         * @brief Constructor
         * @param method Primary execution method
         */
        ExecutionIntegration(Method method = Method::AutoSelect);
        
        /**
         * @brief Destructor
         */
        ~ExecutionIntegration();
        
        /**
         * @brief Initialize the execution integration
         * @return True if initialization succeeded, false otherwise
         */
        bool Initialize();
        
        /**
         * @brief Execute a script
         * @param script Script to execute
         * @return Execution result
         */
        ExecutionResult Execute(const std::string& script);
        
        /**
         * @brief Execute using loadstring
         * @param script Script to execute via loadstring
         * @param chunkName Optional chunk name for error reporting
         * @return Execution result
         */
        ExecutionResult ExecuteWithLoadstring(const std::string& script, const std::string& chunkName = "");
        
        /**
         * @brief Set the primary execution method
         * @param method Method to use
         * @return True if method was set, false otherwise
         */
        bool SetMethod(Method method);
        
        /**
         * @brief Get the primary execution method
         * @return Current primary method
         */
        Method GetMethod() const;
        
        /**
         * @brief Set output callback
         * @param callback Callback function
         */
        void SetOutputCallback(const OutputCallback& callback);
        
        /**
         * @brief Configure fallback chain
         * @param methods Vector of methods to try in order
         */
        void SetFallbackChain(const std::vector<Method>& methods);
        
        /**
         * @brief Get the current fallback chain
         * @return Vector of methods in the fallback chain
         */
        std::vector<Method> GetFallbackChain() const;
        
        /**
         * @brief Clear script cache
         */
        void ClearCache();
        
        /**
         * @brief Check if a method is available
         * @param method Method to check
         * @return True if available, false otherwise
         */
        bool IsMethodAvailable(Method method) const;
        
        /**
         * @brief Get all available methods
         * @return Vector of available methods
         */
        std::vector<Method> GetAvailableMethods() const;
        
        /**
         * @brief Convert method enum to string
         * @param method Method to convert
         * @return String representation of method
         */
        static std::string MethodToString(Method method);
        
        /**
         * @brief Get a description of a method
         * @param method Method to describe
         * @return Description of the method
         */
        static std::string GetMethodDescription(Method method);
    };

} // namespace AdvancedBypass
} // namespace iOS
