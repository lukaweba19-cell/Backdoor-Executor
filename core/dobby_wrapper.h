#pragma once

namespace DobbyWrapper {
    // Install a hook; returns original function pointer, or nullptr on failure
    void* Hook(void* targetAddr, void* replacementAddr);

    // Restore a previously hooked address to its original implementation
    bool Unhook(void* targetAddr);

    // Restore every tracked hook
    void UnhookAll();

    // Lookup original for a hooked target (nullptr if not tracked)
    void* GetOriginalFunction(void* targetAddr);
}
