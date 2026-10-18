#include "PresenceSystem.h"

namespace iOS {
    // Initialize static member variables for PresenceSystem
    void* PresenceSystem::m_nameTagHook = nullptr;
    void* PresenceSystem::m_networkHook = nullptr;
    void* PresenceSystem::m_originalNameTagFunc = nullptr;
    void* PresenceSystem::m_originalNetworkFunc = nullptr;
    void* PresenceSystem::m_tagUIElement = nullptr;
}
