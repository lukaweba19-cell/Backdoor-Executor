#include "dobby_wrapper.h"

#include <cstdint>
#include <unordered_map>
#include <mutex>
#include <vector>

#ifdef __APPLE__
extern "C" {
    // Dobby public API (linked from static lib on CI)
    int DobbyHook(void* address, void* replacement, void** original);
    int DobbyDestroy(void* address);
}
#else
static inline int DobbyHook(void*, void*, void**) { return -1; }
static inline int DobbyDestroy(void*) { return -1; }
#endif

namespace DobbyWrapper {
namespace {
    struct HookRecord {
        void* original = nullptr;
        void* replacement = nullptr;
    };
    std::unordered_map<void*, HookRecord> g_hooks;
    std::mutex g_mutex;
}

void* Hook(void* targetAddr, void* replacementAddr) {
    if (!targetAddr || !replacementAddr) {
        return nullptr;
    }

    std::lock_guard<std::mutex> lock(g_mutex);

    auto existing = g_hooks.find(targetAddr);
    if (existing != g_hooks.end()) {
        // Already hooked — return stored original
        return existing->second.original;
    }

    void* originalFunc = nullptr;
    const int result = DobbyHook(targetAddr, replacementAddr, &originalFunc);
    if (result != 0 || originalFunc == nullptr) {
        return nullptr;
    }

    g_hooks[targetAddr] = HookRecord{originalFunc, replacementAddr};
    return originalFunc;
}

bool Unhook(void* targetAddr) {
    if (!targetAddr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(g_mutex);
    auto it = g_hooks.find(targetAddr);
    if (it == g_hooks.end()) {
        return false;
    }

    // Prefer DobbyDestroy (official restore). If it fails, re-hook original as fallback.
    int rc = DobbyDestroy(targetAddr);
    if (rc != 0) {
        void* dummy = nullptr;
        rc = DobbyHook(targetAddr, it->second.original, &dummy);
        if (rc != 0) {
            return false;
        }
    }

    g_hooks.erase(it);
    return true;
}

void UnhookAll() {
    std::lock_guard<std::mutex> lock(g_mutex);
    for (auto it = g_hooks.begin(); it != g_hooks.end(); ) {
        void* target = it->first;
        void* original = it->second.original;
        int rc = DobbyDestroy(target);
        if (rc != 0) {
            void* dummy = nullptr;
            DobbyHook(target, original, &dummy);
        }
        it = g_hooks.erase(it);
    }
}

void* GetOriginalFunction(void* targetAddr) {
    std::lock_guard<std::mutex> lock(g_mutex);
    auto it = g_hooks.find(targetAddr);
    if (it == g_hooks.end()) {
        return nullptr;
    }
    return it->second.original;
}
} // namespace DobbyWrapper
