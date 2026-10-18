// iOS implementation compatibility header
// This handles the bridge between C++ and Objective-C

#pragma once

#include <cstdint>
#include <string>

#ifdef __APPLE__
#include <TargetConditionals.h>

// Only include UIKit in Objective-C context - not in pure C++
#ifdef __OBJC__
    // iOS specific includes
    #if TARGET_OS_IPHONE
    #import <UIKit/UIKit.h>
    #import <Foundation/Foundation.h>
    #endif

    // Mach-specific includes
    #include <mach/mach.h>
    #include <mach/task.h>
    #include <mach/mach_init.h>
    #include <mach/mach_types.h>
    #include <mach/vm_map.h>
    #include <mach/vm_region.h>
    #include <mach/host_priv.h>
    #include <sys/types.h>
    #include <sys/sysctl.h>
    #include <mach/mach_time.h>
    #include <dlfcn.h>
    #include <mach-o/dyld.h>
    #include <mach-o/loader.h>
    #include <mach-o/nlist.h>
    #include <objc/runtime.h>
    #include <objc/message.h>
#else
    // For C++ code, we just need the mach headers without the Objective-C stuff
    #include "mach_compat.h"
#endif

#endif // __APPLE__

// Define common types and macros for cross-platform compatibility
#ifdef __cplusplus
extern "C" {
#endif

// Define platform-specific types
typedef unsigned char byte;
typedef unsigned int uint;

#ifdef __cplusplus
}
#endif
