/* sp_file_ext.c -- Missing File class methods for the Spinel runtime.
 *
 * Implements the POSIX operations that sp_io.h omits: readlink, symlink,
 * link, stat/lstat (as formatted strings), chmod, and utime.  These are
 * bound to Ruby via native_func declarations in file_ext.rb and linked in
 * with `spinel ... --link nix_utils/sp_file_ext.o`.
 *
 * Include path: -I $SPINEL_LIB/lib   (where spinel/runtime.h lives under lib/)
 * Compile:  cc -c sp_file_ext.c -I$SPINEL_LIB/lib -o sp_file_ext.o
 * The SPINEL_LIB path is ~/.asdf/installs/spinel/master/lib/spinel on a
 * typical asdf-managed install.
 */

#include "spinel/runtime.h"  /* sp_str_alloc, sp_str_alloc_raw, sp_str_set_len */
#include <unistd.h>
#include <sys/stat.h>
#include <utime.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>

/* ---------------------------------------------------------------------------
 * File.readlink(path) -> String
 *
 * Returns the symlink target, or "" if path is not a symlink or on error.
 * The caller (readlink.rb) already checks File.symlink?(path) beforehand.
 * --------------------------------------------------------------------------- */
const char *sp_file_readlink(const char *path) {
    char buf[4096];
    ssize_t n = readlink(path, buf, sizeof(buf) - 1);
    if (n < 0) {
        char *s = sp_str_alloc(0);
        return s;
    }
    buf[n] = '\0';
    char *s = sp_str_alloc_raw((size_t)n + 1);
    memcpy(s, buf, (size_t)n + 1);
    sp_str_set_len(s, (size_t)n);
    return s;
}

/* ---------------------------------------------------------------------------
 * File.symlink(target, link_path) -> Integer (0 success, errno on failure)
 * --------------------------------------------------------------------------- */
mrb_int sp_file_symlink_c(const char *target, const char *link_path) {
    if (symlink(target, link_path) == 0) return 0;
    return (mrb_int)errno;
}

/* ---------------------------------------------------------------------------
 * File.link(src, dst) -> Integer (0 success, errno on failure)
 * --------------------------------------------------------------------------- */
mrb_int sp_file_link_c(const char *src, const char *dst) {
    if (link(src, dst) == 0) return 0;
    return (mrb_int)errno;
}

/* ---------------------------------------------------------------------------
 * File.chmod(mode, path) -> Integer (0 success, errno on failure)
 * --------------------------------------------------------------------------- */
mrb_int sp_file_chmod_c(mrb_int mode, const char *path) {
    if (chmod(path, (mode_t)mode) == 0) return 0;
    return (mrb_int)errno;
}

/* ---------------------------------------------------------------------------
 * Shared stat formatter — populates a GC string with space-separated fields:
 *   mode_oct nlinks uid gid size blocks ino dev atime mtime ctime
 * Returns "" on error (file not found, permission denied, etc.).
 * --------------------------------------------------------------------------- */
static const char *stat_to_str(struct stat *st) {
    char buf[256];
    int n = snprintf(buf, sizeof(buf),
        "%o %lu %u %u %lld %lld %llu %llu %lld %lld %lld",
        (unsigned)st->st_mode,
        (unsigned long)st->st_nlink,
        (unsigned)st->st_uid,
        (unsigned)st->st_gid,
        (long long)st->st_size,
        (long long)st->st_blocks,
        (unsigned long long)st->st_ino,
        (unsigned long long)st->st_dev,
        (long long)st->st_atime,
        (long long)st->st_mtime,
        (long long)st->st_ctime);
    if (n < 0 || n >= (int)sizeof(buf)) n = 0;
    char *s = sp_str_alloc_raw((size_t)n + 1);
    memcpy(s, buf, (size_t)n + 1);
    sp_str_set_len(s, (size_t)n);
    return s;
}

/* ---------------------------------------------------------------------------
 * File.stat_str(path) -> String  (follows symlinks)
 * File.lstat_str(path) -> String (does not follow symlinks)
 *
 * Returns "" on error.  Ruby callers parse the fields with split(" ").
 * --------------------------------------------------------------------------- */
const char *sp_file_stat_str(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0) {
        char *s = sp_str_alloc(0);
        return s;
    }
    return stat_to_str(&st);
}

const char *sp_file_lstat_str(const char *path) {
    struct stat st;
    if (lstat(path, &st) != 0) {
        char *s = sp_str_alloc(0);
        return s;
    }
    return stat_to_str(&st);
}

/* ---------------------------------------------------------------------------
 * File.utime_c(atime_epoch, mtime_epoch, path) -> Integer (0 / errno)
 *
 * Both time arguments are integer Unix timestamps.
 * --------------------------------------------------------------------------- */
mrb_int sp_file_utime_c(mrb_int atime, mrb_int mtime, const char *path) {
    struct utimbuf ut;
    ut.actime  = (time_t)atime;
    ut.modtime = (time_t)mtime;
    if (utime(path, &ut) == 0) return 0;
    return (mrb_int)errno;
}
