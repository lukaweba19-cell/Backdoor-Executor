// Public API for our library - isolated from both Lua and iOS headers
#pragma once

#include <string>

// This header defines the public interface without exposing internal types

extern "C" {
    // Library entry point for Lua
    int luaopen_mylibrary(void* L);
    
    // Script execution API
    bool ExecuteScript(const char* script);
    
    // Memory manipulation
    bool WriteMemory(void* address, const void* data, size_t size);
    bool ProtectMemory(void* address, size_t size, int protection);
    
    // Method hooking
    void* HookRobloxMethod(void* original, void* replacement);

    // UI integration
    bool InjectRobloxUI();
    
    // AI features
    void AIFeatures_Enable(bool enable);
    void AIIntegration_Initialize();
    const char* GetScriptSuggestions(const char* script);
    
    // LED effects
    void LEDEffects_Enable(bool enable);
}
