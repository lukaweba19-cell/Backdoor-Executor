#pragma once

// Standard C++ includes
#include <string>
#include <vector>
#include <functional>
#include <memory>
#include <mutex>
#include <atomic>
#include <unordered_map>

// Forward declare lua_State to avoid dependency issues
struct lua_State;

#include "../logging.hpp"

namespace iOS {
    /**
     * @class LuaInterpreterIntegration
     * @brief Integrates the Lua interpreter with the iOS executor
     * 
     * This class provides the connection between the interpreter.lua in the project root
     * and the iOS execution engine, enabling full script execution capabilities.
     */
    class LuaInterpreterIntegration {
    public:
        // Script execution result
        struct ExecutionResult {
            bool success;
            std::string error;
            std::string output;
            int returnCount;
            std::vector<std::string> returnValues;
            
            ExecutionResult() : success(false), returnCount(0) {}
        };
        
        // Script execution options
        struct ExecutionOptions {
            bool useSandbox;
            bool captureOutput;
            bool usePreprocessor;
            std::unordered_map<std::string, std::string> environment;
            
            ExecutionOptions() 
                : useSandbox(true), 
                  captureOutput(true),
                  usePreprocessor(true) {}
        };
        
        // Output callback type
        using OutputCallback = std::function<void(const std::string&)>;
        
        // Error callback type
        using ErrorCallback = std::function<void(const std::string&)>;
        
        // Singleton instance accessor
        static LuaInterpreterIntegration& GetInstance();
        
        // Initialize the interpreter
        bool Initialize();
        
        // Shutdown and cleanup
        void Shutdown();
        
        // Execute Lua script with options
        ExecutionResult ExecuteScript(const std::string& script, const ExecutionOptions& options = ExecutionOptions());
        
        // Load the interpreter.lua script from root
        bool LoadInterpreterScript();
        
        // Register an output callback
        void RegisterOutputCallback(OutputCallback callback);
        
        // Register an error callback
        void RegisterErrorCallback(ErrorCallback callback);
        
        // Check if initialized
        bool IsInitialized() const { return m_initialized; }
        
    private:
        // Private constructor for singleton
        LuaInterpreterIntegration();
        
        // No copying allowed
        LuaInterpreterIntegration(const LuaInterpreterIntegration&) = delete;
        LuaInterpreterIntegration& operator=(const LuaInterpreterIntegration&) = delete;
        
        // Create the Lua state
        lua_State* CreateState();
        
        // Load the interpreter.lua file
        bool LoadInterpreterFile(lua_State* L);
        
        // Setup execution environment
        bool SetupEnvironment(lua_State* L, const ExecutionOptions& options);
        
        // Setup sandboxing
        bool SetupSandbox(lua_State* L);
        
        // Setup output capture
        bool SetupOutputCapture(lua_State* L);
        
        // Helper function for Lua error handling
        std::string GetLuaError(lua_State* L);
        
        // Generate a sandbox environment
        void GenerateSandbox(lua_State* L);
        
        // Internal state
        std::atomic<bool> m_initialized;
        lua_State* m_luaState;
        
        // Mutex for thread safety
        mutable std::mutex m_mutex;
        
        // Callbacks
        std::vector<OutputCallback> m_outputCallbacks;
        std::vector<ErrorCallback> m_errorCallbacks;
        
        // Cached interpreter script content
        std::string m_interpreterScript;
        
        // Static callback for Lua print function
        static int LuaPrintFunction(lua_State* L);
        
        // Static callback for Lua error function
        static int LuaErrorFunction(lua_State* L);
    };
}
