/**
 * Lua definitions wrapper to handle macro redefinitions gracefully
 */
#pragma once

// Undefine any existing macros that might conflict with Lua headers
#ifdef LUALIB_API
#undef LUALIB_API
#endif

#ifdef LUAI_FUNC
#undef LUAI_FUNC
#endif

// Now include the real Lua headers
#include "../vm/include/lua.h"
#include "../vm/include/luaconf.h"
#include "../vm/include/lualib.h"
#include "../vm/src/lstate.h"
