// ios_compat.h - iOS compatibility header for cross-platform support
#pragma once

// Include system headers based on platform
#ifdef __APPLE__
#include <TargetConditionals.h>

// iOS specific includes
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Security/Security.h>
#else
// macOS specific includes if needed
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#endif

// Common includes for all Apple platforms
#include <sys/types.h>
#include <sys/sysctl.h>
#include <mach/mach.h>
#include <mach/mach_types.h>
#include <mach/mach_init.h>
// Exclude mach_vm.h which is unsupported on iOS
#include <mach/vm_map.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#endif

// Define common types and macros for cross-platform compatibility
#ifdef __cplusplus
extern "C" {
#endif

// iOS version detection macros
#if defined(__APPLE__)
#define IOS_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define IOS_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define IOS_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define IOS_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define IOS_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)
#else
// Stub implementations for non-Apple platforms
#define IOS_VERSION_EQUAL_TO(v)                  (0)
#define IOS_VERSION_GREATER_THAN(v)              (0)
#define IOS_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  (0)
#define IOS_VERSION_LESS_THAN(v)                 (0)
#define IOS_VERSION_LESS_THAN_OR_EQUAL_TO(v)     (0)
#endif

// Device type detection
#if defined(__APPLE__) && TARGET_OS_IPHONE
#define IS_IPHONE (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
#define IS_IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)

// Screen size and orientation utilities
#define SCREEN_WIDTH ([[UIScreen mainScreen] bounds].size.width)
#define SCREEN_HEIGHT ([[UIScreen mainScreen] bounds].size.height)
#define IS_LANDSCAPE UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)
#define IS_PORTRAIT UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)

// Device specific detection
#define IS_IPHONE_X \
    (IS_IPHONE && \
    (SCREEN_HEIGHT == 812.0f || SCREEN_HEIGHT == 896.0f || \
     SCREEN_HEIGHT >= 844.0f))

#else
// Stub implementations for non-iOS platforms
#define IS_IPHONE (0)
#define IS_IPAD (0)
#define SCREEN_WIDTH (0)
#define SCREEN_HEIGHT (0)
#define IS_LANDSCAPE (0)
#define IS_PORTRAIT (0)
#define IS_IPHONE_X (0)
#endif

// Safe area insets for modern iOS devices (iPhone X and newer)
#if defined(__APPLE__) && TARGET_OS_IPHONE
#define SAFE_AREA_INSET_TOP (IS_IPHONE_X ? 44.0f : 20.0f)
#define SAFE_AREA_INSET_BOTTOM (IS_IPHONE_X ? 34.0f : 0.0f)
#else
#define SAFE_AREA_INSET_TOP (0)
#define SAFE_AREA_INSET_BOTTOM (0)
#endif

// Memory management utilities
#if defined(__APPLE__)
#define SAFE_RELEASE(obj) { if (obj) { [obj release]; obj = nil; } }
#define SAFE_RELEASE_CF(ref) { if (ref) { CFRelease(ref); ref = NULL; } }
#else
#define SAFE_RELEASE(obj)
#define SAFE_RELEASE_CF(ref)
#endif

// Common utility macros
#define UNUSED_PARAM(x) (void)(x)
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)
#define CONCAT(a, b) a##b

#ifdef __cplusplus
}
#endif
