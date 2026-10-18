
#include "objc_isolation.h"
#pragma once

#include <string>
#include <vector>
#include <functional>
#include <unordered_map>
#include <memory>

namespace iOS {
namespace AdvancedBypass {

    /**
     * @class DynamicMessageDispatcher
     * @brief Uses Objective-C message dispatching for JIT-independent execution
     * 
     * This class leverages Objective-C's message passing system to create execution
     * contexts that operate outside anti-cheat scanning range. It works on non-jailbroken
     * devices without requiring JIT or special permissions.
     */
    class DynamicMessageDispatcher {
    public:
        // Execution result structure
        struct ExecutionResult {
            bool m_success;              // Execution succeeded
            std::string m_error;         // Error message if failed
            std::string m_output;        // Output captured from execution
            uint64_t m_executionTime;    // Execution time in milliseconds
            
            ExecutionResult()
                : m_success(false), m_executionTime(0) {}
                
            ExecutionResult(bool success, const std::string& error = "", 
                           const std::string& output = "", uint64_t time = 0)
                : m_success(success), m_error(error), 
                  m_output(output), m_executionTime(time) {}
        };
        
        // Execution channel enumeration
        enum class Channel {
            MainThread,       // Execute on main thread
            BackgroundThread, // Execute on background thread
            RunLoop,          // Execute within run loop
            TaskDeferred,     // Execute as deferred task
            AutomaticBest     // Automatically select best channel
        };
        
        // Callback for execution output
        using OutputCallback = std::function<void(const std::string&)>;
        
    private:
        // Member variables with consistent m_ prefix
        Channel m_channel;                    // Current execution channel
        bool m_isInitialized;                 // Whether dispatcher is initialized
        OutputCallback m_outputCallback;      // Callback for execution output
        void* m_dispatcherObject;             // Opaque pointer to dispatcher object
        void* m_runLoopSource;                // Opaque pointer to run loop source
        void* m_dispatchQueue;                // Opaque pointer to dispatch queue
        std::string m_executionOutput;        // Captured execution output
        std::unordered_map<std::string, void*> m_proxyObjects; // Objective-C proxy objects
        
        // Private methods
        bool SetupMainThreadChannel();
        bool SetupBackgroundThreadChannel();
        bool SetupRunLoopChannel();
        bool SetupTaskDeferredChannel();
        void ProcessOutput(const std::string& output);
        Channel DetermineOptimalChannel();
        bool ExecuteViaChannel(const std::string& script, Channel channel);
        std::string PrepareScript(const std::string& script);
        std::string CreateLuaEnvironment();
        void* CreateDispatcherProxy();
        bool ConfigureRunLoopSource();
        
    public:
        /**
         * @brief Constructor
         * @param channel Execution channel to use
         */
        DynamicMessageDispatcher(Channel channel = Channel::AutomaticBest);
        
        /**
         * @brief Destructor
         */
        ~DynamicMessageDispatcher();
        
        /**
         * @brief Initialize the message dispatcher
         * @return True if initialization succeeded, false otherwise
         */
        bool Initialize();
        
        /**
         * @brief Execute a Lua script using message dispatching
         * @param script Lua script to execute
         * @return Execution result
         */
        ExecutionResult Execute(const std::string& script);
        
        /**
         * @brief Change the execution channel
         * @param channel New channel to use
         * @return True if channel was changed, false otherwise
         */
        bool SetChannel(Channel channel);
        
        /**
         * @brief Get the current execution channel
         * @return Current channel
         */
        Channel GetChannel() const;
        
        /**
         * @brief Set output callback
         * @param callback Callback function
         */
        void SetOutputCallback(const OutputCallback& callback);
        
        /**
         * @brief Check if dynamic message dispatching is available
         * @return True if available, false otherwise
         */
        static bool IsAvailable();
 
        /**
         * @brief Execute a script using dynamic message dispatch
         * @param script Lua script to execute
         * @return Output from script execution
         */
        std::string ExecuteScript(const std::string& script);
        
        /**
         * @brief Get a list of available channels
         * @return Vector of available channels
         */
        static std::vector<Channel> GetAvailableChannels();
        
        /**
         * @brief Convert channel enum to string
         * @param channel Channel to convert
         * @return String representation of channel
         */
        static std::string ChannelToString(Channel channel);
        
        /**
         * @brief Get a description of a channel
         * @param channel Channel to describe
         * @return Description of the channel
         */
        static std::string GetChannelDescription(Channel channel);
    };

} // namespace AdvancedBypass
} // namespace iOS
