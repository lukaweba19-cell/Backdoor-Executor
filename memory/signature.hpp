#pragma once

#include <string>
#include <vector>
#include <cstdint>
#include "ci_compat.h"

namespace Memory {
    // Signature scanning utilities
    class Signature {
    public:
        // Parse a signature string into byte pattern and mask
        // Format: "48 8B 05 ?? ?? ?? ??" where ?? represents wildcard bytes
        static std::pair<std::vector<uint8_t>, std::string> Parse(const std::string& signatureString) {
            std::vector<uint8_t> pattern;
            std::string mask;
            
            for (size_t i = 0; i < signatureString.length(); i++) {
                // Skip spaces
                if (signatureString[i] == ' ') {
                    continue;
                }
                
                // Handle wildcards
                if (signatureString[i] == '?') {
                    pattern.push_back(0);
                    mask.push_back('?');
                    
                    // Skip second ? if present (for "??")
                    if (i + 1 < signatureString.length() && signatureString[i + 1] == '?') {
                        i++;
                    }
                } else {
                    // Parse hex byte
                    if (i + 1 >= signatureString.length()) {
                        // Incomplete hex byte
                        break;
                    }
                    
                    char hex[3] = { signatureString[i], signatureString[i + 1], 0 };
                    pattern.push_back(static_cast<uint8_t>(strtol(hex, nullptr, 16)));
                    mask.push_back('x');
                    
                    // Skip second character of the hex byte
                    i++;
                }
            }
            
            return { pattern, mask };
        }
        
        // Convert a byte array to a signature string
        static std::string ToString(const std::vector<uint8_t>& bytes) {
            std::string result;
            
            for (size_t i = 0; i < bytes.size(); i++) {
                char hex[3];
                snprintf(hex, sizeof(hex), "%02X", bytes[i]);
                result += hex;
                
                if (i < bytes.size() - 1) {
                    result += " ";
                }
            }
            
            return result;
        }
    };
    
    // Pattern scanning result
    struct ScanResult {
        uintptr_t address;
        size_t size;
        
        ScanResult() : address(0), size(0) {}
        ScanResult(uintptr_t addr, size_t s) : address(addr), size(s) {}
        
        operator bool() const { return address != 0; }
        
        template<typename T>
        T* As() const { return reinterpret_cast<T*>(address); }
    };
    
    // Forward declaration of PatternScanner
    class PatternScanner {
    public:
        // Scan for a pattern in memory
        static ScanResult ScanForPattern(const char* pattern, const char* mask, void* startAddress, void* endAddress);
        
        // Scan for a signature string
        static ScanResult ScanForSignature(const std::string& signature, void* startAddress = nullptr, void* endAddress = nullptr);
        
        // Scan for a string in memory
        static ScanResult ScanForString(const std::string& str, void* startAddress = nullptr, void* endAddress = nullptr);
        
        // Find all occurrences of a pattern
        static std::vector<ScanResult> FindAllPatterns(const char* pattern, const char* mask, void* startAddress = nullptr, void* endAddress = nullptr);
        
        // Get base address of the process
        static uintptr_t GetBaseAddress();
        
        // Get base address of a module
        static uintptr_t GetModuleBaseAddress(const std::string& moduleName);
        
        // Get size of a module
        static size_t GetModuleSize(const std::string& moduleName);
        
        // Get address by pattern
        static uintptr_t GetAddressByPattern(const char* pattern);
    };
}
