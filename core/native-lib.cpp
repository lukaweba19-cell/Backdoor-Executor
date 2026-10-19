#include <iostream>
#include <string>
#include <memory>

// Include our pure C++ utility macros without Objective-C dependencies
#include "utility.h"

// Include platform-specific headers with proper guards
#ifdef __APPLE__
    #include "hooks/hooks.hpp"
    #include "memory/mem.hpp"
    #include "ios/ExecutionEngine.h"
    #include "ios/ScriptManager.h"
    #include "ios/UIController.h"
#endif

// Forward declarations for RobloxExecutor namespace
namespace RobloxExecutor {
    struct InitOptions {
        bool enableLogging;
        bool enableErrorReporting;
        bool enablePerformanceMonitoring;
        bool enableSecurity;
        bool enableJailbreakBypass;
        bool enableUI;
    };
    
    bool Initialize(const InitOptions& options);
    void Shutdown();
    
    namespace SystemState {
        // Platform-specific declarations inside platform-specific guards
        #ifdef __APPLE__
            #ifndef SKIP_IOS_INTEGRATION
                // Only declare iOS types if integration is enabled
                std::shared_ptr<iOS::ExecutionEngine> GetExecutionEngine();
                std::shared_ptr<iOS::UIController> GetUIController();
            #endif
        #endif
    }
}

// C interface
extern "C" {
    // Initialization function that runs when library is loaded
    __attribute__((constructor))
    void dylib_initializer() {
        std::cout << "Roblox Executor dylib initializing" << std::endl;
        
        #ifdef __APPLE__
        // Initialize the hook engine
        Hooks::HookEngine::Initialize();
        
        // Initialize memory system
        Memory::Initialize();
        
        // iOS-specific initialization
        std::cout << "Initializing iOS integration" << std::endl;
        #endif
    }
    
    __attribute__((destructor))
    void dylib_finalizer() {
        std::cout << "Roblox Executor dylib shutting down" << std::endl;
        
        #ifdef __APPLE__
        // Clean up hooks
        Hooks::HookEngine::ClearAllHooks();
        #endif
    }
    
    // Lua module entry point
    /* luaopen_mylibrary defined in library.cpp */
}
