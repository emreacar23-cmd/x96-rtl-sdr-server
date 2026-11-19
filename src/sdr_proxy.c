/*
 * x96-rtl-sdr-on-demand: accept one RTL-TCP client, launch rtl_tcp only
 * for that session, proxy the protocol, then stop rtl_tcp on disconnect.
 *
 * Build for Android/Termux with: clang -O2 -Wall -Wextra -o sdr_proxy sdr_proxy.c
 */
#define _POSIX_C_SOURCE 200809L
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static volatile sig_atomic_t stopping = 0;
static volatile sig_atomic_t active_child = -1;

static void on_signal(int sig) {
    (void)sig;
    stopping = 1;
    if (active_child > 0) kill((pid_t)active_child, SIGTERM);
}

static int send_all(int fd, const unsigned char *buf, size_t len) {
    size_t off = 0;
    while (off < len) {
#ifdef MSG_NOSIGNAL
        ssize_t n = send(fd, buf + off, len - off, MSG_NOSIGNAL);
#else
        ssize_t n = send(fd, buf + off, len - off, 0);
#endif
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) return -1;
        off += (size_t)n;
    }
    return 0;
}

static int connect_backend(const char *host, int port) {
    struct sockaddr_in a;
    int tries;
    for (tries = 0; tries < 60 && !stopping; tries++) {
        int fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd >= 0) {
            memset(&a, 0, sizeof(a));
            a.sin_family = AF_INET;
            a.sin_port = htons((unsigned short)port);
            if (inet_pton(AF_INET, host, &a.sin_addr) == 1 &&
                connect(fd, (struct sockaddr *)&a, sizeof(a)) == 0) {
                return fd;
            }
            close(fd);
        }
        usleep(100000);
    }
    return -1;
}

static void relay_session(int client, int backend) {
    unsigned char buf[65536];
    struct pollfd p[2];
    p[0].fd = client;  p[0].events = POLLIN;
    p[1].fd = backend; p[1].events = POLLIN;

    while (!stopping) {
        int r = poll(p, 2, 1000);
        if (r < 0) {
            if (errno == EINTR) continue;
            break;
        }
        if (r == 0) continue;

        for (int i = 0; i < 2; i++) {
            if (p[i].revents & (POLLIN | POLLHUP | POLLERR)) {
                int src = p[i].fd;
                int dst = p[1 - i].fd;
                ssize_t n = recv(src, buf, sizeof(buf), 0);
                if (n == 0) return;
                if (n < 0) {
                    if (errno == EINTR || errno == EAGAIN) continue;
                    return;
                }
                if (send_all(dst, buf, (size_t)n) < 0) return;
            }
        }
    }
}

int main(int argc, char **argv) {
    const char *rtl_tcp = argc > 1 ? argv[1] : NULL;
    int listen_port = argc > 2 ? atoi(argv[2]) : 1234;
    int backend_port = argc > 3 ? atoi(argv[3]) : 1235;
    int server, one = 1;
    struct sockaddr_in addr;

    if (!rtl_tcp || access(rtl_tcp, X_OK) != 0 ||
        listen_port < 1 || listen_port > 65535 ||
        backend_port < 1 || backend_port > 65535) {
        fprintf(stderr, "Usage: %s /absolute/path/rtl_tcp [listen_port] [backend_port]\n", argv[0]);
        return 2;
    }

    signal(SIGINT, on_signal);
    signal(SIGTERM, on_signal);
    signal(SIGPIPE, SIG_IGN);

    server = socket(AF_INET, SOCK_STREAM, 0);
    if (server < 0) { perror("socket"); return 1; }
    setsockopt(server, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons((unsigned short)listen_port);

    if (bind(server, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind"); close(server); return 1;
    }
    if (listen(server, 4) < 0) {
        perror("listen"); close(server); return 1;
    }

    fprintf(stderr, "sdr_proxy listening on 0.0.0.0:%d; rtl_tcp starts per client\n", listen_port);

    while (!stopping) {
        struct sockaddr_in peer;
        socklen_t plen = sizeof(peer);
        int client = accept(server, (struct sockaddr *)&peer, &plen);
        if (client < 0) {
            if (errno == EINTR) continue;
            if (stopping) break;
            perror("accept");
            continue;
        }

        char ip[INET_ADDRSTRLEN] = "?";
        inet_ntop(AF_INET, &peer.sin_addr, ip, sizeof(ip));
        fprintf(stderr, "client connected: %s\n", ip);

        pid_t child = fork();
        if (child == 0) {
            char portbuf[16];
            close(server);
            snprintf(portbuf, sizeof(portbuf), "%d", backend_port);
            execl(rtl_tcp, rtl_tcp, "-a", "127.0.0.1", "-p", portbuf, (char *)NULL);
            perror("exec rtl_tcp");
            _exit(127);
        }
        if (child < 0) {
            perror("fork"); close(client); continue;
        }
        active_child = child;

        int backend = connect_backend("127.0.0.1", backend_port);
        if (backend >= 0 && !stopping) {
            fprintf(stderr, "RTL-TCP backend ready; proxying client\n");
            relay_session(client, backend);
            close(backend);
        } else {
            fprintf(stderr, "ERROR: RTL-TCP backend did not start\n");
        }

        close(client);
        if (child > 0) {
            kill(child, SIGTERM);
            for (int i = 0; i < 20; i++) {
                pid_t w = waitpid(child, NULL, WNOHANG);
                if (w == child) { child = -1; break; }
                usleep(100000);
            }
            if (child > 0) {
                kill(child, SIGKILL);
                waitpid(child, NULL, 0);
            }
        }
        active_child = -1;
        fprintf(stderr, "client session ended; RTL-TCP stopped\n");
    }

    close(server);
    if (active_child > 0) kill((pid_t)active_child, SIGTERM);
    fprintf(stderr, "sdr_proxy stopped\n");
    return 0;
}
