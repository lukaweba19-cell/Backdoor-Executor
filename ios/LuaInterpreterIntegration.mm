#include "LuaInterpreterIntegration.h"
#include "advanced_bypass/HttpClient.h"
#include "anti_tamper.hpp"
#include "anti_detection/anti_debug.hpp"
#include "naming_conventions/script_preprocessor.h"
#include "TeleportControl.h"
#include "PresenceSystem.h"

#include <fstream>
#include <sstream>
#include <thread>
#include <chrono>
#include <algorithm>
#include <filesystem>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>

// Required Objective-C imports
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

namespace iOS {
    // Static instance for singleton
    static LuaInterpreterIntegration* s_instance = nullptr;
    
    // Static wrapper for output callbacks
    static LuaInterpreterIntegration* s_outputInstance = nullptr;
    
    // Static function for Lua print
    int LuaInterpreterIntegration::LuaPrintFunction(lua_State* L) {
        if (!s_outputInstance) {
            return 0;
        }
        
        int n = lua_gettop(L);
        std::string output;
        
        for (int i = 1; i <= n; i++) {
            if (i > 1) {
                output += "\t";
            }
            
            if (lua_isstring(L, i)) {
                output += lua_tostring(L, i);
            } else if (lua_isnil(L, i)) {
                output += "nil";
            } else if (lua_isboolean(L, i)) {
                output += lua_toboolean(L, i) ? "true" : "false";
            } else if (lua_isnumber(L, i)) {
                output += std::to_string(lua_tonumber(L, i));
            } else {
                output += luaL_typename(L, i);
            }
        }
        
        // Notify all registered callbacks
        std::vector<OutputCallback> callbacks;
        {
            std::lock_guard<std::mutex> lock(s_outputInstance->m_mutex);
            callbacks = s_outputInstance->m_outputCallbacks;
        }
        
        for (const auto& callback : callbacks) {
            callback(output);
        }
        
        // Also log the output
        Logging::LogInfo("LuaInterpreter", "Script output: " + output);
        
        return 0;
    }
    
    // Static function for Lua error handling
    int LuaInterpreterIntegration::LuaErrorFunction(lua_State* L) {
        if (!s_outputInstance) {
            return lua_error(L); // Default error behavior
        }
        
        // Get error message
        std::string errorMsg = "Error: ";
        if (lua_isstring(L, -1)) {
            errorMsg += lua_tostring(L, -1);
        } else {
            errorMsg += "Unknown error occurred";
        }
        
        // Notify all registered callbacks
        std::vector<ErrorCallback> callbacks;
        {
            std::lock_guard<std::mutex> lock(s_outputInstance->m_mutex);
            callbacks = s_outputInstance->m_errorCallbacks;
        }
        
        for (const auto& callback : callbacks) {
            callback(errorMsg);
        }
        
        // Also log the error
        Logging::LogError("LuaInterpreter", errorMsg);
        
        // Re-raise the error for Lua to handle
        return lua_error(L);
    }
    
    // LuaInterpreterIntegration implementation
    LuaInterpreterIntegration& LuaInterpreterIntegration::GetInstance() {
        if (!s_instance) {
            s_instance = new LuaInterpreterIntegration();
            s_outputInstance = s_instance; // For static callback access
        }
        return *s_instance;
    }
    
    LuaInterpreterIntegration::LuaInterpreterIntegration() 
        : m_initialized(false), m_luaState(nullptr) {
    }
    
    bool LuaInterpreterIntegration::Initialize() {
        if (m_initialized) {
            return true;
        }
        
        Logging::LogInfo("LuaInterpreter", "Initializing Lua interpreter integration");
        
        // Apply anti-debugging measures
        AntiDetection::AntiDebug::ApplyAntiTamperingMeasures();
        
        // Create Lua state
        m_luaState = CreateState();
        if (!m_luaState) {
            Logging::LogError("LuaInterpreter", "Failed to create Lua state");
            return false;
        }
        
        // Load the interpreter script
        if (!LoadInterpreterScript()) {
            Logging::LogError("LuaInterpreter", "Failed to load interpreter script");
            lua_close(m_luaState);
            m_luaState = nullptr;
            return false;
        }
        
        m_initialized = true;
        Logging::LogInfo("LuaInterpreter", "Lua interpreter integration initialized successfully");
        
        return true;
    }
    
    void LuaInterpreterIntegration::Shutdown() {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        if (m_luaState) {
            lua_close(m_luaState);
            m_luaState = nullptr;
        }
        
        m_initialized = false;
        
        Logging::LogInfo("LuaInterpreter", "Lua interpreter integration shutdown");
    }
    
    LuaInterpreterIntegration::ExecutionResult LuaInterpreterIntegration::ExecuteScript(
        const std::string& script, const ExecutionOptions& options) {
        
        ExecutionResult result;
        
        if (!m_initialized || !m_luaState) {
            result.error = "Lua interpreter not initialized";
            return result;
        }
        
        // Create a new thread for execution to isolate it
        lua_State* L = lua_newthread(m_luaState);
        if (!L) {
            result.error = "Failed to create Lua thread";
            return result;
        }
        
        try {
            // Process script with naming conventions if enabled
            std::string processedScript = script;
            if (options.usePreprocessor) {
                auto& preprocessor = RobloxExecutor::NamingConventions::ScriptPreprocessor::GetInstance();
                if (preprocessor.Initialize()) {
                    processedScript = preprocessor.PreprocessScript(script);
                }
            }
            
            // Setup environment based on options
            SetupEnvironment(L, options);
            
            // Setup sandbox if enabled
            if (options.useSandbox) {
                SetupSandbox(L);
            }
            
            // Setup output capture if enabled
            if (options.captureOutput) {
                SetupOutputCapture(L);
            }
            
            // Load the processed script
            int loadStatus = luaL_loadstring(L, processedScript.c_str());
            if (loadStatus != 0) {
                result.error = "Failed to load script: " + GetLuaError(L);
                lua_pop(m_luaState, 1); // Remove thread
                return result;
            }
            
            // Execute the script
            int execStatus = lua_pcall(L, 0, LUA_MULTRET, 0);
            if (execStatus != 0) {
                result.error = "Failed to execute script: " + GetLuaError(L);
                lua_pop(m_luaState, 1); // Remove thread
                return result;
            }
            
            // Collect return values
            int returnCount = lua_gettop(L);
            result.returnCount = returnCount;
            
            for (int i = 1; i <= returnCount; i++) {
                if (lua_isstring(L, i)) {
                    result.returnValues.push_back(lua_tostring(L, i));
                } else if (lua_isnil(L, i)) {
                    result.returnValues.push_back("nil");
                } else if (lua_isboolean(L, i)) {
                    result.returnValues.push_back(lua_toboolean(L, i) ? "true" : "false");
                } else if (lua_isnumber(L, i)) {
                    result.returnValues.push_back(std::to_string(lua_tonumber(L, i)));
                } else {
                    result.returnValues.push_back(luaL_typename(L, i));
                }
            }
            
            result.success = true;
            
            // Remove thread
            lua_pop(m_luaState, 1);
        }
        catch (const std::exception& e) {
            result.error = "Exception during execution: " + std::string(e.what());
            lua_pop(m_luaState, 1); // Remove thread
        }
        
        return result;
    }
    
    bool LuaInterpreterIntegration::LoadInterpreterScript() {
        if (m_interpreterScript.empty()) {
            // Try to load the interpreter.lua from various locations
            std::vector<std::string> possiblePaths = {
                "interpreter.lua",                    // Root
                "../interpreter.lua",                 // One level up
                "../../interpreter.lua",              // Two levels up
                "../../../interpreter.lua",           // Three levels up
                "/var/mobile/interpreter.lua",        // Common iOS path
                "/var/mobile/Documents/interpreter.lua", // Documents folder
                "./interpreter.lua"                   // Current directory
            };
            
            // Get the app bundle path
            NSBundle* mainBundle = [NSBundle mainBundle];
            NSString* bundlePath = [mainBundle bundlePath];
            if (bundlePath) {
                NSString* interpreterPath = [bundlePath stringByAppendingPathComponent:@"interpreter.lua"];
                possiblePaths.push_back([interpreterPath UTF8String]);
            }
            
            // Try each path
            for (const auto& path : possiblePaths) {
                std::ifstream file(path);
                if (file.is_open()) {
                    std::stringstream buffer;
                    buffer << file.rdbuf();
                    m_interpreterScript = buffer.str();
                    
                    Logging::LogInfo("LuaInterpreter", "Loaded interpreter.lua from: " + path);
                    break;
                }
            }
            
            // If still empty, look within embedded resources
            if (m_interpreterScript.empty()) {
                NSString* interpreterPath = [mainBundle pathForResource:@"interpreter" ofType:@"lua"];
                if (interpreterPath) {
                    NSError* error = nil;
                    NSString* content = [NSString stringWithContentsOfFile:interpreterPath 
                                                   encoding:NSUTF8StringEncoding 
                                                      error:&error];
                    if (content && !error) {
                        m_interpreterScript = [content UTF8String];
                        Logging::LogInfo("LuaInterpreter", "Loaded interpreter.lua from resources");
                    }
                }
            }
            
            // Last resort - load from embedded string if we have it
            if (m_interpreterScript.empty()) {
                // We'd need a fallback interpreter script embedded in the code
                // but it's better to bundle the actual interpreter.lua file
                Logging::LogError("LuaInterpreter", "Failed to load interpreter.lua from any location");
                return false;
            }
        }
        
        // Load the script into Lua
        return LoadInterpreterFile(m_luaState);
    }
    
    void LuaInterpreterIntegration::RegisterOutputCallback(OutputCallback callback) {
        if (!callback) {
            return;
        }
        
        std::lock_guard<std::mutex> lock(m_mutex);
        m_outputCallbacks.push_back(callback);
    }
    
    void LuaInterpreterIntegration::RegisterErrorCallback(ErrorCallback callback) {
        if (!callback) {
            return;
        }
        
        std::lock_guard<std::mutex> lock(m_mutex);
        m_errorCallbacks.push_back(callback);
    }
    
    lua_State* LuaInterpreterIntegration::CreateState() {
        // Create a new Lua state
        lua_State* L = luaL_newstate();
        if (!L) {
            return nullptr;
        }
        
        // Open standard libraries
        luaL_openlibs(L);
        
        // Register our custom print function
        lua_pushcfunction(L, LuaPrintFunction);
        lua_setglobal(L, "print");
        
        // Register error function in debug module
        lua_getglobal(L, "debug");
        if (lua_istable(L, -1)) {
            lua_pushcfunction(L, LuaErrorFunction);
            lua_setfield(L, -2, "traceback");
        }
        lua_pop(L, 1); // Pop debug table
        
        // Initialize special iOS-specific features
        
        // 1. Add TeleportControl API
        lua_newtable(L);
        
        // TeleportControl.setEnabled(enabled)
        lua_pushcfunction(L, [](lua_State* L) -> int {
            if (lua_gettop(L) >= 1 && lua_isboolean(L, 1)) {
                bool enabled = lua_toboolean(L, 1);
                
                // Get current mode
                auto mode = TeleportControl::GetInstance().GetControlMode();
                
                // Set new mode based on enabled flag
                TeleportControl::GetInstance().SetControlMode(
                    enabled ? mode : TeleportControl::ControlMode::AllowAll);
                
                Logging::LogInfo("LuaInterpreter", std::string("TeleportControl ") + 
                              (enabled ? "enabled" : "disabled"));
            }
            return 0;
        });
        lua_setfield(L, -2, "setEnabled");
        
        // TeleportControl.setMode(mode)
        lua_pushcfunction(L, [](lua_State* L) -> int {
            if (lua_gettop(L) >= 1 && lua_isnumber(L, 1)) {
                int mode = (int)lua_tonumber(L, 1);
                
                // Valid modes: 0=AllowAll, 1=BlockAll, 2=PromptUser, 3=CustomRules
                if (mode >= 0 && mode <= 3) {
                    TeleportControl::GetInstance().SetControlMode(
                        static_cast<TeleportControl::ControlMode>(mode));
                    
                    Logging::LogInfo("LuaInterpreter", "TeleportControl mode set to: " + std::to_string(mode));
                }
            }
            return 0;
        });
        lua_setfield(L, -2, "setMode");
        
        // TeleportControl.setCustomRule(type, allow)
        lua_pushcfunction(L, [](lua_State* L) -> int {
            if (lua_gettop(L) >= 2 && lua_isnumber(L, 1) && lua_isboolean(L, 2)) {
                int type = (int)lua_tonumber(L, 1);
                bool allow = lua_toboolean(L, 2);
                
                // Valid types: 0-5 corresponding to TeleportType enum
                if (type >= 0 && type <= 5) {
                    TeleportControl::GetInstance().SetCustomRule(
                        static_cast<TeleportControl::TeleportType>(type), allow);
                    
                    Logging::LogInfo("LuaInterpreter", "TeleportControl rule set for type " + 
                                    std::to_string(type) + ": " + (allow ? "Allow" : "Block"));
                }
            }
            return 0;
        });
        lua_setfield(L, -2, "setCustomRule");
        
        // Set the TeleportControl table as global
        lua_setglobal(L, "TeleportControl");
        
        // 2. Add PresenceSystem API
        lua_newtable(L);
        
        // PresenceSystem.setEnabled(enabled)
        lua_pushcfunction(L, [](lua_State* L) -> int {
            if (lua_gettop(L) >= 1 && lua_isboolean(L, 1)) {
                bool enabled = lua_toboolean(L, 1);
                PresenceSystem::GetInstance().SetEnabled(enabled);
                
                Logging::LogInfo("LuaInterpreter", std::string("PresenceSystem ") + 
                              (enabled ? "enabled" : "disabled"));
            }
            return 0;
        });
        lua_setfield(L, -2, "setEnabled");
        
        // PresenceSystem.getExecutorUsers()
        lua_pushcfunction(L, [](lua_State* L) -> int {
            // Get all executor users
            auto users = PresenceSystem::GetInstance().GetExecutorUsers();
            
            // Create a table to return
            lua_newtable(L);
            
            // Fill the table with user info
            for (size_t i = 0; i < users.size(); i++) {
                lua_newtable(L);
                
                lua_pushstring(L, users[i].userId.c_str());
                lua_setfield(L, -2, "userId");
                
                lua_pushstring(L, users[i].username.c_str());
                lua_setfield(L, -2, "username");
                
                lua_pushstring(L, users[i].displayName.c_str());
                lua_setfield(L, -2, "displayName");
                
                lua_pushboolean(L, users[i].isExecutorUser);
                lua_setfield(L, -2, "isExecutorUser");
                
                // Set this user info table at index i+1
                lua_rawseti(L, -2, i + 1);
            }
            
            return 1; // Return the table
        });
        lua_setfield(L, -2, "getExecutorUsers");
        
        // PresenceSystem.refreshPresence()
        lua_pushcfunction(L, [](lua_State* L) -> int {
            PresenceSystem::GetInstance().RefreshPresence();
            return 0;
        });
        lua_setfield(L, -2, "refreshPresence");
        
        // Set the PresenceSystem table as global
        lua_setglobal(L, "PresenceSystem");

        // Native HTTP via AdvancedBypass::HttpClient
        {
            static std::shared_ptr<iOS::AdvancedBypass::HttpClient> s_http;
            if (!s_http) {
                s_http = std::make_shared<iOS::AdvancedBypass::HttpClient>();
                s_http->Initialize();
            }
            lua_pushcfunction(L, [](lua_State* L) -> int {
                const char* url = luaL_checkstring(L, 1);
                static std::shared_ptr<iOS::AdvancedBypass::HttpClient> client;
                if (!client) {
                    client = std::make_shared<iOS::AdvancedBypass::HttpClient>();
                    client->Initialize();
                }
                auto result = client->Get(url ? url : "");
                if (!result.m_success) {
                    lua_pushnil(L);
                    lua_pushstring(L, result.m_error.c_str());
                    return 2;
                }
                lua_pushstring(L, result.m_content.c_str());
                return 1;
            });
            lua_setglobal(L, "__nativeHttpGet");

            lua_pushcfunction(L, [](lua_State* L) -> int {
                const char* url = luaL_checkstring(L, 1);
                const char* body = luaL_optstring(L, 2, "");
                static std::shared_ptr<iOS::AdvancedBypass::HttpClient> client;
                if (!client) {
                    client = std::make_shared<iOS::AdvancedBypass::HttpClient>();
                    client->Initialize();
                }
                auto result = client->Post(url ? url : "", body ? body : "");
                if (!result.m_success) {
                    lua_pushnil(L);
                    lua_pushstring(L, result.m_error.c_str());
                    return 2;
                }
                lua_pushstring(L, result.m_content.c_str());
                return 1;
            });
            lua_setglobal(L, "__nativeHttpPost");

            // Convenience game.HttpGet-style helpers
            const char* bootstrap =
                "function _httpGet(url, cache) local r,e = __nativeHttpGet(url); if not r then error(e or 'HttpGet failed') end; return r end\n"
                "function game_HttpGet(url) return _httpGet(url, true) end\n";
            if (luaL_dostring(L, bootstrap) != 0) {
                lua_pop(L, 1);
            }
        }
        
        return L;
    }
    
    bool LuaInterpreterIntegration::LoadInterpreterFile(lua_State* L) {
        if (!L || m_interpreterScript.empty()) {
            return false;
        }
        
        // Load the interpreter script
        int status = luaL_loadstring(L, m_interpreterScript.c_str());
        if (status != 0) {
            Logging::LogError("LuaInterpreter", "Failed to load interpreter.lua: " + GetLuaError(L));
            return false;
        }
        
        // Execute the script to initialize the interpreter
        status = lua_pcall(L, 0, 0, 0);
        if (status != 0) {
            Logging::LogError("LuaInterpreter", "Failed to execute interpreter.lua: " + GetLuaError(L));
            return false;
        }
        
        Logging::LogInfo("LuaInterpreter", "Successfully loaded and executed interpreter.lua");
        return true;
    }
    
    bool LuaInterpreterIntegration::SetupEnvironment(lua_State* L, const ExecutionOptions& options) {
        // Set up environment variables
        lua_newtable(L);
        
        // Add all custom environment variables
        for (const auto& pair : options.environment) {
            lua_pushstring(L, pair.second.c_str());
            lua_setfield(L, -2, pair.first.c_str());
        }
        
        // Add standard environment variables
        // Default globals for Roblox-like environment
        lua_pushstring(L, "iOS");
        lua_setfield(L, -2, "_G_PLATFORM");
        
        lua_pushboolean(L, 1);
        lua_setfield(L, -2, "_G_IS_MOBILE");
        
        lua_pushnumber(L, 1.0);
        lua_setfield(L, -2, "_G_VERSION");
        
        // Set as global "_ENV" for scripts
        lua_setglobal(L, "_ENV");
        
        return true;
    }
    
    bool LuaInterpreterIntegration::SetupSandbox(lua_State* L) {
        // Generate and apply sandbox environment
        GenerateSandbox(L);
        return true;
    }
    
    bool LuaInterpreterIntegration::SetupOutputCapture(lua_State* L) {
        // print function is already overridden in CreateState
        // Additional output functions can be captured here
        return true;
    }
    
    std::string LuaInterpreterIntegration::GetLuaError(lua_State* L) {
        std::string error;
        
        if (lua_isstring(L, -1)) {
            error = lua_tostring(L, -1);
        } else {
            error = "Unknown error";
        }
        
        lua_pop(L, 1); // Remove error message
        return error;
    }
    
    void LuaInterpreterIntegration::GenerateSandbox(lua_State* L) {
        // Create a sandboxed environment for script execution
        luaL_dostring(L, R"(
            local sandbox = {}
            
            -- Copy safe base functions
            for k, v in pairs(_G) do
                if k ~= "dofile" and k ~= "loadfile" and k ~= "load" and
                   k ~= "os" and k ~= "io" and k ~= "debug" then
                    sandbox[k] = v
                end
            end
            
            -- Provide limited os functions
            sandbox.os = {
                time = os.time,
                date = os.date,
                difftime = os.difftime,
                clock = os.clock
            }
            
            -- Restricted require function
            sandbox.require = function(module)
                -- Only allow safe modules
                if module == "math" or module == "table" or module == "string" or
                   module == "coroutine" or module == "utf8" then
                    return require(module)
                else
                    error("Cannot require module: " .. module)
                end
            end
            
            -- Set the sandbox as global environment
            _G.sandbox = sandbox
        )");
    }
}
