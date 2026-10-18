/*
** LuaFileSystem - iOS/Ubuntu POSIX subset
*/

/* Define 'chdir' for systems that do not implement it */
#ifdef NO_CHDIR
#define chdir(p)	(-1)
#define chdir_error	"Function 'chdir' not provided by system"
#else
#define chdir_error	strerror(errno)
#endif

/* Remove Windows-specific definitions — iOS/ARM64 only */
#define LFS_EXPORT

#ifdef __cplusplus
extern "C" {
#endif

  LFS_EXPORT int luaopen_lfs(lua_State * L);

#ifdef __cplusplus
}
#endif
