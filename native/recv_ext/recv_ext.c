/* recv_ext.c -- minimal FFI extension for Spinel native socket.
 *
 * Exposes one function: sp_recv(fd, maxlen) which calls the POSIX recv()
 * syscall and returns available data immediately — unlike Spinel's native
 * readpartial(), which blocks until the peer closes its write end (FIN).
 *
 * Compiled into binaries that use require "socket" + lib/socket_recv_ext.rb:
 *
 *   SPINEL_REQUIRE_GATE=1 spinel --link native/recv_ext/recv_ext.c source/prog.rb -o bin/prog
 */

#include <errno.h>
#include <sys/socket.h>

#define SP_RECV_BUFSIZE 65536

/* Spinel reads this after a :binstr call to know how many bytes to copy. */
extern int sp_net_bin_len;

static char sp_recv_buf[SP_RECV_BUFSIZE];

/* recv() wrapper: returns however many bytes are available right now.
 * Blocks only if no data has arrived yet (normal for a new connection).
 * Returns an empty string on error or connection close. */
const char *sp_recv(int fd, int maxlen) {
  ssize_t n;
  if (maxlen <= 0 || maxlen >= SP_RECV_BUFSIZE) maxlen = SP_RECV_BUFSIZE - 1;
  do {
    n = recv(fd, sp_recv_buf, (size_t)maxlen, 0);
  } while (n < 0 && errno == EINTR);
  if (n <= 0) {
    sp_net_bin_len = 0;
    sp_recv_buf[0] = '\0';
    return sp_recv_buf;
  }
  sp_net_bin_len = (int)n;
  sp_recv_buf[n] = '\0';
  return sp_recv_buf;
}
