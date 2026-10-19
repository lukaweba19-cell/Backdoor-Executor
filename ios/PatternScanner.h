#include "ci_compat.h"

#pragma once

#include <string>
#include <vector>
#include <map>
#include <mutex>
#include <cstdint>

namespace iOS {
    class PatternScanner {
    public:
        struct ScanResult {
            uintptr_t address;
            size_t size;
            ScanResult() : address(0), size(0) {}
            ScanResult(uintptr_t addr, size_t s) : address(addr), size(s) {}
            operator bool() const { return address != 0; }
        };

        // Implemented in PatternScanner.mm
        static ScanResult ScanForPattern(const char* pattern, const char* mask, void* startAddress, void* endAddress);
        static ScanResult ScanForSignature(const std::string& signature, void* startAddress = nullptr, void* endAddress = nullptr);
        static ScanResult ScanForString(const std::string& str, void* startAddress = nullptr, void* endAddress = nullptr);
        static std::vector<ScanResult> FindAllPatterns(const char* pattern, const char* mask, void* startAddress, void* endAddress);

        static uintptr_t GetBaseAddress();
        static uintptr_t GetModuleBaseAddress(const std::string& moduleName);
        static std::pair<uintptr_t, size_t> GetModuleInfo(const std::string& moduleName);
        static void* FindSymbol(const std::string& moduleName, const std::string& symbolName);
        static size_t GetModuleSize(const std::string& moduleName);

        // Convenience wrappers (real implementations, not stubs)
        static ScanResult FindPattern(const char* module, const char* pattern, const char* mask);
        static ScanResult FindPattern(const char* module, const char* patternString);
    };
}
