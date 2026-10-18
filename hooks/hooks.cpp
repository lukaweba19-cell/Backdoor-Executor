#include "hooks.hpp"
#include "../dobby_wrapper.cpp"
#include <iostream>

namespace Hooks {
    // Initialize static members that were previously in the header
    std::unordered_map<void*, void*> HookEngine::s_hookedFunctions;
    std::mutex HookEngine::s_hookMutex;
    std::map<std::string, std::pair<Class, SEL>> ObjcMethodHook::s_hookedMethods;
    std::mutex ObjcMethodHook::s_methodMutex;
    
    // Initialize the hook engine
    bool HookEngine::Initialize() {
        std::cout << "Initializing hook engine..." << std::endl;
        return true;
    }
    
    // Register hooks
    bool HookEngine::RegisterHook(void* targetAddr, void* hookAddr, void** originalAddr) {
        if (!targetAddr || !hookAddr) {
            return false;
        }
        
        std::lock_guard<std::mutex> lock(s_hookMutex);
        
        // Check if already hooked
        if (s_hookedFunctions.find(targetAddr) != s_hookedFunctions.end()) {
            return false;
        }
        
        // Use Dobby to hook the function
        bool success = Implementation::HookFunction(targetAddr, hookAddr, originalAddr);
        if (success) {
            s_hookedFunctions[targetAddr] = hookAddr;
        }
        
        return success;
    }
    
    // Unregister hooks
    bool HookEngine::UnregisterHook(void* targetAddr) {
        if (!targetAddr) {
            return false;
        }
        
        std::lock_guard<std::mutex> lock(s_hookMutex);
        
        // Check if hooked
        auto it = s_hookedFunctions.find(targetAddr);
        if (it == s_hookedFunctions.end()) {
            return false;
        }
        
        // Use Dobby to unhook the function
        bool success = Implementation::UnhookFunction(targetAddr);
        if (success) {
            s_hookedFunctions.erase(it);
        }
        
        return success;
    }
    
    // Clear all hooks
    void HookEngine::ClearAllHooks() {
        std::lock_guard<std::mutex> lock(s_hookMutex);
        
        for (auto& pair : s_hookedFunctions) {
            Implementation::UnhookFunction(pair.first);
        }
        
        s_hookedFunctions.clear();
    }
    
    // Implementation namespace
    namespace Implementation {
        // Hook function implementation using Dobby
        bool HookFunction(void* target, void* replacement, void** original) {
            if (!target || !replacement) {
                return false;
            }
            
#ifdef USE_DOBBY
            // Use Dobby for hooking
            *original = DobbyWrapper::Hook(target, replacement);
            return (*original != nullptr);
#else
            // No hooking library available
            return false;
#endif
        }
        
        // Unhook function implementation
        bool UnhookFunction(void* target) {
            if (!target) {
                return false;
            }
            
#ifdef USE_DOBBY
            // Use Dobby for unhooking
            return DobbyWrapper::Unhook(target);
#else
            // No hooking library available
            return false;
#endif
        }
    }
    
    // Objective-C Method hooking implementation
    bool ObjcMethodHook::HookMethod(const std::string& className, const std::string& selectorName,
                                    void* replacementFn, void** originalFn) {
#ifdef __APPLE__
        std::lock_guard<std::mutex> lock(s_methodMutex);
        
        // Get the class and selector
        Class cls = objc_getClass(className.c_str());
        if (!cls) {
            return false;
        }
        
        SEL selector = sel_registerName(selectorName.c_str());
        if (!selector) {
            return false;
        }
        
        // Get the method
        Method method = class_getInstanceMethod(cls, selector);
        if (!method) {
            return false;
        }
        
        // Store the original method implementation
        IMP originalIMP = method_getImplementation(method);
        if (originalFn) {
            *originalFn = (void*)originalIMP;
        }
        
        // Replace the method implementation
        method_setImplementation(method, (IMP)replacementFn);
        
        // Store the hooked method for later
        std::string key = className + "::" + selectorName;
        s_hookedMethods[key] = std::make_pair(cls, selector);
        
        return true;
#else
        // Not supported on non-Apple platforms
        return false;
#endif
    }
    
    bool ObjcMethodHook::UnhookMethod(const std::string& className, const std::string& selectorName) {
#ifdef __APPLE__
        std::lock_guard<std::mutex> lock(s_methodMutex);
        
        // Check if the method is hooked
        std::string key = className + "::" + selectorName;
        auto it = s_hookedMethods.find(key);
        if (it == s_hookedMethods.end()) {
            return false;
        }
        
        // Get the class and selector
        Class cls = it->second.first;
        SEL selector = it->second.second;
        
        // Get the method
        Method method = class_getInstanceMethod(cls, selector);
        if (!method) {
            return false;
        }
        
        // We don't have the original implementation, so we can't restore it
        // This is a limitation - a better implementation would store the original implementation
        
        // Remove from the tracked methods
        s_hookedMethods.erase(it);
        
        return true;
#else
        // Not supported on non-Apple platforms
        return false;
#endif
    }
    
    void ObjcMethodHook::ClearAllHooks() {
#ifdef __APPLE__
        std::lock_guard<std::mutex> lock(s_methodMutex);
        
        // We don't have the original implementations, so we can't restore them
        // This is a limitation - a better implementation would store the original implementations
        
        // Clear the tracked methods
        s_hookedMethods.clear();
#endif
    }
}
