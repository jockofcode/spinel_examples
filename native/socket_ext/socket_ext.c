/* socket_ext.c -- project-local socket helpers for Spinel FFI examples. */

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <ifaddrs.h>
#include <netdb.h>
#include <net/if.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>
#include <unistd.h>

#define SX_BUFSIZE 65536
#define SX_MAX_IFADDRS 128

extern int sp_net_bin_len;

static char sx_buf[SX_BUFSIZE];
static char sx_buf2[SX_BUFSIZE];
static char sx_addr_buf[SX_BUFSIZE];
static int sx_pair_a = -1;
static int sx_pair_b = -1;
static int sx_last_errno_value = 0;
static int sx_last_recv_fd_value = -1;

struct sx_ifaddr_entry {
  char name[IF_NAMESIZE];
  int ifindex;
  unsigned int flags;
  int family;
  char addr[128];
  char netmask[128];
  char broadaddr[128];
  char dstaddr[128];
};

static struct sx_ifaddr_entry sx_ifaddrs[SX_MAX_IFADDRS];
static int sx_ifaddr_count_value = 0;

static void sx_ignore_sigpipe(void) {
  signal(SIGPIPE, SIG_IGN);
}

static int sx_set_nonblock_fd(int fd) {
  int flags = fcntl(fd, F_GETFL, 0);
  if (flags < 0) return -1;
  return fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

static int sx_wait_fd(int fd, short events) {
  struct pollfd pfd;
  pfd.fd = fd;
  pfd.events = events;
  pfd.revents = 0;
  for (;;) {
    int r = poll(&pfd, 1, 1000);
    if (r > 0) return 1;
    if (r == 0) continue;
    if (errno == EINTR) continue;
    return 0;
  }
}

static int sx_parse_sockaddr_in(const char *sockaddr, struct sockaddr_in *out) {
  char host[256];
  int port = 0;
  const char *colon;
  size_t n;
  if (!sockaddr || !out) return -1;
  colon = strrchr(sockaddr, ':');
  if (!colon) return -1;
  n = (size_t)(colon - sockaddr);
  if (n == 0 || n >= sizeof(host)) return -1;
  memcpy(host, sockaddr, n);
  host[n] = '\0';
  port = atoi(colon + 1);
  memset(out, 0, sizeof(*out));
  out->sin_family = AF_INET;
  out->sin_port = htons((unsigned short)port);
  if (inet_pton(AF_INET, host, &out->sin_addr) != 1) {
    struct hostent *he = gethostbyname(host);
    if (!he || he->h_addrtype != AF_INET || !he->h_addr_list[0]) return -1;
    memcpy(&out->sin_addr, he->h_addr_list[0], sizeof(out->sin_addr));
  }
  return 0;
}

static const char *sx_format_sockaddr_to(const struct sockaddr *sa, socklen_t len, char *out, size_t outlen) {
  (void)len;
  out[0] = '\0';
  if (!sa) return out;
  if (sa->sa_family == AF_INET) {
    const struct sockaddr_in *in = (const struct sockaddr_in *)sa;
    char host[INET_ADDRSTRLEN];
    if (!inet_ntop(AF_INET, &in->sin_addr, host, sizeof(host))) host[0] = '\0';
    snprintf(out, outlen, "%s:%d", host, ntohs(in->sin_port));
    return out;
  }
  if (sa->sa_family == AF_INET6) {
    const struct sockaddr_in6 *in6 = (const struct sockaddr_in6 *)sa;
    char host[INET6_ADDRSTRLEN];
    if (!inet_ntop(AF_INET6, &in6->sin6_addr, host, sizeof(host))) host[0] = '\0';
    snprintf(out, outlen, "%s:%d", host, ntohs(in6->sin6_port));
    return out;
  }
  if (sa->sa_family == AF_UNIX) {
    const struct sockaddr_un *un = (const struct sockaddr_un *)sa;
    snprintf(out, outlen, "%s", un->sun_path);
    return out;
  }
  return out;
}

static const char *sx_format_sockaddr(const struct sockaddr *sa, socklen_t len) {
  return sx_format_sockaddr_to(sa, len, sx_buf, sizeof(sx_buf));
}

int sx_set_nonblock(int fd) {
  return sx_set_nonblock_fd(fd);
}

int sx_shutdown(int fd, int how) {
  return shutdown(fd, how);
}

int sx_ipv6only(int fd) {
#ifdef IPV6_V6ONLY
  int value = 1;
  int rc = setsockopt(fd, IPPROTO_IPV6, IPV6_V6ONLY, &value, sizeof(value));
  sx_last_errno_value = rc < 0 ? errno : 0;
  return rc;
#else
  (void)fd;
  sx_last_errno_value = ENOTSUP;
  return -1;
#endif
}

const char *sx_getsockname(int fd) {
  struct sockaddr_storage ss;
  socklen_t len = sizeof(ss);
  if (getsockname(fd, (struct sockaddr *)&ss, &len) < 0) return "";
  return sx_format_sockaddr((struct sockaddr *)&ss, len);
}

const char *sx_getpeername(int fd) {
  struct sockaddr_storage ss;
  socklen_t len = sizeof(ss);
  if (getpeername(fd, (struct sockaddr *)&ss, &len) < 0) return "";
  return sx_format_sockaddr((struct sockaddr *)&ss, len);
}

int sx_getsockopt_int(int fd, int level, int optname) {
  int value = 0;
  socklen_t len = sizeof(value);
  if (getsockopt(fd, level, optname, &value, &len) < 0) return -1;
  return value;
}

int sx_getsockopt_int_str(int fd, const char *level, const char *optname) {
  return sx_getsockopt_int(fd, atoi(level ? level : "0"), atoi(optname ? optname : "0"));
}

int sx_setsockopt_int(int fd, int level, int optname, int value) {
  return setsockopt(fd, level, optname, &value, sizeof(value));
}

int sx_setsockopt_int_str(int fd, const char *level, const char *optname, const char *value) {
  return sx_setsockopt_int(
      fd,
      atoi(level ? level : "0"),
      atoi(optname ? optname : "0"),
      atoi(value ? value : "0"));
}

static int sx_getpeereid_values(int fd, int *uid_out, int *gid_out) {
#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__)
  uid_t uid;
  gid_t gid;
  if (getpeereid(fd, &uid, &gid) < 0) return -1;
  *uid_out = (int)uid;
  *gid_out = (int)gid;
  return 0;
#elif defined(SO_PEERCRED)
  struct ucred cred;
  socklen_t len = sizeof(cred);
  if (getsockopt(fd, SOL_SOCKET, SO_PEERCRED, &cred, &len) < 0) return -1;
  *uid_out = (int)cred.uid;
  *gid_out = (int)cred.gid;
  return 0;
#else
  (void)fd;
  (void)uid_out;
  (void)gid_out;
  return -1;
#endif
}

int sx_getpeereid_uid(int fd) {
  int uid = -1;
  int gid = -1;
  if (sx_getpeereid_values(fd, &uid, &gid) < 0) return -1;
  return uid;
}

int sx_getpeereid_gid(int fd) {
  int uid = -1;
  int gid = -1;
  if (sx_getpeereid_values(fd, &uid, &gid) < 0) return -1;
  return gid;
}

const char *sx_recv_flags(int fd, int maxlen, int flags) {
  ssize_t n;
  if (maxlen <= 0 || maxlen >= SX_BUFSIZE) maxlen = SX_BUFSIZE - 1;
  do {
    n = recv(fd, sx_buf, (size_t)maxlen, flags);
  } while (n < 0 && errno == EINTR);
  if (n < 0) {
    sp_net_bin_len = 0;
    sx_buf[0] = '\0';
    return sx_buf;
  }
  sp_net_bin_len = (int)n;
  sx_buf[n] = '\0';
  return sx_buf;
}

const char *sx_last_recvfrom_addr(void) {
  return sx_addr_buf;
}

const char *sx_recv_nonblock(int fd, int maxlen, int flags) {
  sx_set_nonblock_fd(fd);
  return sx_recv_flags(fd, maxlen, flags);
}

int sx_send_flags(int fd, const char *data, int flags) {
  size_t len;
  size_t off = 0;
  if (!data) return -1;
  sx_ignore_sigpipe();
  len = strlen(data);
  while (off < len) {
    ssize_t n = send(fd, data + off, len - off, flags);
    if (n < 0 && errno == EINTR) continue;
    if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK) && sx_wait_fd(fd, POLLOUT)) continue;
    if (n <= 0) return -1;
    off += (size_t)n;
  }
  return 0;
}

int sx_send_nonblock(int fd, const char *data, int flags) {
  sx_set_nonblock_fd(fd);
  return sx_send_flags(fd, data, flags);
}

int sx_udp_socket(int family) {
  sx_ignore_sigpipe();
  return socket(family ? family : AF_INET, SOCK_DGRAM, 0);
}

int sx_udp_bind(int fd, const char *host, int port) {
  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons((unsigned short)port);
  if (!host || strcmp(host, "0.0.0.0") == 0 || strcmp(host, "") == 0) {
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
  } else if (inet_pton(AF_INET, host, &addr.sin_addr) != 1) {
    return -1;
  }
  return bind(fd, (struct sockaddr *)&addr, sizeof(addr));
}

int sx_udp_connect(int fd, const char *host, int port) {
  struct sockaddr_in addr;
  char packed[320];
  snprintf(packed, sizeof(packed), "%s:%d", host ? host : "127.0.0.1", port);
  if (sx_parse_sockaddr_in(packed, &addr) < 0) return -1;
  return connect(fd, (struct sockaddr *)&addr, sizeof(addr));
}

int sx_udp_sendto(int fd, const char *data, int flags, const char *host, int port) {
  struct sockaddr_in addr;
  char packed[320];
  if (!data) return -1;
  snprintf(packed, sizeof(packed), "%s:%d", host ? host : "127.0.0.1", port);
  if (sx_parse_sockaddr_in(packed, &addr) < 0) return -1;
  return (int)sendto(fd, data, strlen(data), flags, (struct sockaddr *)&addr, sizeof(addr));
}

const char *sx_udp_recvfrom(int fd, int maxlen, int flags) {
  struct sockaddr_storage ss;
  socklen_t slen = sizeof(ss);
  ssize_t n;
  if (maxlen <= 0 || maxlen >= SX_BUFSIZE) maxlen = SX_BUFSIZE - 1;
  n = recvfrom(fd, sx_buf, (size_t)maxlen, flags, (struct sockaddr *)&ss, &slen);
  if (n < 0) {
    sp_net_bin_len = 0;
    sx_buf[0] = '\0';
    return sx_buf;
  }
  sp_net_bin_len = (int)n;
  sx_buf[n] = '\0';
  sx_format_sockaddr_to((struct sockaddr *)&ss, slen, sx_addr_buf, sizeof(sx_addr_buf));
  return sx_buf;
}

int sx_socket_create(int family, int type, int protocol) {
  int fd;
  sx_ignore_sigpipe();
  fd = socket(family, type, protocol);
  sx_last_errno_value = fd < 0 ? errno : 0;
  return fd;
}

int sx_socket_create_tcp(void) {
  return sx_socket_create(AF_INET, SOCK_STREAM, 0);
}

int sx_socket_create_tcp6(void) {
  return sx_socket_create(AF_INET6, SOCK_STREAM, 0);
}

int sx_last_errno(void) {
  return sx_last_errno_value;
}

int sx_socket_bind(int fd, const char *sockaddr) {
  struct sockaddr_in addr;
  if (sx_parse_sockaddr_in(sockaddr, &addr) < 0) return -1;
  return bind(fd, (struct sockaddr *)&addr, sizeof(addr));
}

int sx_socket_connect(int fd, const char *sockaddr) {
  struct sockaddr_in addr;
  if (sx_parse_sockaddr_in(sockaddr, &addr) < 0) return -1;
  return connect(fd, (struct sockaddr *)&addr, sizeof(addr));
}

int sx_socket_listen(int fd, int backlog) {
  return listen(fd, backlog);
}

int sx_socket_listen_str(int fd, const char *backlog) {
  return sx_socket_listen(fd, atoi(backlog ? backlog : "0"));
}

int sx_socket_accept(int fd) {
  int cfd;
  do {
    cfd = accept(fd, NULL, NULL);
  } while (cfd < 0 && errno == EINTR);
  return cfd;
}

int sx_unix_socket(void) {
  return socket(AF_UNIX, SOCK_STREAM, 0);
}

int sx_unix_connect(const char *path) {
  int fd = sx_unix_socket();
  struct sockaddr_un addr;
  if (fd < 0) return -1;
  memset(&addr, 0, sizeof(addr));
  addr.sun_family = AF_UNIX;
  snprintf(addr.sun_path, sizeof(addr.sun_path), "%s", path ? path : "");
  if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
    close(fd);
    return -1;
  }
  return fd;
}

int sx_unix_server(const char *path) {
  int fd = sx_unix_socket();
  struct sockaddr_un addr;
  if (fd < 0) return -1;
  memset(&addr, 0, sizeof(addr));
  addr.sun_family = AF_UNIX;
  snprintf(addr.sun_path, sizeof(addr.sun_path), "%s", path ? path : "");
  unlink(addr.sun_path);
  if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
    close(fd);
    return -1;
  }
  if (listen(fd, 128) < 0) {
    close(fd);
    return -1;
  }
  return fd;
}

int sx_unix_socketpair(void) {
  int fds[2];
  if (socketpair(AF_UNIX, SOCK_STREAM, 0, fds) < 0) return -1;
  sx_pair_a = fds[0];
  sx_pair_b = fds[1];
  return 0;
}

int sx_unix_socketpair_first(void) {
  return sx_pair_a;
}

int sx_unix_socketpair_second(void) {
  return sx_pair_b;
}

int sx_send_fd(int socket_fd, int fd_to_send) {
  struct msghdr msg;
  struct iovec iov;
  char byte = 'F';
  char control[CMSG_SPACE(sizeof(int))];
  struct cmsghdr *cmsg;

  memset(&msg, 0, sizeof(msg));
  memset(control, 0, sizeof(control));
  iov.iov_base = &byte;
  iov.iov_len = sizeof(byte);
  msg.msg_iov = &iov;
  msg.msg_iovlen = 1;
  msg.msg_control = control;
  msg.msg_controllen = sizeof(control);

  cmsg = CMSG_FIRSTHDR(&msg);
  cmsg->cmsg_level = SOL_SOCKET;
  cmsg->cmsg_type = SCM_RIGHTS;
  cmsg->cmsg_len = CMSG_LEN(sizeof(int));
  memcpy(CMSG_DATA(cmsg), &fd_to_send, sizeof(int));
  msg.msg_controllen = cmsg->cmsg_len;

  if (sendmsg(socket_fd, &msg, 0) < 0) return -1;
  return 0;
}

int sx_sendmsg_fd(int socket_fd, const char *data, int fd_to_send) {
  struct msghdr msg;
  struct iovec iov;
  char control[CMSG_SPACE(sizeof(int))];
  struct cmsghdr *cmsg;
  const char *payload = data ? data : "";

  memset(&msg, 0, sizeof(msg));
  memset(control, 0, sizeof(control));
  iov.iov_base = (void *)payload;
  iov.iov_len = strlen(payload);
  if (iov.iov_len == 0) {
    static char empty_byte = '\0';
    iov.iov_base = &empty_byte;
    iov.iov_len = 1;
  }
  msg.msg_iov = &iov;
  msg.msg_iovlen = 1;
  msg.msg_control = control;
  msg.msg_controllen = sizeof(control);

  cmsg = CMSG_FIRSTHDR(&msg);
  cmsg->cmsg_level = SOL_SOCKET;
  cmsg->cmsg_type = SCM_RIGHTS;
  cmsg->cmsg_len = CMSG_LEN(sizeof(int));
  memcpy(CMSG_DATA(cmsg), &fd_to_send, sizeof(int));
  msg.msg_controllen = cmsg->cmsg_len;

  if (sendmsg(socket_fd, &msg, 0) < 0) return -1;
  return (int)iov.iov_len;
}

int sx_recv_fd(int socket_fd) {
  struct msghdr msg;
  struct iovec iov;
  char byte = '\0';
  char control[CMSG_SPACE(sizeof(int))];
  struct cmsghdr *cmsg;
  int received_fd = -1;

  memset(&msg, 0, sizeof(msg));
  memset(control, 0, sizeof(control));
  iov.iov_base = &byte;
  iov.iov_len = sizeof(byte);
  msg.msg_iov = &iov;
  msg.msg_iovlen = 1;
  msg.msg_control = control;
  msg.msg_controllen = sizeof(control);

  if (recvmsg(socket_fd, &msg, 0) < 0) return -1;
  cmsg = CMSG_FIRSTHDR(&msg);
  if (!cmsg) return -1;
  if (cmsg->cmsg_level != SOL_SOCKET || cmsg->cmsg_type != SCM_RIGHTS) return -1;
  memcpy(&received_fd, CMSG_DATA(cmsg), sizeof(int));
  return received_fd;
}

const char *sx_recvmsg_with_fd(int socket_fd, int maxlen, int flags) {
  struct msghdr msg;
  struct iovec iov;
  char control[CMSG_SPACE(sizeof(int))];
  struct cmsghdr *cmsg;
  ssize_t n;

  if (maxlen <= 0 || maxlen >= SX_BUFSIZE) maxlen = SX_BUFSIZE - 1;
  sx_last_recv_fd_value = -1;
  memset(&msg, 0, sizeof(msg));
  memset(control, 0, sizeof(control));
  iov.iov_base = sx_buf;
  iov.iov_len = (size_t)maxlen;
  msg.msg_iov = &iov;
  msg.msg_iovlen = 1;
  msg.msg_control = control;
  msg.msg_controllen = sizeof(control);

  do {
    n = recvmsg(socket_fd, &msg, flags);
  } while (n < 0 && errno == EINTR);
  if (n < 0) {
    sp_net_bin_len = 0;
    sx_buf[0] = '\0';
    return sx_buf;
  }

  sp_net_bin_len = (int)n;
  sx_buf[n] = '\0';
  for (cmsg = CMSG_FIRSTHDR(&msg); cmsg; cmsg = CMSG_NXTHDR(&msg, cmsg)) {
    if (cmsg->cmsg_level == SOL_SOCKET && cmsg->cmsg_type == SCM_RIGHTS) {
      memcpy(&sx_last_recv_fd_value, CMSG_DATA(cmsg), sizeof(int));
      break;
    }
  }
  return sx_buf;
}

int sx_last_recv_fd(void) {
  return sx_last_recv_fd_value;
}

const char *sx_gethostname(void) {
  if (gethostname(sx_buf, sizeof(sx_buf) - 1) < 0) return "";
  sx_buf[sizeof(sx_buf) - 1] = '\0';
  return sx_buf;
}

const char *sx_getaddrinfo_one(const char *host, int service, int family, int socktype, int protocol, int flags) {
  struct addrinfo hints;
  struct addrinfo *res = NULL;
  char portbuf[32];
  sx_buf[0] = '\0';
  memset(&hints, 0, sizeof(hints));
  hints.ai_family = family ? family : AF_UNSPEC;
  hints.ai_socktype = socktype;
  hints.ai_protocol = protocol;
  hints.ai_flags = flags;
  snprintf(portbuf, sizeof(portbuf), "%d", service);
  if (getaddrinfo(host, portbuf, &hints, &res) != 0 || !res) return sx_buf;
  sx_format_sockaddr(res->ai_addr, (socklen_t)res->ai_addrlen);
  snprintf(sx_buf2, sizeof(sx_buf2), "%s|%d|%d|%d", sx_buf, res->ai_family, res->ai_socktype, res->ai_protocol);
  freeaddrinfo(res);
  return sx_buf2;
}

const char *sx_getnameinfo(const char *sockaddr, int flags) {
  struct sockaddr_in addr;
  char host[NI_MAXHOST];
  char serv[NI_MAXSERV];
  sx_buf[0] = '\0';
  if (sx_parse_sockaddr_in(sockaddr, &addr) < 0) return sx_buf;
  if (getnameinfo((struct sockaddr *)&addr, sizeof(addr), host, sizeof(host), serv, sizeof(serv), flags) != 0) return sx_buf;
  snprintf(sx_buf, sizeof(sx_buf), "%s|%s", host, serv);
  return sx_buf;
}

int sx_getservbyname_port(const char *service, const char *protocol) {
  struct servent *se = getservbyname(service, protocol ? protocol : "tcp");
  if (!se) return -1;
  return ntohs((unsigned short)se->s_port);
}

const char *sx_getservbyport_name(int port, const char *protocol) {
  struct servent *se = getservbyport(htons((unsigned short)port), protocol ? protocol : "tcp");
  if (!se) return "";
  return se->s_name;
}

const char *sx_getservbyport_name_str(const char *port, const char *protocol) {
  return sx_getservbyport_name(atoi(port ? port : "0"), protocol);
}

static void sx_store_sockaddr_host(const struct sockaddr *sa, char *out, size_t outlen) {
  out[0] = '\0';
  if (!sa) return;
  if (sa->sa_family == AF_INET) {
    const struct sockaddr_in *in = (const struct sockaddr_in *)sa;
    if (!inet_ntop(AF_INET, &in->sin_addr, out, (socklen_t)outlen)) out[0] = '\0';
  } else if (sa->sa_family == AF_INET6) {
    const struct sockaddr_in6 *in6 = (const struct sockaddr_in6 *)sa;
    if (!inet_ntop(AF_INET6, &in6->sin6_addr, out, (socklen_t)outlen)) out[0] = '\0';
  }
}

int sx_ifaddr_count(void) {
  struct ifaddrs *ifaddr = NULL;
  struct ifaddrs *ifa;
  sx_ifaddr_count_value = 0;
  if (getifaddrs(&ifaddr) < 0) return 0;
  for (ifa = ifaddr; ifa && sx_ifaddr_count_value < SX_MAX_IFADDRS; ifa = ifa->ifa_next) {
    struct sx_ifaddr_entry *entry;
    if (!ifa->ifa_addr) continue;
    if (ifa->ifa_addr->sa_family != AF_INET && ifa->ifa_addr->sa_family != AF_INET6) continue;
    entry = &sx_ifaddrs[sx_ifaddr_count_value++];
    memset(entry, 0, sizeof(*entry));
    snprintf(entry->name, sizeof(entry->name), "%s", ifa->ifa_name ? ifa->ifa_name : "");
    entry->ifindex = (int)if_nametoindex(entry->name);
    entry->flags = ifa->ifa_flags;
    entry->family = ifa->ifa_addr->sa_family;
    sx_store_sockaddr_host(ifa->ifa_addr, entry->addr, sizeof(entry->addr));
    sx_store_sockaddr_host(ifa->ifa_netmask, entry->netmask, sizeof(entry->netmask));
    if ((ifa->ifa_flags & IFF_BROADCAST) && ifa->ifa_broadaddr) {
      sx_store_sockaddr_host(ifa->ifa_broadaddr, entry->broadaddr, sizeof(entry->broadaddr));
    }
    if ((ifa->ifa_flags & IFF_POINTOPOINT) && ifa->ifa_dstaddr) {
      sx_store_sockaddr_host(ifa->ifa_dstaddr, entry->dstaddr, sizeof(entry->dstaddr));
    }
  }
  freeifaddrs(ifaddr);
  return sx_ifaddr_count_value;
}

const char *sx_ifaddr_name(int index) {
  if (index < 0 || index >= sx_ifaddr_count_value) return "";
  return sx_ifaddrs[index].name;
}

int sx_ifaddr_ifindex(int index) {
  if (index < 0 || index >= sx_ifaddr_count_value) return 0;
  return sx_ifaddrs[index].ifindex;
}

int sx_ifaddr_flags(int index) {
  if (index < 0 || index >= sx_ifaddr_count_value) return 0;
  return (int)sx_ifaddrs[index].flags;
}

int sx_ifaddr_family(int index) {
  if (index < 0 || index >= sx_ifaddr_count_value) return AF_UNSPEC;
  return sx_ifaddrs[index].family;
}

const char *sx_ifaddr_addr(int index) {
  if (index < 0 || index >= sx_ifaddr_count_value) return "";
  return sx_ifaddrs[index].addr;
}

const char *sx_ifaddr_netmask(int index) {
  if (index < 0 || index >= sx_ifaddr_count_value) return "";
  return sx_ifaddrs[index].netmask;
}

const char *sx_ifaddr_broadaddr(int index) {
  if (index < 0 || index >= sx_ifaddr_count_value) return "";
  return sx_ifaddrs[index].broadaddr;
}

const char *sx_ifaddr_dstaddr(int index) {
  if (index < 0 || index >= sx_ifaddr_count_value) return "";
  return sx_ifaddrs[index].dstaddr;
}

const char *sx_pack_sockaddr_in(int port, const char *host) {
  snprintf(sx_buf, sizeof(sx_buf), "%s:%d", host ? host : "0.0.0.0", port);
  return sx_buf;
}

int sx_unpack_sockaddr_in_port(const char *sockaddr) {
  const char *colon = sockaddr ? strrchr(sockaddr, ':') : NULL;
  if (!colon) return 0;
  return atoi(colon + 1);
}

const char *sx_unpack_sockaddr_in_host(const char *sockaddr) {
  const char *colon = sockaddr ? strrchr(sockaddr, ':') : NULL;
  size_t n;
  if (!sockaddr || !colon) return "";
  n = (size_t)(colon - sockaddr);
  if (n >= SX_BUFSIZE) n = SX_BUFSIZE - 1;
  memcpy(sx_buf, sockaddr, n);
  sx_buf[n] = '\0';
  return sx_buf;
}

const char *sx_pack_sockaddr_un(const char *path) {
  snprintf(sx_buf, sizeof(sx_buf), "%s", path ? path : "");
  return sx_buf;
}

const char *sx_unpack_sockaddr_un(const char *sockaddr) {
  return sockaddr ? sockaddr : "";
}

int sx_const_af_inet(void) { return AF_INET; }
int sx_const_af_inet6(void) { return AF_INET6; }
int sx_const_af_unix(void) { return AF_UNIX; }
int sx_const_af_unspec(void) { return AF_UNSPEC; }
int sx_const_sock_stream(void) { return SOCK_STREAM; }
int sx_const_sock_dgram(void) { return SOCK_DGRAM; }
int sx_const_sol_socket(void) { return SOL_SOCKET; }
int sx_const_so_reuseaddr(void) { return SO_REUSEADDR; }
int sx_const_so_reuseport(void) {
#ifdef SO_REUSEPORT
  return SO_REUSEPORT;
#else
  return 0;
#endif
}
int sx_const_tcp_nodelay(void) { return TCP_NODELAY; }
int sx_const_shut_rd(void) { return SHUT_RD; }
int sx_const_shut_wr(void) { return SHUT_WR; }
int sx_const_shut_rdwr(void) { return SHUT_RDWR; }
