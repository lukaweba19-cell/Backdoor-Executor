// MemoryAccess.mm - Production-quality implementation
#include "MemoryAccess.h"
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <mach/vm_region.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <vector>
#include <sys/mman.h>
#include <iostream>

namespace iOS {
    // Implement ReadMemory with robust functionality
    bool MemoryAccess::ReadMemory(void* address, void* buffer, size_t size) {
        if (!address || !buffer || size == 0) {
            std::cerr << "ReadMemory: Invalid parameters" << std::endl;
            return false;
        }
        
        task_t task = mach_task_self();
        vm_size_t bytesRead = 0;
        
        kern_return_t kr = vm_read_overwrite(task, 
                                         (vm_address_t)address, 
                                         size, 
                                         (vm_address_t)buffer, 
                                         &bytesRead);
        
        if (kr != KERN_SUCCESS) {
            std::cerr << "ReadMemory: Failed at address " << address 
                     << ", size " << size << std::endl;
            return false;
        }
        
        return bytesRead == size;
    }
    
    // Implement WriteMemory with robust functionality
    bool MemoryAccess::WriteMemory(void* address, const void* buffer, size_t size) {
        if (!address || !buffer || size == 0) {
            std::cerr << "WriteMemory: Invalid parameters" << std::endl;
            return false;
        }
        
        task_t task = mach_task_self();
        
        // Get current protection - using vm_region instead of vm_region_64 to fix type issues
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
        vm_address_t regionAddress = (vm_address_t)(uintptr_t)address;
        vm_size_t regionSize = 0;
        mach_port_t objectName = MACH_PORT_NULL;
        
        kern_return_t kr = vm_region(task, 
                                  &regionAddress, 
                                  &regionSize, 
                                  VM_REGION_BASIC_INFO_64, 
                                  (vm_region_info_t)&info, 
                                  &infoCount, 
                                  &objectName);
        
        // Ensure memory is writable
        bool protectionChanged = false;
        int originalProtection = VM_PROT_READ | VM_PROT_WRITE;
        
        if (kr == KERN_SUCCESS) {
            originalProtection = info.protection;
            
            if (!(originalProtection & VM_PROT_WRITE)) {
                kr = vm_protect(task, 
                              (vm_address_t)address, 
                              size, 
                              FALSE, 
                              originalProtection | VM_PROT_WRITE);
                
                if (kr == KERN_SUCCESS) {
                    protectionChanged = true;
                }
            }
        }
        
        // Write memory
        kr = vm_write(task, 
                   (vm_address_t)address, 
                   (vm_address_t)buffer, 
                   (mach_msg_type_number_t)size);
        
        // Restore original protection if changed
        if (protectionChanged) {
            vm_protect(task, 
                     (vm_address_t)address, 
                     size, 
                     FALSE, 
                     originalProtection);
        }
        
        if (kr != KERN_SUCCESS) {
            std::cerr << "WriteMemory: Failed at address " << address 
                     << ", size " << size << std::endl;
            return false;
        }
        
        return true;
    }
    
    // Implement GetModuleBase with robust functionality
    uintptr_t MemoryAccess::GetModuleBase(const std::string& moduleName) {
        // Empty name → main executable (or this image as fallback)
        if (moduleName.empty() || moduleName == "main" || moduleName == "RobloxPlayer" ||
            moduleName == "Roblox") {
            Dl_info info;
            uintptr_t (*baseFn)(const std::string&) = &MemoryAccess::GetModuleBase;
            if (dladdr((void*)baseFn, &info) && info.dli_fbase) {
                // Prefer dyld image 0 (main executable)
                uint32_t count = _dyld_image_count();
                if (count > 0) {
                    const char* name0 = _dyld_get_image_name(0);
                    const mach_header* hdr0 = _dyld_get_image_header(0);
                    if (hdr0) {
                        // If caller wants Roblox specifically, match name
                        if (moduleName.empty() || moduleName == "main" ||
                            (name0 && (std::string(name0).find("Roblox") != std::string::npos ||
                                       moduleName == "Roblox" || moduleName == "RobloxPlayer"))) {
                            return (uintptr_t)hdr0;
                        }
                    }
                    // Search images for Roblox
                    for (uint32_t i = 0; i < count; ++i) {
                        const char* n = _dyld_get_image_name(i);
                        if (n && strstr(n, "Roblox")) {
                            return (uintptr_t)_dyld_get_image_header(i);
                        }
                    }
                    // Default main image
                    if (hdr0) {
                        return (uintptr_t)hdr0;
                    }
                }
                return (uintptr_t)info.dli_fbase;
            }
            return 0;
        }
        
        void* handle = dlopen(moduleName.c_str(), RTLD_NOLOAD);
        if (!handle) {
            // Try with various extensions
            std::vector<std::string> attempts = {
                moduleName + ".dylib",
                moduleName + ".framework/" + moduleName,
                "/usr/lib/" + moduleName,
                "/System/Library/Frameworks/" + moduleName + ".framework/" + moduleName
            };
            
            for (const auto& attempt : attempts) {
                handle = dlopen(attempt.c_str(), RTLD_NOLOAD);
                if (handle) {
                    break;
                }
            }
            
            if (!handle) {
                std::cerr << "GetModuleBase: Module not found: " << moduleName << std::endl;
                return 0;
            }
        }
        
        Dl_info info;
        if (dladdr(handle, &info) == 0) {
            dlclose(handle);
            std::cerr << "GetModuleBase: Failed to get module info for " << moduleName << std::endl;
            return 0;
        }
        
        dlclose(handle);
        return (uintptr_t)info.dli_fbase;
    }
    
    // Real module size via Mach-O header + load commands (or vm regions)
    size_t MemoryAccess::GetModuleSize(const std::string& moduleName) {
        uintptr_t base = GetModuleBase(moduleName);
        if (base == 0) {
            // Main image if name looks like empty / main
            base = GetModuleBase("");
            if (base == 0) {
                // Fall back: dyld main image
                const struct mach_header_64* hdr = nullptr;
                // Use dladdr on a known symbol in this image
                Dl_info info;
                // Disambiguate overload: take address of the string-parameter overload via lambda body symbol
                size_t (*sizeFn)(const std::string&) = &MemoryAccess::GetModuleSize;
                if (dladdr((void*)sizeFn, &info) && info.dli_fbase) {
                    base = (uintptr_t)info.dli_fbase;
                }
            }
        }
        if (base == 0) return 0;
        return GetModuleSize(base);
    }
    
    size_t MemoryAccess::GetModuleSize(uintptr_t moduleBase) {
        if (moduleBase == 0) return 0;

        // Prefer Mach-O header size computation
        const mach_header_64* header = reinterpret_cast<const mach_header_64*>(moduleBase);
        // Basic sanity: magic
        uint32_t magic = 0;
        if (!ReadMemory(reinterpret_cast<void*>(moduleBase), &magic, sizeof(magic))) {
            return 0;
        }
        if (magic != MH_MAGIC_64 && magic != MH_CIGAM_64 && magic != MH_MAGIC && magic != MH_CIGAM) {
            // Not a Mach-O header at base — sum contiguous vm regions starting at base
            task_t task = mach_task_self();
            vm_address_t address = (vm_address_t)moduleBase;
            vm_size_t size = 0;
            size_t total = 0;
            vm_region_basic_info_data_64_t info;
            mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
            mach_port_t object_name = MACH_PORT_NULL;
            kern_return_t kr = vm_region_64(task, &address, &size, VM_REGION_BASIC_INFO_64,
                                           (vm_region_info_t)&info, &count, &object_name);
            if (kr == KERN_SUCCESS && address <= moduleBase && moduleBase < address + size) {
                return (size_t)size;
            }
            return 0;
        }

        // Walk load commands for max extent
        if (magic == MH_MAGIC_64 || magic == MH_CIGAM_64) {
            mach_header_64 hdr{};
            if (!ReadMemory(reinterpret_cast<void*>(moduleBase), &hdr, sizeof(hdr))) return 0;
            uintptr_t cursor = moduleBase + sizeof(mach_header_64);
            uintptr_t maxEnd = moduleBase + sizeof(mach_header_64);
            for (uint32_t i = 0; i < hdr.ncmds; ++i) {
                load_command lc{};
                if (!ReadMemory(reinterpret_cast<void*>(cursor), &lc, sizeof(lc))) break;
                if (lc.cmd == LC_SEGMENT_64) {
                    segment_command_64 seg{};
                    if (ReadMemory(reinterpret_cast<void*>(cursor), &seg, sizeof(seg))) {
                        uintptr_t end = moduleBase + seg.fileoff + seg.filesize;
                        // Prefer vmaddr-based for loaded image
                        end = seg.vmaddr + seg.vmsize; // slide may apply; use vmsize from base-relative if needed
                        // For dyld-loaded images, seg.vmaddr is already slid in process
                        if (seg.vmsize > 0) {
                            uintptr_t segEnd = (uintptr_t)seg.vmaddr + (uintptr_t)seg.vmsize;
                            if (segEnd > maxEnd) maxEnd = segEnd;
                        }
                    }
                }
                cursor += lc.cmdsize;
                if (lc.cmdsize == 0) break;
            }
            if (maxEnd > moduleBase) return (size_t)(maxEnd - moduleBase);
        }

        // Fallback: single region size at base
        task_t task = mach_task_self();
        vm_address_t address = (vm_address_t)moduleBase;
        vm_size_t size = 0;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t object_name = MACH_PORT_NULL;
        if (vm_region_64(task, &address, &size, VM_REGION_BASIC_INFO_64,
                         (vm_region_info_t)&info, &count, &object_name) == KERN_SUCCESS) {
            return (size_t)size;
        }
        return 0;
    }
    
    // Implement ProtectMemory with robust functionality
    bool MemoryAccess::ProtectMemory(void* address, size_t size, int protection) {
        if (!address || size == 0) {
            std::cerr << "ProtectMemory: Invalid parameters" << std::endl;
            return false;
        }
        
        task_t task = mach_task_self();
        
        kern_return_t kr = vm_protect(task, 
                                    (vm_address_t)address, 
                                    size, 
                                    FALSE, 
                                    protection);
        
        if (kr != KERN_SUCCESS) {
            std::cerr << "ProtectMemory: Failed at address " << address 
                     << ", size " << size 
                     << ", protection " << protection << std::endl;
            return false;
        }
        
        std::cout << "ProtectMemory: Successfully changed protection at " << address << std::endl;
        return true;
    }
}
