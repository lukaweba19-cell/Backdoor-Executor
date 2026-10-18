// This file is part of the Luau programming language and is licensed under MIT License; see LICENSE.txt for details
// This code is based on Lua 5.x implementation licensed under MIT License; see lua_LICENSE.txt for details
#include "lua.h"

// iOS/Ubuntu only - Windows support removed
#ifdef __APPLE__
#include <mach/mach.h>
#include <mach/mach_time.h>
#endif


#include <time.h>

static double clock_period()
{
#if defined(__APPLE__)
    mach_timebase_info_data_t result = {};
    mach_timebase_info(&result);
    return double(result.numer) / double(result.denom) * 1e-9;
#elif defined(__linux__) || defined(__FreeBSD__)
    return 1e-9;
#else
    return 1.0 / double(CLOCKS_PER_SEC);
#endif
}

static double clock_timestamp()
{
#if defined(__APPLE__)
    return double(mach_absolute_time());
#elif defined(__linux__) || defined(__FreeBSD__)
    timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return now.tv_sec * 1e9 + now.tv_nsec;
#else
    return double(clock());
#endif
}

double lua_clock()
{
    static double period = clock_period();

    return clock_timestamp() * period;
}
