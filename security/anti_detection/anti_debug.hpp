#pragma once

#include <string>
#include <vector>
#include <chrono>
#include <thread>
#include <random>
#include <functional>
#include <unordered_map>
#include <atomic>
#include <mutex>
#include <dlfcn.h>

// iOS-specific includes
// Use Mach-specific APIs instead of ptrace on iOS
// ptrace is unreliable on iOS anyway as it's heavily restricted
#include <sys/types.h>
#include <sys/sysctl.h>
#include <unistd.h>
#include <signal.h>
#include <mach/mach.h>
#include <mach/mach_error.h>
#include <mach/task.h>
#include <mach-o/dyld.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <objc/runtime.h>
#include <objc/message.h>

// Define the ptrace constants and function we need for iOS
#define PT_DENY_ATTACH      31

// Define the ptrace function prototype for iOS
extern "C" {
    int ptrace(int request, pid_t pid, caddr_t addr, int data);
}

namespace AntiDetection {
    /**
     * @class AntiDebug
     * @brief Advanced iOS-specific anti-debugging techniques to prevent analysis
     * 
     * This class implements multiple iOS anti-debugging techniques to prevent
     * reverse engineering and analysis of the executor, optimized for iOS devices.
     */
    class AntiDebug {
    private:
        // Constants for iOS-specific checks
        static constexpr int PTRACE_DENY_ATTACH = 31;
        // Avoid redefining P_TRACED as it's already defined in system headers
        static constexpr int EXECUTOR_P_TRACED = 0x00000800;
        static constexpr int PROC_PIDINFO = 3;
        static constexpr int PROC_PIDPATHINFO = 11;
        
        // iOS debugger tools and indicators
        static const inline std::vector<std::string> s_debuggerPaths = {
            "/Applications/Xcode.app",
            "/usr/bin/gdb",
            "/usr/local/bin/cycript",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/usr/sbin/frida-server",
            "/usr/lib/frida",
            "/etc/apt/sources.list.d/electra.list",
            "/etc/apt/sources.list.d/sileo.sources",
            "/usr/lib/TweakInject"
        };
        
        // Timing check state
        static std::atomic<bool> s_timingCheckActive;
        static std::mutex s_timingMutex;
        static std::chrono::high_resolution_clock::time_point s_lastCheckTime;
        
        // Random number generator with entropy from device-specific sources
        static std::mt19937& GetRNG() {
            // Use multiple sources of entropy including device-specific information
            static std::random_device rd;
            static std::seed_seq seed{rd(), static_cast<unsigned int>(time(nullptr)), 
                                     static_cast<unsigned int>(clock()), 
                                     static_cast<unsigned int>(getpid())};
            static std::mt19937 gen(seed);
            return gen;
        }
        
        // Advanced iOS-specific anti-debug check using sysctl
        static bool CheckSysctlDebugger() {
            struct kinfo_proc info;
            size_t info_size = sizeof(info);
            int name[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
            
            if (sysctl(name, 4, &info, &info_size, nullptr, 0) == 0) {
                return ((info.kp_proc.p_flag & EXECUTOR_P_TRACED) != 0);
            }
            
            return false;
        }
        
        // Check if being debugged using all available iOS methods
        static bool IsBeingDebugged() {
            // Method 1: Use ptrace to deny debugger attachment
            // If ptrace returns error and errno is EPERM, a debugger is already attached
            errno = 0;
            ptrace(PTRACE_DENY_ATTACH, 0, 0, 0);
            if (errno == EPERM) {
                return true;
            }
            
            // Method 2: Check process info using sysctl
            if (CheckSysctlDebugger()) {
                return true;
            }
            
            // Method 3: Check for suspicious environment variables
            const char* debugEnvVars[] = {
                "DYLD_INSERT_LIBRARIES",
                "DYLD_FORCE_FLAT_NAMESPACE",
                "DYLD_PRINT_TO_FILE",
                "_MSSafeMode"
            };
            
            for (const auto& var : debugEnvVars) {
                if (getenv(var) != nullptr) {
                    return true;
                }
            }
            
            // Method 4: Check for suspicious loaded dylibs
            uint32_t count = _dyld_image_count();
            for (uint32_t i = 0; i < count; i++) {
                const char* name = _dyld_get_image_name(i);
                if (name) {
                    std::string imageName(name);
                    if (imageName.find("frida") != std::string::npos ||
                        imageName.find("cydia") != std::string::npos ||
                        imageName.find("substrate") != std::string::npos ||
                        imageName.find("cycript") != std::string::npos ||
                        imageName.find("Hook") != std::string::npos ||
                        imageName.find("Inject") != std::string::npos) {
                        return true;
                    }
                }
            }
            
            // Method 5: Check exception ports (Mach-based debuggers)
            mach_msg_type_number_t count5 = 0;
            exception_mask_t masks[EXC_TYPES_COUNT];
            mach_port_t ports[EXC_TYPES_COUNT];
            exception_behavior_t behaviors[EXC_TYPES_COUNT];
            thread_state_flavor_t flavors[EXC_TYPES_COUNT];
            
            if (task_get_exception_ports(mach_task_self(), EXC_MASK_ALL, masks, &count5, ports, behaviors, flavors) == KERN_SUCCESS) {
                for (mach_msg_type_number_t i = 0; i < count5; i++) {
                    if (ports[i] != MACH_PORT_NULL) {
                        // Exception port is set, could be a debugger
                        return true;
                    }
                }
            }
            
            return false;
        }
        
        // Detects timing anomalies that might indicate debugging
        static bool DetectTimingAnomalies() {
            std::lock_guard<std::mutex> lock(s_timingMutex);
            
            auto now = std::chrono::high_resolution_clock::now();
            
            if (s_lastCheckTime.time_since_epoch().count() > 0) {
                auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - s_lastCheckTime).count();
                
                // If the time between checks is suspiciously long, it might indicate a debugger
                // iOS debuggers typically cause significant timing delays
                if (elapsed > 2000) { // 2 seconds threshold for iOS (more sensitive)
                    s_lastCheckTime = now;
                    return true;
                }
            }
            
            s_lastCheckTime = now;
            
            // Additional iOS-specific timing check: CADisplayLink
            // Call through to Objective-C runtime for more accurate timing check
            static Class displayLinkClass = objc_getClass("CADisplayLink");
            static SEL createSel = sel_registerName("displayLinkWithTarget:selector:");
            static SEL invalidateSel = sel_registerName("invalidate");
            static SEL addToRunLoopSel = sel_registerName("addToRunLoop:forMode:");
            static SEL runLoopSel = sel_registerName("mainRunLoop");
            static SEL defaultModeSel = sel_registerName("defaultMode");
            
            if (displayLinkClass) {
                id runLoop = ((id (*)(Class, SEL))objc_msgSend)(objc_getClass("NSRunLoop"), runLoopSel);
                id defaultMode = ((id (*)(Class, SEL))objc_msgSend)(objc_getClass("NSRunLoopMode"), defaultModeSel);
                
                // Implementation would add more timing validation here with CADisplayLink
                // We don't implement full code to avoid issues with Objective-C runtime in cpp file
            }
            
            return false;
        }
        
        // Check for iOS debugger tools and modified system paths
        static bool DetectDebuggerTools() {
            for (const auto& path : s_debuggerPaths) {
                struct stat statbuf;
                if (stat(path.c_str(), &statbuf) == 0) {
                    return true;
                }
            }
            
            // Check if system is write-protected (non-jailbroken iOS devices have read-only system)
            const char* testPath = "/bin/test_write_permission";
            FILE* file = fopen(testPath, "w");
            if (file != nullptr) {
                fclose(file);
                unlink(testPath); // Clean up
                return true; // System shouldn't be writable
            }
            
            // Check for Cydia URL scheme
            // We'd need to call through to UIApplication, simplified here
            Class uiApplicationClass = objc_getClass("UIApplication");
            if (uiApplicationClass) {
                // We can't directly call methods, but would check for Cydia URL scheme here
                // canOpenURL: would be called with cydia:// URL to check
            }
            
            return false;
        }
        
        // Check for injected code segments
        static bool DetectCodeInjection() {
            uint32_t count = _dyld_image_count();
            
            // First, get list of legitimate iOS frameworks and our own code's path
            std::vector<std::string> legitimateFrameworks = {
                "/System/Library/",
                "/usr/lib/",
                "/Developer/"
            };
            
            // Get our app's bundle path to allow our own frameworks
            char selfPath[PATH_MAX];
            uint32_t selfPathSize = sizeof(selfPath);
            if (_NSGetExecutablePath(selfPath, &selfPathSize) == 0) {
                std::string appPath(selfPath);
                size_t lastSlash = appPath.find_last_of('/');
                if (lastSlash != std::string::npos) {
                    appPath = appPath.substr(0, lastSlash);
                    legitimateFrameworks.push_back(appPath);
                }
            }
            
            // Check each loaded dylib
            for (uint32_t i = 0; i < count; i++) {
                const char* name = _dyld_get_image_name(i);
                if (name) {
                    std::string imageName(name);
                    bool isLegitimate = false;
                    
                    // Check if this is a system framework or our own code
                    for (const auto& prefix : legitimateFrameworks) {
                        if (imageName.find(prefix) == 0) {
                            isLegitimate = true;
                            break;
                        }
                    }
                    
                    // Look for suspicious injected libraries
                    if (!isLegitimate) {
                        if (imageName.find("MobileSubstrate") != std::string::npos ||
                            imageName.find("TweakInject") != std::string::npos ||
                            imageName.find("libhooker") != std::string::npos ||
                            imageName.find("substitute") != std::string::npos) {
                            return true;
                        }
                    }
                }
            }
            
            return false;
        }
        
        // Apply code integrity checks continuously
        static void ApplyCodeIntegrityChecks() {
            std::thread([]{
                while (s_timingCheckActive) {
                    // Run all checks in random order
                    std::array<std::function<bool()>, 4> checks = {
                        IsBeingDebugged,
                        DetectTimingAnomalies,
                        DetectDebuggerTools,
                        DetectCodeInjection
                    };
                    
                    // Shuffle the checks for unpredictability
                    std::shuffle(checks.begin(), checks.end(), GetRNG());
                    
                    for (const auto& check : checks) {
                        if (check()) {
                            // Take evasive action
                            // We introduce variable timing and behavior to confuse analysis
                            std::uniform_int_distribution<> dist(10, 50);
                            std::this_thread::sleep_for(std::chrono::milliseconds(dist(GetRNG())));
                            
                            // Optional: more aggressive response for production
                            if (std::uniform_int_distribution<>(1, 100)(GetRNG()) <= 20) {
                                // Introduce subtle corruption to thwart debugging attempts
                                // This is more effective than crashing outright
                                volatile uint8_t* ptr = new uint8_t[16];
                                std::uniform_int_distribution<> dist(0, 255);
                                for (int i = 0; i < 16; i++) {
                                    ptr[i] = static_cast<uint8_t>(dist(GetRNG()));
                                }
                                // Leak the memory deliberately (subtle corruption)
                            }
                        }
                    }
                    
                    // Random sleep to make timing analysis harder
                    std::uniform_int_distribution<> dist(300, 800);
                    std::this_thread::sleep_for(std::chrono::milliseconds(dist(GetRNG())));
                }
            }).detach();
        }
        
    public:
        // Initialize anti-debugging measures
        static void Initialize() {
            s_timingCheckActive = true;
            s_lastCheckTime = std::chrono::high_resolution_clock::now();
            
            // Apply preventative anti-debug measure to block future debugger attachment
            ptrace(PTRACE_DENY_ATTACH, 0, 0, 0);
            
            // Start integrity checks in background
            ApplyCodeIntegrityChecks();
        }
        
        // Shutdown anti-debugging measures
        static void Shutdown() {
            s_timingCheckActive = false;
        }
        
        // Apply comprehensive anti-tampering measures
        static void ApplyAntiTamperingMeasures() {
            // Initialize if not already done
            static bool initialized = false;
            if (!initialized) {
                Initialize();
                initialized = true;
            }
            
            // Immediate checks using all detection methods
            if (IsBeingDebugged() || DetectTimingAnomalies() || 
                DetectDebuggerTools() || DetectCodeInjection()) {
                // Take immediate evasive action
                
                // 1. Introduce unpredictability
                std::uniform_int_distribution<> dist(20, 100);
                std::this_thread::sleep_for(std::chrono::milliseconds(dist(GetRNG())));
                
                // 2. Instead of backtrace, use direct stack pointer access
                // This is safer and more compatible with iOS restrictions
                uint32_t checksum = 0;
                uintptr_t sp = 0;
                
                // Get stack pointer - inline assembly is more reliable
                #if defined(__x86_64__) || defined(__i386__)
                    asm volatile("movq %%rsp, %0" : "=r" (sp));
                #elif defined(__arm64__) || defined(__aarch64__)
                    asm volatile("mov %0, sp" : "=r" (sp));
                #elif defined(__arm__)
                    asm volatile("mov %0, sp" : "=r" (sp));
                #endif
                
                // Use stack pointer as part of checksum
                checksum = (checksum * 31) + sp;
                
                // 3. Take action based on checksum anomalies
                if (checksum == 0) {
                    // Suspicious execution environment
                    std::uniform_int_distribution<> distLong(1000, 5000);
                    std::this_thread::sleep_for(std::chrono::milliseconds(distLong(GetRNG())));
                }
            }
            
            // Add junk code that makes static analysis harder
            if (false && IsBeingDebugged()) {
                volatile uint8_t* buffer = new uint8_t[1024];
                std::uniform_int_distribution<> dist(0, 255);
                for (int i = 0; i < 1024; i++) {
                    buffer[i] = dist(GetRNG());
                }
                delete[] buffer;
            }
            
            // Make function return address verification
            void* returnAddress = __builtin_return_address(0);
            if (returnAddress) {
                Dl_info info;
                if (dladdr(returnAddress, &info)) {
                    // Check if return address is from a known dylib
                    std::string dliName = info.dli_fname ? info.dli_fname : "";
                    if (dliName.find("libdyld.dylib") != std::string::npos ||
                        dliName.find("Foundation") != std::string::npos) {
                        // Normal execution path
                    } else if (dliName.find("CoreFoundation") == std::string::npos &&
                              dliName.find("UIKitCore") == std::string::npos) {
                        // Potential debugging or hooking framework
                        // Insert unpredictable behavior
                        std::uniform_int_distribution<> dist(10, 30);
                        std::this_thread::sleep_for(std::chrono::milliseconds(dist(GetRNG())));
                    }
                }
            }
        }
        
        // Check if the current environment is safe for execution
        static bool IsSafeEnvironment() {
            return !IsBeingDebugged() && 
                   !DetectTimingAnomalies() && 
                   !DetectDebuggerTools() && 
                   !DetectCodeInjection();
        }
    };
    
    // Initialize static members
    std::atomic<bool> AntiDebug::s_timingCheckActive(false);
    std::mutex AntiDebug::s_timingMutex;
    std::chrono::high_resolution_clock::time_point AntiDebug::s_lastCheckTime;
}
