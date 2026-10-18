#include "ios_compat.h"
#include "GameDetector.h"
#include "MemoryAccess.h"
#include "PatternScanner.h"
#include <chrono>
#include <iostream>
#include <fstream>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <cctype>

// UIKit / Foundation via runtime to avoid hard link issues in all build contexts
static id GetSharedApplication() {
    Class UIApp = objc_getClass("UIApplication");
    if (!UIApp) return nil;
    return ((id(*)(Class, SEL))objc_msgSend)(UIApp, sel_registerName("sharedApplication"));
}

static std::string NSStringToStd(id nsstr) {
    if (!nsstr) return "";
    const char* c = ((const char*(*)(id, SEL))objc_msgSend)(nsstr, sel_registerName("UTF8String"));
    return c ? std::string(c) : "";
}

namespace iOS {

static std::function<void(GameState)> s_stateCallback;

GameDetector::GameDetector()
    : m_currentState(GameState::Unknown),
      m_running(false),
      m_lastChecked(0),
      m_lastGameJoinTime(0) {
    m_offsets = {};
}

GameDetector::~GameDetector() {
    Stop();
}

bool GameDetector::Start() {
    if (m_running.load()) return true;
    if (!InitializeMemoryAccess()) {
        std::cerr << "GameDetector: memory init failed (continuing with limited detection)\n";
    }
    UpdateRobloxOffsets();
    m_running.store(true);
    m_workerThread = std::thread([this]() { WorkerThread(); });
    std::cout << "GameDetector: started\n";
    return true;
}

void GameDetector::Stop() {
    if (!m_running.load()) return;
    m_running.store(false);
    if (m_workerThread.joinable()) m_workerThread.join();
}

void GameDetector::WorkerThread() {
    while (m_running.load()) {
        UpdateGameState();
        m_lastChecked.store(
            (uint64_t)std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::system_clock::now().time_since_epoch()).count());
        std::this_thread::sleep_for(std::chrono::seconds(2));
    }
}

bool GameDetector::InitializeMemoryAccess() {
    uintptr_t base = MemoryAccess::GetModuleBase("");
    if (base == 0) base = MemoryAccess::GetModuleBase("Roblox");
    m_offsets.baseAddress = base;
    return base != 0;
}

bool GameDetector::UpdateRobloxOffsets() {
    uintptr_t base = MemoryAccess::GetModuleBase("");
    if (base == 0) base = MemoryAccess::GetModuleBase("Roblox");
    m_offsets.baseAddress = base;
    // ScriptContext / LuaState / DataModel require version-specific patterns;
    // leave 0 until PatternScanner finds them — callers should check.
    if (base) {
        // Try common string anchors to validate we're in Roblox
        auto r = PatternScanner::ScanForString("ScriptContext", (void*)base, (void*)(base + 0x2000000));
        if (r.address) {
            // Not a direct pointer fixup, but confirms image content
            m_offsets.scriptContext = r.address;
        }
    }
    return m_offsets.baseAddress != 0;
}

bool GameDetector::CheckRobloxRunning() {
    // 1) Bundle identifier
    Class NSBundle = objc_getClass("NSBundle");
    if (NSBundle) {
        id mainBundle = ((id(*)(Class, SEL))objc_msgSend)(NSBundle, sel_registerName("mainBundle"));
        if (mainBundle) {
            id bid = ((id(*)(id, SEL))objc_msgSend)(mainBundle, sel_registerName("bundleIdentifier"));
            std::string idStr = NSStringToStd(bid);
            if (idStr.find("roblox") != std::string::npos || idStr.find("Roblox") != std::string::npos) {
                return true;
            }
            id name = ((id(*)(id, SEL))objc_msgSend)(mainBundle, sel_registerName("bundlePath"));
            std::string path = NSStringToStd(name);
            if (path.find("Roblox") != std::string::npos) return true;
        }
    }
    // 2) dyld images
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; ++i) {
        const char* n = _dyld_get_image_name(i);
        if (n && strstr(n, "Roblox")) return true;
    }
    // 3) Process name via sysctl-less path: argv[0] not available; use image 0
    if (count > 0) {
        const char* n0 = _dyld_get_image_name(0);
        if (n0 && (strstr(n0, "Roblox") || strstr(n0, "roblox"))) return true;
    }
    return false;
}

std::string GameDetector::ReadRobloxString(mach_vm_address_t stringPtr) {
    if (stringPtr == 0) return "";
    // Roblox/Lua strings vary; try null-terminated C string up to 512 bytes
    char buf[512] = {0};
    if (!MemoryAccess::ReadMemory(reinterpret_cast<void*>(stringPtr), buf, sizeof(buf) - 1)) {
        return "";
    }
    buf[sizeof(buf) - 1] = '\0';
    // Ensure printable
    std::string out;
    for (size_t i = 0; i < sizeof(buf) && buf[i]; ++i) {
        unsigned char c = static_cast<unsigned char>(buf[i]);
        if (c < 32 || c > 126) break;
        out.push_back(static_cast<char>(c));
    }
    return out;
}

std::string GameDetector::GetGameNameFromMemory() {
    // Prefer UI / bundle display name while in-process
    Class NSBundle = objc_getClass("NSBundle");
    if (NSBundle) {
        id mainBundle = ((id(*)(Class, SEL))objc_msgSend)(NSBundle, sel_registerName("mainBundle"));
        if (mainBundle) {
            id info = ((id(*)(id, SEL))objc_msgSend)(mainBundle, sel_registerName("infoDictionary"));
            if (info) {
                id key = ((id(*)(Class, SEL, const char*))objc_msgSend)(
                    objc_getClass("NSString"), sel_registerName("stringWithUTF8String:"), "CFBundleDisplayName");
                id val = ((id(*)(id, SEL, id))objc_msgSend)(info, sel_registerName("objectForKey:"), key);
                std::string display = NSStringToStd(val);
                if (!display.empty()) return display;
                key = ((id(*)(Class, SEL, const char*))objc_msgSend)(
                    objc_getClass("NSString"), sel_registerName("stringWithUTF8String:"), "CFBundleName");
                val = ((id(*)(id, SEL, id))objc_msgSend)(info, sel_registerName("objectForKey:"), key);
                display = NSStringToStd(val);
                if (!display.empty()) return display;
            }
        }
    }
    // Scan for place name patterns is version-fragile; report generic if unknown
    if (CheckRobloxRunning()) return "Roblox";
    return "Unknown";
}

std::string GameDetector::GetPlaceIdFromMemory() {
    // Try to find a numeric place id string in memory near known anchors — best-effort.
    // Also check NSUserDefaults / scene URL if present.
    Class NSUserDefaults = objc_getClass("NSUserDefaults");
    if (NSUserDefaults) {
        id defs = ((id(*)(Class, SEL))objc_msgSend)(NSUserDefaults, sel_registerName("standardUserDefaults"));
        if (defs) {
            const char* keys[] = {"placeId", "PlaceId", "placeID", "lastPlaceId", "RobloxPlaceId"};
            for (const char* k : keys) {
                id key = ((id(*)(Class, SEL, const char*))objc_msgSend)(
                    objc_getClass("NSString"), sel_registerName("stringWithUTF8String:"), k);
                id val = ((id(*)(id, SEL, id))objc_msgSend)(defs, sel_registerName("objectForKey:"), key);
                std::string s = NSStringToStd(val);
                if (!s.empty() && s.find_first_not_of("0123456789") == std::string::npos) {
                    return s;
                }
            }
        }
    }

    // Search process memory for "www.roblox.com/games/" style URLs
    uintptr_t base = m_offsets.baseAddress ? m_offsets.baseAddress : MemoryAccess::GetModuleBase("");
    if (base) {
        auto hit = PatternScanner::ScanForString("roblox.com/games/", (void*)base, (void*)(base + 0x3000000));
        if (hit.address) {
            char buf[128] = {0};
            if (MemoryAccess::ReadMemory(reinterpret_cast<void*>(hit.address), buf, sizeof(buf) - 1)) {
                std::string s(buf);
                size_t pos = s.find("games/");
                if (pos != std::string::npos) {
                    pos += 6;
                    std::string id;
                    while (pos < s.size() && std::isdigit(static_cast<unsigned char>(s[pos]))) {
                        id.push_back(s[pos++]);
                    }
                    if (!id.empty()) return id;
                }
            }
        }
    }
    return "";
}

void GameDetector::DetectCurrentGame() {
    m_currentGameName = GetGameNameFromMemory();
    m_currentPlaceId = GetPlaceIdFromMemory();
    if (m_currentPlaceId.empty() && CheckRobloxRunning()) {
        // Still in Roblox but place unknown
        m_currentPlaceId = "0";
    }
    m_lastGameJoinTime.store(
        (uint64_t)std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::system_clock::now().time_since_epoch()).count());
}

void GameDetector::NotifyStateChange(GameState newState) {
    if (s_stateCallback) s_stateCallback(newState);
}

void GameDetector::UpdateGameState() {
    bool running = CheckRobloxRunning();
    GameState prev = m_currentState.load();
    GameState next = prev;

    if (!running) {
        next = GameState::NotRunning;
        m_currentGameName.clear();
        m_currentPlaceId.clear();
    } else {
        DetectCurrentGame();
        // Heuristic: if we have a non-zero place id, treat as InGame; else Connecting/InMenu
        if (!m_currentPlaceId.empty() && m_currentPlaceId != "0") {
            next = GameState::InGame;
        } else {
            next = (prev == GameState::InGame) ? GameState::InMenu : GameState::Connecting;
        }
        UpdateRobloxOffsets();
    }

    if (next != prev) {
        m_currentState.store(next);
        NotifyStateChange(next);
        std::cout << "GameDetector: state -> " << (int)next
                  << " game=" << m_currentGameName
                  << " place=" << m_currentPlaceId << "\n";
    }
}

GameState GameDetector::GetCurrentState() const { return m_currentState.load(); }
bool GameDetector::IsInGame() const { return m_currentState.load() == GameState::InGame; }
std::string GameDetector::GetCurrentGameName() const { return m_currentGameName; }
std::string GameDetector::GetCurrentPlaceId() const { return m_currentPlaceId; }
uint64_t GameDetector::GetGameJoinTime() const { return m_lastGameJoinTime.load(); }
void GameDetector::SetStateChangeCallback(std::function<void(GameState)> callback) { s_stateCallback = callback; }
RobloxOffsets GameDetector::GetOffsets() const { return m_offsets; }

} // namespace iOS
