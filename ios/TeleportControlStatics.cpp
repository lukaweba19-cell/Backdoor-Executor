#include "TeleportControl.h"

namespace iOS {
    // Initialize static member variables for TeleportControl
    void* TeleportControl::m_originalTeleportFunc = nullptr;
    void* TeleportControl::m_originalValidationFunc = nullptr;
    void* TeleportControl::m_teleportHook = nullptr;
    void* TeleportControl::m_teleportValidationHook = nullptr;
}
