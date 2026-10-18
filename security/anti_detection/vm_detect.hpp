#pragma once

// Standard C headers for compatibility
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <time.h>

// Standard C++ headers
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <cstdint>
#include <string>
#include <vector>
#include <unordered_set>
#include <unordered_map>
#include <algorithm>
#include <sstream>
#include <random>
#include <atomic>
#include <thread>
#include <ctime>
#include <chrono>
#include <mutex>
#include <memory>

// iOS-specific includes
#include <unistd.h>
#include <sys/sysctl.h>
#include <sys/stat.h>
#include <sys/utsname.h>
#include <sys/types.h>
#include <sys/mount.h> // For statfs
#include <dlfcn.h>
#include <mach/mach.h>
#include <mach/mach_host.h>
#include <mach/vm_statistics.h>
#include <mach-o/dyld.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>

namespace AntiDetection {
    
    /**
     * @class VMDetection
     * @brief Advanced iOS virtual machine and simulator detection
     * 
     * This class implements multiple detection techniques to identify if the code
     * is running in a simulator, emulator, or other virtualized environment.
     * Optimized specifically for iOS with multiple layers of detection.
     */
    class VMDetection {
    private:
        // Mutex for thread safety
        static std::mutex s_mutex;
        
        // Counter for VM detection attempts
        static std::atomic<int> s_detectionAttempts;
        
        // Flag for VM detection
        static std::atomic<bool> s_vmDetected;
        
        // Anti-fingerprinting - slightly randomize responses to make detection harder
        static bool s_useAntiFingerprinting;
        
        // Simulator/emulator files and paths to check
        static const inline std::vector<std::string> s_simulatorPaths = {
            "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform",
            "/Library/Developer/CoreSimulator",
            "/Library/Developer/CommandLineTools",
            "/opt/procursus",
            "/.SIMULATOR_DEVICE_NAME",
            "/.SIMULATOR_VERSIONS",
            "/opt/simverify",
            "/usr/share/xcode",
            "/var/db/xcode_select_link",
            "/var/mobile/Library/Caches/com.apple.dyld/dyld_shared_cache_x86_64h"
        };
        
        // Environment variables that indicate simulators
        static const inline std::vector<std::string> s_simulatorEnvVars = {
            "SIMULATOR_DEVICE_NAME",
            "SIMULATOR_HOST_HOME",
            "SIMULATOR_RUNTIME_VERSION",
            "SIMULATOR_UDID",
            "SIMULATOR_LOG_ROOT",
            "SIMULATOR_SHARED_RESOURCES_DIRECTORY",
            "SIMULATOR_VERSION_INFO",
            "DYLD_INSERT_LIBRARIES",
            "DYLD_FRAMEWORK_PATH",
            "DYLD_ROOT_PATH"
        };
        
        // Non-ARM device models (simulator models)
        static const inline std::unordered_set<std::string> s_nonArmModels = {
            "x86_64",
            "i386",
            "i686",
            "simulator",
            "macos",
            "osx"
        };
        
        // Expected performance characteristics
        struct PerformanceMetrics {
            uint64_t minRamMB;         // Minimum expected RAM (MB)
            uint64_t minFreeDiskMB;    // Minimum expected free disk space (MB)
            float minClockSpeedGhz;    // Minimum expected CPU clock speed (GHz)
            int minProcessorCount;     // Minimum expected processor count
            
            PerformanceMetrics() 
                : minRamMB(1024),      // 1GB RAM minimum for modern iOS devices
                  minFreeDiskMB(1024), // 1GB free disk space minimum
                  minClockSpeedGhz(1.0f), // 1GHz clock speed minimum
                  minProcessorCount(2)  // At least 2 cores
            {}
        };
        
        // Random number generator
        static std::mt19937& GetRNG() {
            static std::random_device rd;
            static std::mt19937 rng(rd());
            return rng;
        }
        
        // Check if a file exists
        static bool FileExists(const std::string& filename) {
            struct stat buffer;
            return (stat(filename.c_str(), &buffer) == 0);
        }
        
        // Get processor name (if available)
        static std::string GetProcessorName() {
            // On iOS, we can use sysctl to get processor info
            char buffer[256];
            size_t size = sizeof(buffer);
            if (sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nullptr, 0) == 0) {
                return std::string(buffer);
            }
            return "";
        }
        
        // Get processor speed in Hz
        static uint64_t GetProcessorSpeed() {
            uint64_t frequency = 0;
            size_t size = sizeof(frequency);
            if (sysctlbyname("hw.cpufrequency", &frequency, &size, nullptr, 0) != 0) {
                // Try legacy method if the first failed
                if (sysctlbyname("hw.cpufrequency_max", &frequency, &size, nullptr, 0) != 0) {
                    // Return a default if all methods fail
                    return 0;
                }
            }
            return frequency;
        }
        
        // Get performance metrics
        static bool CheckPerformanceMetrics(const PerformanceMetrics& expected) {
            // Get system RAM
            uint64_t memsize = 0;
            size_t size = sizeof(memsize);
            if (sysctlbyname("hw.memsize", &memsize, &size, nullptr, 0) == 0) {
                uint64_t ramMB = memsize / (1024 * 1024);
                if (ramMB < expected.minRamMB) {
                    return true; // Likely a VM with low RAM allocation
                }
            }
            
            // Get processor count
            int cpuCount = 0;
            size = sizeof(cpuCount);
            if (sysctlbyname("hw.ncpu", &cpuCount, &size, nullptr, 0) == 0) {
                if (cpuCount < expected.minProcessorCount) {
                    return true; // Likely a VM with few CPUs
                }
            }
            
            // Get processor speed
            uint64_t cpuFreq = GetProcessorSpeed();
            if (cpuFreq > 0) {
                float cpuGhz = (float)cpuFreq / 1000000000.0f;
                if (cpuGhz < expected.minClockSpeedGhz) {
                    return true; // Likely a VM with slow CPU
                }
            }
            
            // Check free disk space - simplify for iOS
            struct statfs stats;
            if (statfs("/", &stats) == 0) {
                uint64_t freeDiskMB = (uint64_t)stats.f_bsize * (uint64_t)stats.f_bfree / (1024 * 1024);
                if (freeDiskMB < expected.minFreeDiskMB) {
                    return true; // Very low free space, suspicious
                }
            }
            
            return false;
        }
        
        // Check for iOS simulator-specific characteristics
        static bool DetectIOSSimulator() {
            // Counter for detection flags
            int detectionCount = 0;
            
            // 1. Check system architecture
            struct utsname systemInfo;
            if (uname(&systemInfo) == 0) {
                std::string machine = systemInfo.machine;
                std::transform(machine.begin(), machine.end(), machine.begin(), ::tolower);
                
                for (const auto& model : s_nonArmModels) {
                    if (machine.find(model) != std::string::npos) {
                        return true; // Non-ARM architecture detected
                    }
                }
            }
            
            // 2. Check model identifier
            char model[256];
            size_t len = sizeof(model);
            int mib[2] = { CTL_HW, HW_MODEL };
            if (sysctl(mib, 2, model, &len, NULL, 0) == 0) {
                if (strstr(model, "Simulator") != nullptr) {
                    return true;
                }
            }
            
            // 3. Check simulator environment variables
            for (const auto& envVar : s_simulatorEnvVars) {
                if (getenv(envVar.c_str()) != nullptr) {
                    detectionCount++;
                    if (detectionCount >= 2) return true; // Multiple env vars detected
                }
            }
            
            // 4. Check simulator-specific files
            for (const auto& path : s_simulatorPaths) {
                if (FileExists(path)) {
                    detectionCount++;
                    if (detectionCount >= 2) return true; // Multiple indicators detected
                }
            }
            
            // 5. Check for simulator-specific bundles using ObjC runtime
            Class nsBundle = objc_getClass("NSBundle");
            if (nsBundle) {
                SEL mainBundleSel = sel_registerName("mainBundle");
                SEL bundleIdSel = sel_registerName("bundleIdentifier");
                
                // Call [NSBundle mainBundle]
                id (*mainBundleFunc)(Class, SEL) = (id (*)(Class, SEL))objc_msgSend;
                id mainBundle = mainBundleFunc(nsBundle, mainBundleSel);
                
                if (mainBundle) {
                    // Call bundleIdentifier on the main bundle
                    id (*bundleIdFunc)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
                    id bundleId = bundleIdFunc(mainBundle, bundleIdSel);
                    
                    // Check if this is a simulator bundle
                    if (bundleId) {
                        const char* bundleIdStr = ((const char* (*)(id, SEL))objc_msgSend)(bundleId, sel_registerName("UTF8String"));
                        if (bundleIdStr && (
                            strstr(bundleIdStr, "Simulator") != nullptr ||
                            strstr(bundleIdStr, "iphonesimulator") != nullptr ||
                            strstr(bundleIdStr, "simulator") != nullptr)) {
                            return true;
                        }
                    }
                }
            }
            
            // 6. Check for suspicious performance metrics
            PerformanceMetrics metrics;
            if (CheckPerformanceMetrics(metrics)) {
                detectionCount++;
            }
            
            // 7. Check UIDevice current model (requires Objective-C runtime)
            Class uiDevice = objc_getClass("UIDevice");
            if (uiDevice) {
                // Get [UIDevice currentDevice]
                SEL currentDeviceSel = sel_registerName("currentDevice");
                id (*currentDeviceFunc)(Class, SEL) = (id (*)(Class, SEL))objc_msgSend;
                id device = currentDeviceFunc(uiDevice, currentDeviceSel);
                
                if (device) {
                    // Get device model
                    SEL modelSel = sel_registerName("model");
                    id (*modelFunc)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
                    id modelObj = modelFunc(device, modelSel);
                    
                    if (modelObj) {
                        // Convert to string and check
                        const char* modelStr = ((const char* (*)(id, SEL))objc_msgSend)(modelObj, sel_registerName("UTF8String"));
                        if (modelStr && strstr(modelStr, "Simulator") != nullptr) {
                            return true;
                        }
                    }
                }
            }
            
            // Check for combined indicators that might suggest a simulator
            return detectionCount >= 3; // Multiple minor indicators present
        }
        
        // Check for hardware anomalies that might indicate a VM
        static bool DetectHardwareAnomalies() {
            // Check for hardware MAC address anomalies - VMs often have specific patterns
            struct ifaddrs* interfaces = nullptr;
            
            if (getifaddrs(&interfaces) == 0) {
                bool hasRealMAC = false;
                bool hasVMMAC = false;
                
                // Common VM MAC address prefixes
                std::vector<std::string> vmMacPrefixes = {
                    "00:16:3e",  // Xen
                    "00:50:56",  // VMware
                    "00:1C:42",  // Parallels
                    "00:0C:29",  // VMware
                    "00:05:69",  // VMware
                    "00:1f:16",  // VMware
                    "00:21:F6",  // Virtual Iron
                    "00:14:4F",  // Oracle VM
                    "08:00:27",  // VirtualBox
                };
                
                for (struct ifaddrs* interface = interfaces; interface != nullptr; interface = interface->ifa_next) {
                    if (interface->ifa_addr && interface->ifa_addr->sa_family == AF_LINK) {
                        if (!(interface->ifa_flags & IFF_LOOPBACK) && (interface->ifa_flags & IFF_UP)) {
                            // Get MAC address
                            struct sockaddr_dl* sdl = (struct sockaddr_dl*)interface->ifa_addr;
                            unsigned char* macAddress = (unsigned char*)LLADDR(sdl);
                            
                            // Convert to string format
                            char macStr[18];
                            snprintf(macStr, sizeof(macStr), "%02x:%02x:%02x:%02x:%02x:%02x",
                                     macAddress[0], macAddress[1], macAddress[2],
                                     macAddress[3], macAddress[4], macAddress[5]);
                            
                            std::string macString(macStr);
                            
                            // Check for VM MAC prefixes
                            for (const auto& prefix : vmMacPrefixes) {
                                if (macString.substr(0, prefix.length()) == prefix) {
                                    hasVMMAC = true;
                                    break;
                                }
                            }
                            
                            // Real devices have at least one non-VM MAC
                            if (!hasVMMAC) {
                                hasRealMAC = true;
                            }
                        }
                    }
                }
                
                freeifaddrs(interfaces);
                
                // If we found a VM MAC and no real MACs, it's likely a VM
                if (hasVMMAC && !hasRealMAC) {
                    return true;
                }
            }
            
            // Check for typical iOS device sensors using Objective-C runtime
            Class cmMotionManager = objc_getClass("CMMotionManager");
            if (cmMotionManager) {
                // Create a motion manager instance
                id (*allocFunc)(Class, SEL) = (id (*)(Class, SEL))objc_msgSend;
                id instance = allocFunc(cmMotionManager, sel_registerName("alloc"));
                
                if (instance) {
                    id (*initFunc)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
                    id manager = initFunc(instance, sel_registerName("init"));
                    
                    if (manager) {
                        // Check for accelerometer
                        SEL accelSel = sel_registerName("isAccelerometerAvailable");
                        BOOL (*accelAvailFunc)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
                        bool accelAvailable = accelAvailFunc(manager, accelSel);
                        
                        // Check for gyroscope
                        SEL gyroSel = sel_registerName("isGyroAvailable");
                        BOOL (*gyroAvailFunc)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
                        bool gyroAvailable = gyroAvailFunc(manager, gyroSel);
                        
                        // Release the manager
                        SEL releaseSel = sel_registerName("release");
                        void (*releaseFunc)(id, SEL) = (void (*)(id, SEL))objc_msgSend;
                        releaseFunc(manager, releaseSel);
                        
                        // Most simulators don't properly simulate sensors
                        if (!accelAvailable && !gyroAvailable) {
                            return true;
                        }
                    }
                }
            }
            
            return false;
        }
        
        // Check for VM indicators in runtime behavior
        static bool DetectRuntimeBehavior() {
            // Check memory page sizes - VMs often have different page sizes
            vm_size_t pageSize;
            int mib[2] = { CTL_HW, HW_PAGESIZE };
            size_t length = sizeof(pageSize);
            
            if (sysctl(mib, 2, &pageSize, &length, NULL, 0) == 0) {
                // Most iOS devices use 16KB or 4KB page sizes
                // Simulators might use different values based on host
                if (pageSize != 4096 && pageSize != 16384) {
                    return true;
                }
            }
            
            // Check CPU timing consistency - VMs often have inconsistent timing
            // Measure the time it takes to perform a CPU-intensive operation
            const int iterations = 1000000;
            auto start = std::chrono::high_resolution_clock::now();
            
            volatile uint64_t result = 0;
            for (int i = 0; i < iterations; i++) {
                result += i * i;
            }
            
            auto end = std::chrono::high_resolution_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();
            
            // Calculate operations per microsecond
            double opsPerMicrosecond = static_cast<double>(iterations) / duration;
            
            // Real devices should have relatively consistent performance
            // Low or erratic performance may indicate a VM
            if (opsPerMicrosecond < 10.0) { // This threshold may need adjustment
                return true;
            }
            
            return false;
        }
        
    public:
        // Initialize with anti-fingerprinting option
        static void Initialize(bool useAntiFingerprinting = false) {
            std::lock_guard<std::mutex> lock(s_mutex);
            s_useAntiFingerprinting = useAntiFingerprinting;
            s_detectionAttempts = 0;
            s_vmDetected = false;
        }
        
        // Main VM detection function that combines multiple techniques
        static bool DetectVM() {
            // If we've already detected a VM, return the cached result
            if (s_vmDetected) {
                return true;
            }
            
            // Increment detection attempts
            s_detectionAttempts++;
            
            // Anti-fingerprinting: occasionally return false to confuse analysis
            if (s_useAntiFingerprinting) {
                std::uniform_int_distribution<> dist(1, 100);
                if (s_detectionAttempts > 3 && dist(GetRNG()) <= 5) {
                    return false;
                }
            }
            
            // Use multiple detection methods
            bool isSimulator = DetectIOSSimulator();
            
            // Only run additional checks if simulator check is negative
            bool hasHardwareAnomalies = isSimulator ? false : DetectHardwareAnomalies();
            bool hasRuntimeAnomalies = isSimulator ? false : DetectRuntimeBehavior();
            
            // Check if any detection method returned true
            bool result = isSimulator || hasHardwareAnomalies || hasRuntimeAnomalies;
            
            // Cache positive results
            if (result) {
                s_vmDetected = true;
            }
            
            return result;
        }
        
        // Take appropriate actions based on VM detection
        static void HandleVMDetection() {
            if (DetectVM()) {
                // Strategy: Make the executor subtly less effective rather than outright failing
                
                // 1. Introduce subtle delays
                std::uniform_int_distribution<> delayDist(50, 200);
                std::this_thread::sleep_for(std::chrono::milliseconds(delayDist(GetRNG())));
                
                // 2. Add random memory usage to consume resources
                std::uniform_int_distribution<> memDist(1, 10);
                int memBlocks = memDist(GetRNG());
                std::vector<std::vector<uint8_t>> memoryBlocks;
                
                for (int i = 0; i < memBlocks; i++) {
                    std::vector<uint8_t> block(1024 * 1024); // 1MB blocks
                    memoryBlocks.push_back(std::move(block));
                }
                
                // 3. Start a background thread with random CPU usage
                static std::atomic<bool> shouldRun(true);
                static std::thread cpuThread;
                
                if (!cpuThread.joinable()) {
                    cpuThread = std::thread([]() {
                        std::uniform_int_distribution<> workDist(10, 100);
                        std::uniform_int_distribution<> sleepDist(50, 500);
                        
                        while (shouldRun) {
                            // Do some CPU work
                            int work = workDist(GetRNG());
                            volatile uint64_t result = 0;
                            for (int i = 0; i < work * 100000; i++) {
                                result += i * i;
                            }
                            
                            // Sleep a bit
                            std::this_thread::sleep_for(std::chrono::milliseconds(sleepDist(GetRNG())));
                        }
                    });
                }
            }
        }
        
        // Clean up resources
        static void Shutdown() {
            static std::atomic<bool>& shouldRun = *reinterpret_cast<std::atomic<bool>*>(
                dlsym(RTLD_DEFAULT, "shouldRun"));
            
            if (shouldRun) {
                shouldRun = false;
                
                // Wait for thread to join
                static std::thread& cpuThread = *reinterpret_cast<std::thread*>(
                    dlsym(RTLD_DEFAULT, "cpuThread"));
                
                if (cpuThread.joinable()) {
                    cpuThread.join();
                }
            }
        }
    };
    
    // Initialize static members
    std::mutex VMDetection::s_mutex;
    std::atomic<int> VMDetection::s_detectionAttempts(0);
    std::atomic<bool> VMDetection::s_vmDetected(false);
    bool VMDetection::s_useAntiFingerprinting = false;
}
