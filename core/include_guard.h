// include_guard.h - Central include file for all platform-specific headers
#pragma once

// Include utility macros first (pure C++ code)
#include "utility.h"

// Platform-specific includes
#ifdef __APPLE__
    // Include the objc_isolation header with the correct path based on the build system
    // This header handles the Objective-C / C++ boundary correctly
    #include "objc_isolation.h"
#endif
