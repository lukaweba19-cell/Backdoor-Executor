// Method swizzling for Objective-C runtime
#pragma once

#include "objc_isolation.h"

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#endif

namespace iOS {
    // Method swizzling utilities for Objective-C
    class MethodSwizzling {
    public:
        // Swizzle class methods
        static bool SwizzleClassMethod(Class cls, SEL originalSelector, SEL swizzledSelector) {
            #ifdef __OBJC__
            Method originalMethod = class_getClassMethod(cls, originalSelector);
            Method swizzledMethod = class_getClassMethod(cls, swizzledSelector);
            
            if (!originalMethod || !swizzledMethod) {
                return false;
            }
            
            // Get meta class which contains class methods
            Class metaClass = objc_getMetaClass(class_getName(cls));
            
            // Add the method and swizzle
            if (class_addMethod(metaClass, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
                class_replaceMethod(metaClass, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
            } else {
                method_exchangeImplementations(originalMethod, swizzledMethod);
            }
            
            return true;
            #else
            // Not implemented for non-Objective-C
            return false;
            #endif
        }
        
        // Swizzle instance methods
        static bool SwizzleInstanceMethod(Class cls, SEL originalSelector, SEL swizzledSelector) {
            #ifdef __OBJC__
            Method originalMethod = class_getInstanceMethod(cls, originalSelector);
            Method swizzledMethod = class_getInstanceMethod(cls, swizzledSelector);
            
            if (!originalMethod || !swizzledMethod) {
                return false;
            }
            
            // Add the method and swizzle
            if (class_addMethod(cls, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
                class_replaceMethod(cls, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
            } else {
                method_exchangeImplementations(originalMethod, swizzledMethod);
            }
            
            return true;
            #else
            // Not implemented for non-Objective-C
            return false;
            #endif
        }
    };
}
