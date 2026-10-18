// utility.h - Utility macros and functions for C++ code
#pragma once

// Platform detection
#ifdef __APPLE__
    #include <TargetConditionals.h>
    #define PLATFORM_APPLE 1
    #if TARGET_OS_IPHONE
        #define PLATFORM_IOS 1
        #define PLATFORM_MACOS 0
    #else
        #define PLATFORM_IOS 0
        #define PLATFORM_MACOS 1
    #endif
#else
    #define PLATFORM_APPLE 0
    #define PLATFORM_IOS 0
    #define PLATFORM_MACOS 0
#endif

// Utility macros
#define UNUSED_PARAM(x) (void)(x)
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)
#define CONCAT(a, b) a##b

// Bit manipulation
#define BIT(x) (1ULL << (x))
#define SET_BIT(value, bit) ((value) |= BIT(bit))
#define CLEAR_BIT(value, bit) ((value) &= ~BIT(bit))
#define TOGGLE_BIT(value, bit) ((value) ^= BIT(bit))
#define IS_BIT_SET(value, bit) (((value) & BIT(bit)) != 0)
