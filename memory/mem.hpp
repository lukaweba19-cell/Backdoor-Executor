#pragma once

#include <cstdint>
#include <string>
#include <vector>
#include <map>
#include <mutex>
#include <functional>
#include <memory>
#include "ci_compat.h"
#include "signature.hpp"

namespace Memory {
    // Memory protection flags
    enum class Protection {
        None = 0,
        Read = 1,
        Write = 2,
        Execute = 4,
        ReadWrite = Read | Write,
        ReadExecute = Read | Execute,
        ReadWriteExecute = Read | Write | Execute
    };
    
    // Memory region information
    struct MemoryRegion {
        uintptr_t baseAddress;
        size_t size;
        Protection protection;
        std::string name;
        
        MemoryRegion() : baseAddress(0), size(0), protection(Protection::None) {}
        MemoryRegion(uintptr_t base, size_t s, Protection prot, const std::string& n = "")
            : baseAddress(base), size(s), protection(prot), name(n) {}
    };
    
    // Memory scanning model
    class MemoryScanModel {
    public:
        // Scan for a specific pattern in memory
        static ScanResult ScanForPattern(const std::string& pattern, const MemoryRegion& region);
        
        // Scan for a specific string in memory
        static ScanResult ScanForString(const std::string& str, const MemoryRegion& region);
        
        // Scan for multiple patterns and return all matches
        static std::vector<ScanResult> ScanForMultiplePatterns(const std::vector<std::string>& patterns, const MemoryRegion& region);
        
        // Predict memory locations based on previous scans
        static std::map<std::string, uintptr_t> PredictMemoryLocations(const std::string& version);
    };
    
    // Memory utilities
    class MemoryUtils {
    public:
        // Read memory
        template<typename T>
        static T Read(uintptr_t address) {
            T value = T();
            ReadMemory(address, &value, sizeof(T));
            return value;
        }
        
        // Write memory
        template<typename T>
        static bool Write(uintptr_t address, const T& value) {
            return WriteMemory(address, &value, sizeof(T));
        }
        
        // Read string from memory
        static std::string ReadString(uintptr_t address, size_t maxLength = 256);
        
        // Write string to memory
        static bool WriteString(uintptr_t address, const std::string& str);
        
        // Change memory protection
        static bool Protect(uintptr_t address, size_t size, Protection protection);
        
        // Get memory regions
        static std::vector<MemoryRegion> GetMemoryRegions();
        
        // Find memory region containing address
        static MemoryRegion FindMemoryRegion(uintptr_t address);
        
        // Low-level memory operations
        static bool ReadMemory(uintptr_t address, void* buffer, size_t size);
        static bool WriteMemory(uintptr_t address, const void* buffer, size_t size);
    };
    
    // Memory patching utilities
    class MemoryPatch {
    public:
        MemoryPatch(uintptr_t address, const std::vector<uint8_t>& bytes);
        ~MemoryPatch();
        
        // Apply the patch
        bool Apply();
        
        // Restore original bytes
        bool Restore();
        
        // Check if patch is applied
        bool IsApplied() const;
        
    private:
        uintptr_t m_address;
        std::vector<uint8_t> m_originalBytes;
        std::vector<uint8_t> m_patchBytes;
        bool m_applied;
        Protection m_originalProtection;
    };
    
    // Memory hook utilities
    class MemoryHook {
    public:
        using HookCallback = std::function<void(void*)>;
        
        MemoryHook(uintptr_t address, const HookCallback& callback);
        ~MemoryHook();
        
        // Install the hook
        bool Install();
        
        // Remove the hook
        bool Remove();
        
        // Check if hook is installed
        bool IsInstalled() const;
        
    private:
        uintptr_t m_address;
        HookCallback m_callback;
        bool m_installed;
        std::vector<uint8_t> m_originalBytes;
    };
    
    // Memory cache for optimizing repeated memory operations
    class MemoryCache {
    public:
        // Get instance (singleton)
        static MemoryCache& GetInstance();
        
        // Cache a memory region
        bool CacheRegion(uintptr_t address, size_t size);
        
        // Read from cache
        template<typename T>
        T Read(uintptr_t address) {
            T value = T();
            ReadFromCache(address, &value, sizeof(T));
            return value;
        }
        
        // Invalidate cache
        void Invalidate();
        
    private:
        MemoryCache();
        ~MemoryCache();
        
        // Read from cache implementation
        bool ReadFromCache(uintptr_t address, void* buffer, size_t size);
        
        // Cache data
        std::map<uintptr_t, std::vector<uint8_t>> m_cachedRegions;
        std::mutex m_cacheMutex;
    };
    
    // Initialize memory subsystem
    bool Initialize();
    
    // Shutdown memory subsystem
    void Shutdown();
}
