// lua_compatibility.h - Compatibility layer for Luau integration (Roblox's Lua)
// Optimized for Luau but compatible with standard Lua if needed
#pragma once

// Include standard headers
#include <stddef.h>
#include <stdarg.h>
#include <string>
#include <vector>

#ifdef __cplusplus
#include <cstddef>
#include <cstdarg>
#endif

// Include the Luau/Lua headers - these will be found in our installed location
// For Luau, these are in VM/include
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

// Compatibility for Luau-specific features and standard Lua differences
#ifdef __cplusplus
extern "C" {
#endif

// Make sure LUA_TVECTOR is defined (Luau-specific type for Vector3, etc.)
#ifndef LUA_TVECTOR
#define LUA_TVECTOR 10
#endif

// Luau userdata type
#ifndef LUA_TUSERDATA0
#define LUA_TUSERDATA0 11
#endif

// Compatibility for Luau vector operations
#if !defined(LUA_VMOVE) && !defined(LUA_VROT)
#define LUA_VMOVE 0
#define LUA_VROT 1
#define LUA_VSTEP 2
#define LUA_VSCALE 3
#define LUA_VOP_COUNT 4
#endif

// Add some compatibility macros for older Lua versions if needed
#ifndef lua_pushcfunction
#define lua_pushcfunction(L, f) lua_pushcclosure(L, (f), 0)
#endif

// Luau-specific: Ensure we have new_lib defined for library creation
#ifndef new_lib
#define new_lib(L, l) (lua_createtable(L, 0, sizeof(l)/sizeof((l)[0]) - 1), luaL_setfuncs(L, l, 0))
#endif

// Some older Lua versions use deprecated functions
#if LUA_VERSION_NUM < 502
// For Lua 5.1 compatibility
#define luaL_setfuncs(L, l, nup) luaL_register(L, NULL, l)
#endif

// Helper for luaL_checkstring to work across Lua versions
#if !defined(luaL_checkstring) && !defined(LUAI_FUNC)
#define luaL_checkstring(L, n) luaL_checklstring(L, (n), NULL)
#endif

// For older Lua versions, provide lua_rawlen compatibility
#if LUA_VERSION_NUM < 502 && !defined(lua_rawlen)
#define lua_rawlen(L, i) lua_objlen(L, (i))
#endif

// Luau sandboxing functions - stub implementations if using standard Lua
#ifndef lua_sandboxthread
inline int lua_sandboxthread(lua_State* L) { return 0; }
#endif

#ifndef lua_setsafeenv
inline void lua_setsafeenv(lua_State* L, int idx, int safe) { }
#endif

// Luau vector operations - stub implementations if using standard Lua
#ifndef lua_isvector
inline int lua_isvector(lua_State* L, int idx) { return 0; }
#endif

#ifndef lua_tovector
inline int lua_tovector(lua_State* L, int idx, float* x, float* y, float* z) { 
    *x = 0.0f; *y = 0.0f; *z = 0.0f; 
    return 0; 
}
#endif

#ifndef lua_pushvector
inline void lua_pushvector(lua_State* L, float x, float y, float z) {
    // Push a table with x,y,z fields as a fallback
    lua_createtable(L, 0, 3);
    lua_pushnumber(L, x);
    lua_setfield(L, -2, "x");
    lua_pushnumber(L, y);
    lua_setfield(L, -2, "y");
    lua_pushnumber(L, z);
    lua_setfield(L, -2, "z");
}
#endif

// Helper functions for common Roblox Lua operations
inline void luau_pushInstance(lua_State* L, const char* className) {
    // Creates a simple userdata that mimics a Roblox Instance
    void* data = lua_newuserdata(L, sizeof(void*));
    lua_createtable(L, 0, 2);
    
    // Set ClassName property
    lua_pushstring(L, className);
    lua_setfield(L, -2, "ClassName");
    
    // Set metatable with __index metamethod
    lua_createtable(L, 0, 1);
    lua_pushvalue(L, -2);
    lua_setfield(L, -2, "__index");
    lua_setmetatable(L, -2);
    
    lua_setmetatable(L, -2);
}

// Useful for Roblox script execution
inline int luau_loadbuffer(lua_State* L, const char* buff, size_t sz, const char* name, const char* mode) {
#ifdef LUAU_FASTINT_SUPPORT
    // Use Luau's enhanced loader if available
    return luau_load(L, name, buff, sz, mode);
#else
    // Fall back to standard Lua
    return luaL_loadbuffer(L, buff, sz, name);
#endif
}

// Add compatibility with Lua 5.1's global table access
#if LUA_VERSION_NUM >= 502
// In Lua 5.2+, the globals are accessed through LUA_RIDX_GLOBALS
inline void lua_compat_getglobal(lua_State* L, const char* name) {
    lua_getglobal(L, name);
}
inline void lua_compat_setglobal(lua_State* L, const char* name) {
    lua_setglobal(L, name);
}
#else
// In Lua 5.1, the globals table is at LUA_GLOBALSINDEX
inline void lua_compat_getglobal(lua_State* L, const char* name) {
    lua_getfield(L, LUA_GLOBALSINDEX, name);
}
inline void lua_compat_setglobal(lua_State* L, const char* name) {
    lua_setfield(L, LUA_GLOBALSINDEX, name);
}
#define lua_getglobal(L, name) lua_compat_getglobal(L, name)
#define lua_setglobal(L, name) lua_compat_setglobal(L, name)
#endif

#ifdef __cplusplus
}

// C++ helper classes for Luau integration
namespace Luau {

// Vector3 class compatible with Roblox's Vector3
class Vector3 {
public:
    float x, y, z;
    
    Vector3() : x(0), y(0), z(0) {}
    Vector3(float x, float y, float z) : x(x), y(y), z(z) {}
    
    // Push this vector to Lua stack
    void push(lua_State* L) const {
        lua_pushvector(L, x, y, z);
    }
    
    // Get vector from Lua stack
    static Vector3 from(lua_State* L, int idx) {
        Vector3 result;
        lua_tovector(L, idx, &result.x, &result.y, &result.z);
        return result;
    }
    
    // Check if value at idx is a vector
    static bool check(lua_State* L, int idx) {
        return lua_isvector(L, idx) != 0;
    }
};

// Helper for script execution
class ScriptRunner {
public:
    static int runScript(lua_State* L, const std::string& script, const std::string& chunkName = "UserScript") {
        if (luau_loadbuffer(L, script.c_str(), script.length(), chunkName.c_str(), nullptr) != 0) {
            return 1; // Load error
        }
        
        // Execute in protected mode
        return lua_pcall(L, 0, LUA_MULTRET, 0);
    }
};

} // namespace Luau
#endif // __cplusplus
