#include "hooks.hpp"
#include "dobby_wrapper.h"

#include <iostream>

namespace Hooks {

std::unordered_map<void*, void*> HookEngine::s_hookedFunctions;
std::mutex HookEngine::s_hookMutex;

#ifdef __APPLE__
std::map<std::string, ObjcMethodHook::HookedMethodInfo> ObjcMethodHook::s_hookedMethods;
std::mutex ObjcMethodHook::s_methodMutex;
#endif

bool HookEngine::Initialize() {
    return true;
}

bool HookEngine::RegisterHook(void* targetAddr, void* hookAddr, void** originalAddr) {
    if (!targetAddr || !hookAddr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(s_hookMutex);
    if (s_hookedFunctions.find(targetAddr) != s_hookedFunctions.end()) {
        return false;
    }

    void* original = nullptr;
    if (!Implementation::HookFunction(targetAddr, hookAddr, &original)) {
        return false;
    }

    if (originalAddr) {
        *originalAddr = original;
    }
    s_hookedFunctions[targetAddr] = original; // store original for restore
    return true;
}

bool HookEngine::UnregisterHook(void* targetAddr) {
    if (!targetAddr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(s_hookMutex);
    auto it = s_hookedFunctions.find(targetAddr);
    if (it == s_hookedFunctions.end()) {
        return false;
    }

    if (!Implementation::UnhookFunction(targetAddr)) {
        return false;
    }

    s_hookedFunctions.erase(it);
    return true;
}

void HookEngine::ClearAllHooks() {
    std::lock_guard<std::mutex> lock(s_hookMutex);
    for (auto& pair : s_hookedFunctions) {
        Implementation::UnhookFunction(pair.first);
    }
    s_hookedFunctions.clear();
}

namespace Implementation {

bool HookFunction(void* target, void* replacement, void** original) {
    if (!target || !replacement) {
        return false;
    }
#if defined(USE_DOBBY) && USE_DOBBY
    void* orig = DobbyWrapper::Hook(target, replacement);
    if (!orig) {
        return false;
    }
    if (original) {
        *original = orig;
    }
    return true;
#else
    (void)target;
    (void)replacement;
    (void)original;
    return false;
#endif
}

bool UnhookFunction(void* target) {
    if (!target) {
        return false;
    }
#if defined(USE_DOBBY) && USE_DOBBY
    return DobbyWrapper::Unhook(target);
#else
    (void)target;
    return false;
#endif
}

} // namespace Implementation

#ifdef __APPLE__

bool ObjcMethodHook::HookMethod(const std::string& className,
                                const std::string& selectorName,
                                void* replacementFn,
                                void** originalFn) {
    if (className.empty() || selectorName.empty() || !replacementFn) {
        return false;
    }

    std::lock_guard<std::mutex> lock(s_methodMutex);

    Class cls = objc_getClass(className.c_str());
    if (!cls) {
        return false;
    }

    SEL selector = sel_registerName(selectorName.c_str());
    if (!selector) {
        return false;
    }

    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        // Try class method
        method = class_getClassMethod(cls, selector);
        if (!method) {
            return false;
        }
    }

    const std::string key = className + "::" + selectorName;
    if (s_hookedMethods.find(key) != s_hookedMethods.end()) {
        // Already hooked — still return original if requested
        if (originalFn) {
            *originalFn = s_hookedMethods[key].originalIMP;
        }
        return true;
    }

    IMP originalIMP = method_getImplementation(method);
    if (!originalIMP) {
        return false;
    }

    method_setImplementation(method, reinterpret_cast<IMP>(replacementFn));

    HookedMethodInfo info;
    info.cls = cls;
    info.selector = selector;
    info.originalIMP = reinterpret_cast<HookIMP>(originalIMP);
    s_hookedMethods[key] = info;

    if (originalFn) {
        *originalFn = reinterpret_cast<void*>(originalIMP);
    }
    return true;
}

bool ObjcMethodHook::UnhookMethod(const std::string& className,
                                  const std::string& selectorName) {
    std::lock_guard<std::mutex> lock(s_methodMutex);

    const std::string key = className + "::" + selectorName;
    auto it = s_hookedMethods.find(key);
    if (it == s_hookedMethods.end()) {
        return false;
    }

    Class cls = it->second.cls;
    SEL selector = it->second.selector;
    IMP originalIMP = reinterpret_cast<IMP>(it->second.originalIMP);

    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        method = class_getClassMethod(cls, selector);
    }
    if (!method) {
        s_hookedMethods.erase(it);
        return false;
    }

    method_setImplementation(method, originalIMP);
    s_hookedMethods.erase(it);
    return true;
}

void ObjcMethodHook::ClearAllHooks() {
    std::lock_guard<std::mutex> lock(s_methodMutex);

    for (auto it = s_hookedMethods.begin(); it != s_hookedMethods.end(); ) {
        Class cls = it->second.cls;
        SEL selector = it->second.selector;
        IMP originalIMP = reinterpret_cast<IMP>(it->second.originalIMP);

        Method method = class_getInstanceMethod(cls, selector);
        if (!method) {
            method = class_getClassMethod(cls, selector);
        }
        if (method) {
            method_setImplementation(method, originalIMP);
        }
        it = s_hookedMethods.erase(it);
    }
}

#endif // __APPLE__

} // namespace Hooks
