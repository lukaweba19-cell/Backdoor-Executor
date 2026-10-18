// MemoryAccess.h - Simplified memory access utilities
#pragma once

#include <string>
#include <cstdint>

namespace iOS {
    class MemoryAccess {
    public:
        // Basic memory operations - simplified
        static bool ReadMemory(void* address, void* buffer, size_t size);
        static bool WriteMemory(void* address, const void* buffer, size_t size);
        
        // Module information - simplified
        static uintptr_t GetModuleBase(const std::string& moduleName);
        static size_t GetModuleSize(const std::string& moduleName);
        static size_t GetModuleSize(uintptr_t moduleBase);
        
        // Memory protection - simplified
        static bool ProtectMemory(void* address, size_t size, int protection);
    };
}
