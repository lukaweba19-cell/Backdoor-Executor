#include "library.hpp"

#include <cstring>
#include <iostream>
#include <memory>
#include <string>
#include <vector>

#ifdef __APPLE__
#include <mach/mach.h>
#include <unistd.h>
#endif

#include "dobby_wrapper.h"
#include "init.hpp"
#include "ExecutionEngine.h"
#include "ScriptManager.h"
#include "JailbreakBypass.h"
#include "UIController.h"
#include "MemoryAccess.h"

#if defined(ENABLE_AI_FEATURES) && ENABLE_AI_FEATURES
#include "HybridAISystem.h"
#include "ScriptAssistant.h"
#include "AISystemInitializer.h"


#endif

namespace {

std::shared_ptr<iOS::ExecutionEngine> g_executionEngine;
std::shared_ptr<iOS::ScriptManager> g_scriptManager;
std::unique_ptr<iOS::UIController> g_uiController;
bool g_aiEnabled = true;

bool InitializeLibrary() {
    std::cout << "Initializing Roblox Executor library..." << std::endl;

    try {
        RobloxExecutor::InitOptions options;
        options.enableLogging = true;
        options.enableErrorReporting = true;
        options.enablePerformanceMonitoring = true;
        options.enableSecurity = true;
        options.enableJailbreakBypass = true;
        options.enableUI = true;
#if defined(ENABLE_AI_FEATURES) && ENABLE_AI_FEATURES
        options.enableAI = true;
#endif

        if (!RobloxExecutor::SystemState::Initialize(options)) {
            std::cerr << "Failed to initialize RobloxExecutor::SystemState" << std::endl;
            return false;
        }

        g_executionEngine = RobloxExecutor::SystemState::GetExecutionEngine();
        g_scriptManager = RobloxExecutor::SystemState::GetScriptManager();
        g_uiController = std::move(RobloxExecutor::SystemState::GetUIController());

        if (!g_executionEngine) {
            std::cerr << "ExecutionEngine not available after init" << std::endl;
            return false;
        }

        std::cout << "Roblox Executor library initialized successfully" << std::endl;
        return true;
    } catch (const std::exception& ex) {
        std::cerr << "Exception during library initialization: " << ex.what() << std::endl;
        return false;
    }
}

} // namespace

extern "C" {

__attribute__((constructor))
void dylib_initializer() {
    std::cout << "Roblox Executor dylib loaded" << std::endl;
    if (!InitializeLibrary()) {
        std::cerr << "Failed to initialize library" << std::endl;
    }
}

__attribute__((destructor))
void dylib_finalizer() {
    std::cout << "Roblox Executor dylib unloading" << std::endl;
    RobloxExecutor::SystemState::Shutdown();
    g_executionEngine.reset();
    g_scriptManager.reset();
    g_uiController.reset();
    DobbyWrapper::UnhookAll();
}

int luaopen_mylibrary(void* L) {
    (void)L;
    return 1;
}

bool ExecuteScript(const char* script) {
    if (!script || !g_executionEngine) {
        return false;
    }
    try {
        auto result = g_executionEngine->Execute(std::string(script));
        return result.m_success;
    } catch (const std::exception& ex) {
        std::cerr << "ExecuteScript exception: " << ex.what() << std::endl;
        return false;
    }
}

bool WriteMemory(void* address, const void* data, size_t size) {
    if (!address || !data || size == 0) {
        return false;
    }
    return iOS::MemoryAccess::WriteMemory(address, data, size);
}

bool ProtectMemory(void* address, size_t size, int protection) {
    if (!address || size == 0) {
        return false;
    }
#ifdef __APPLE__
    return iOS::MemoryAccess::ProtectMemory(address, size, protection);
#else
    (void)protection;
    return false;
#endif
}

void* HookRobloxMethod(void* original, void* replacement) {
    if (!original || !replacement) {
        return nullptr;
    }
#if defined(USE_DOBBY) && USE_DOBBY
    return DobbyWrapper::Hook(original, replacement);
#else
    return nullptr;
#endif
}

bool InjectRobloxUI() {
    if (!g_uiController) {
        return false;
    }
    try {
        g_uiController->Show();
        return true;
    } catch (const std::exception& ex) {
        std::cerr << "InjectRobloxUI exception: " << ex.what() << std::endl;
        return false;
    }
}

void AIFeatures_Enable(bool enable) {
    g_aiEnabled = enable;
}

void AIIntegration_Initialize() {
#if defined(ENABLE_AI_FEATURES) && ENABLE_AI_FEATURES
    try {
        auto* init = iOS::AIFeatures::AISystemInitializer::GetInstance();
        if (init && !init->IsInitialized()) {
            init->Initialize();
        }
        auto assistant = RobloxExecutor::SystemState::GetScriptAssistant();
        if (assistant) {
            assistant->Initialize();
        }
    } catch (const std::exception& ex) {
        std::cerr << "AIIntegration_Initialize exception: " << ex.what() << std::endl;
    }
#else
    std::cerr << "AI features compiled out (ENABLE_AI_FEATURES=0)" << std::endl;
#endif
}

const char* GetScriptSuggestions(const char* script) {
    static std::string suggestions;
    suggestions.clear();

    if (!script) {
        suggestions = "-- error: null script";
        return suggestions.c_str();
    }

#if defined(ENABLE_AI_FEATURES) && ENABLE_AI_FEATURES
    if (!g_aiEnabled) {
        suggestions = "-- AI features disabled";
        return suggestions.c_str();
    }

    try {
        auto assistant = RobloxExecutor::SystemState::GetScriptAssistant();
        if (assistant) {
            std::vector<std::string> list = assistant->GetSuggestions(std::string(script));
            for (size_t i = 0; i < list.size(); ++i) {
                if (i > 0) suggestions += "\n";
                suggestions += list[i];
            }
            if (!suggestions.empty()) {
                return suggestions.c_str();
            }
            // Online generation via HybridAISystem nested types
            iOS::AIFeatures::HybridAISystem hybrid;
            // Endpoint/key come from AIConfig defaults when empty args allowed — use online-only mode
            hybrid.Initialize("", "", "", iOS::AIFeatures::HybridAISystem::OnlineMode::OnlineOnly);
            iOS::AIFeatures::HybridAISystem::AIRequest request(
                std::string("Provide concise Luau script suggestions for:\n") + script,
                "",
                "general",
                false);
            auto response = hybrid.ProcessRequestSync(request);
            if (response.m_success) {
                suggestions = response.m_content.empty() ? response.m_scriptCode : response.m_content;
            } else {
                suggestions = std::string("-- AI error: ") + response.m_errorMessage;
            }
        } else {
            suggestions = "-- ScriptAssistant not available";
        }
    } catch (const std::exception& ex) {
        suggestions = std::string("-- exception: ") + ex.what();
    }
#else
    suggestions = "-- AI features not compiled in";
#endif
    return suggestions.c_str();
}

void LEDEffects_Enable(bool enable) {
    (void)enable;
    // LED hardware effects are device-specific; no-op until a concrete backend is wired.
}

} // extern "C"
