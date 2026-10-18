// objc_isolation.h - Isolation layer for Objective-C and C++ interoperability
#pragma once

// Standard library includes
#include <string>
#include <vector>
#include <map>

// Properly guard Objective-C code
#ifdef __APPLE__
    #ifdef __OBJC__
        // Include iOS compatibility header for Objective-C code
        #import <Foundation/Foundation.h>
        #if TARGET_OS_IPHONE
            #import <UIKit/UIKit.h>
        #endif
    #else
        // Forward declare Objective-C classes for C++ code
        #ifdef __cplusplus
            // Forward declarations of common Objective-C types
            typedef struct objc_class *Class;
            typedef struct objc_object *id;
            typedef struct objc_selector *SEL;
            #if !defined(__OBJC__)
            typedef bool BOOL;
            #endif
            
            // Common Foundation types for C++ code
            typedef const void* CFTypeRef;
            typedef const struct __CFString* CFStringRef;
            typedef const struct __CFDictionary* CFDictionaryRef;
            typedef const struct __CFArray* CFArrayRef;
            
            // Forward declarations of Objective-C classes
            #define OBJC_CLASS(name) class name;
            OBJC_CLASS(UIView)
            OBJC_CLASS(UIWindow)
            OBJC_CLASS(UIButton)
            OBJC_CLASS(UIViewController)
            OBJC_CLASS(UIApplication)
            OBJC_CLASS(UIControl)
            OBJC_CLASS(UILabel)
            OBJC_CLASS(UITextField)
            OBJC_CLASS(UITextView)
            OBJC_CLASS(UITableView)
            OBJC_CLASS(UIScrollView)
            OBJC_CLASS(UIImage)
            OBJC_CLASS(UIImageView)
            OBJC_CLASS(UIColor)
            OBJC_CLASS(UIFont)
            OBJC_CLASS(UIGestureRecognizer)
            OBJC_CLASS(UIAlertController)
            OBJC_CLASS(UIAlertAction)
            OBJC_CLASS(UIActivityIndicatorView)
            OBJC_CLASS(UISwitch)
            OBJC_CLASS(CALayer)
            OBJC_CLASS(NSString)
            OBJC_CLASS(NSArray)
            OBJC_CLASS(NSMutableArray)
            OBJC_CLASS(NSDictionary)
            OBJC_CLASS(NSMutableDictionary)
            OBJC_CLASS(NSData)
            OBJC_CLASS(NSMutableData)
            OBJC_CLASS(NSNumber)
            OBJC_CLASS(NSObject)
            OBJC_CLASS(NSError)
            OBJC_CLASS(NSTimer)
            OBJC_CLASS(NSThread)
            OBJC_CLASS(NSDate)
            OBJC_CLASS(NSURLSession)
            OBJC_CLASS(NSURLSessionDataTask)
            OBJC_CLASS(NSURLRequest)
            OBJC_CLASS(NSMutableURLRequest)
            OBJC_CLASS(NSUserDefaults)
            OBJC_CLASS(NSNotificationCenter)
            OBJC_CLASS(NSCache)
            OBJC_CLASS(NSFileManager)
            OBJC_CLASS(NSBundle)
            OBJC_CLASS(NSRunLoop)
            #undef OBJC_CLASS
        #endif // __cplusplus
    #endif // __OBJC__
#endif // __APPLE__

// Common definitions that work in all contexts
#ifdef __cplusplus
extern "C" {
#endif

// Error codes
typedef enum {
    kErrorNone = 0,
    kErrorGeneric = -1,
    kErrorInvalidArgument = -2,
    kErrorMemoryAllocation = -3,
    kErrorNotImplemented = -4,
    kErrorNotSupported = -5,
    kErrorPermissionDenied = -6,
    kErrorTimeout = -7,
    kErrorNotFound = -8,
    kErrorAlreadyExists = -9,
    kErrorNetworkFailure = -10
} ErrorCode;

#ifdef __cplusplus
}
#endif
