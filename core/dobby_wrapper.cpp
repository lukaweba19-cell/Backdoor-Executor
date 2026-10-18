// Fixed dobby_wrapper.cpp implementation without DobbyUnHook
#include <cstdint>
#include <unordered_map>
#include <mutex>
#include <vector>

#ifdef __APPLE__
  // On iOS, we would include the actual Dobby header
  // #include "../external/dobby/include/dobby.h"
  // For compilation purposes, we'll define the function we need
  extern "C" {
    int DobbyHook(void* address, void* replacement, void** original);
  }
#else
  // Stub for non-iOS platforms
  #define DobbyHook(a, b, c) (-1)
#endif

namespace DobbyWrapper {
    // Thread-safe storage for original function pointers
    static std::unordered_map<void*, void*> originalFunctions;
    static std::mutex hookMutex;
    static std::vector<std::pair<void*, void*>> hookHistory;

    // Hook a function using Dobby
    void* Hook(void* targetAddr, void* replacementAddr) {
        if (!targetAddr || !replacementAddr) return nullptr;
        
        void* originalFunc = nullptr;
        
        {
            std::lock_guard<std::mutex> lock(hookMutex);
            int result = DobbyHook(targetAddr, replacementAddr, &originalFunc);
            
            if (result == 0 && originalFunc) {
                originalFunctions[targetAddr] = originalFunc;
                hookHistory.push_back({targetAddr, replacementAddr});
            } else {
                // Log error or handle the failure
                return nullptr;
            }
        }
        
        return originalFunc;
    }

    // Get the original function pointer for a hooked function
    void* GetOriginalFunction(void* targetAddr) {
        std::lock_guard<std::mutex> lock(hookMutex);
        auto it = originalFunctions.find(targetAddr);
        if (it != originalFunctions.end()) {
            return it->second;
        }
        return nullptr;
    }

    // Unhook a previously hooked function - Alternative implementation without DobbyUnHook
    bool Unhook(void* targetAddr) {
        if (!targetAddr) return false;
        
        {
            std::lock_guard<std::mutex> lock(hookMutex);
            // Alternative implementation - re-hook to original function
            auto it = originalFunctions.find(targetAddr);
            if (it != originalFunctions.end()) {
                void* originalFunc = it->second;
                // Re-hook to restore original function
                void* dummy = nullptr;
                DobbyHook(targetAddr, originalFunc, &dummy);
                originalFunctions.erase(targetAddr);
                return true;
            }
        }
        
        return false;
    }

    // Unhook all previously hooked functions
    void UnhookAll() {
        std::lock_guard<std::mutex> lock(hookMutex);
        
        for (auto& pair : hookHistory) {
            // Alternative implementation - re-hook to original function
            auto it = originalFunctions.find(pair.first);
            if (it != originalFunctions.end()) {
                void* dummy = nullptr;
                DobbyHook(pair.first, it->second, &dummy);
            }
        }
        
        originalFunctions.clear();
        hookHistory.clear();
    }
}
