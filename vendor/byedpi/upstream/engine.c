#define _DEFAULT_SOURCE
#include "byedpi_engine.h"

#include <errno.h>
#include <limits.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>

#include "params.h"

extern int parse_args(int argc, char **argv);
extern int init(void);
extern int run(const union sockaddr_u *srv);
extern void clear_params(char *line, char **argv);

enum engine_state { ENGINE_IDLE, ENGINE_STARTING, ENGINE_RUNNING, ENGINE_STOPPING, ENGINE_EXITED };

static pthread_mutex_t engine_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t engine_changed = PTHREAD_COND_INITIALIZER;
static pthread_t engine_thread;
static enum engine_state state = ENGINE_IDLE;
static int thread_finished = 0;
static int engine_result = -1;
static volatile int engine_stop_requested = 0;
static int local_port = 0;
static int active_profile = -1;
static char protect_path[PATH_MAX];
static char interface_name[64];

static void reset_params(void) {
    memset(&params, 0, sizeof(params));
    params.await_int = 10;
    params.ipv6 = 1;
    params.resolve = 1;
    params.udp = 1;
    params.max_open = 512;
    params.bfsize = 16384;
    params.baddr.in6.sin6_family = AF_INET6;
    params.laddr.in.sin_family = AF_INET;
    params.pid_fd = -1;
}

static void report_ready(unsigned short port) {
    pthread_mutex_lock(&engine_mutex);
    local_port = (int)port;
    state = ENGINE_RUNNING;
    pthread_cond_broadcast(&engine_changed);
    pthread_mutex_unlock(&engine_mutex);
}

static void *run_engine(void *unused) {
    (void)unused;
    char *argv[64];
    int argc = 0;
    static char executable[] = "byedpi-engine";
    static char listen_option[] = "--ip";
    static char listen_address[] = "127.0.0.1";
    static char port_option[] = "--port";
    static char dynamic_port[] = "0";
    static char no_domain[] = "--no-domain";
    static char debug_option[] = "--debug";
    static char quiet[] = "0";
    static char protect_option[] = "--protect-path";
    static char interface_option[] = "--interface";
    static char split_option[] = "--split";
    static char disorder_option[] = "--disorder";
    static char split_first[] = "1+s";
    static char disorder_later[] = "3+s";
    static char disorder_first[] = "1+s";
    static char split_later[] = "3+s";
    int result = -1;

    reset_params();
    pthread_mutex_lock(&engine_mutex);
    params.engine_stop_requested = engine_stop_requested;
    pthread_mutex_unlock(&engine_mutex);
    params.allow_dynamic_port = true;
    params.engine_mode = true;
    params.engine_ready_callback = report_ready;

    argv[argc++] = executable;
    argv[argc++] = listen_option;
    argv[argc++] = listen_address;
    argv[argc++] = port_option;
    argv[argc++] = dynamic_port;
    argv[argc++] = no_domain;
    argv[argc++] = debug_option;
    argv[argc++] = quiet;
    if (protect_path[0]) {
        argv[argc++] = protect_option;
        argv[argc++] = protect_path;
    }
    if (interface_name[0]) {
        argv[argc++] = interface_option;
        argv[argc++] = interface_name;
    }
    static char auto_option[] = "--auto";
    static char triggers[] = "torst,ssl_err";
    if (active_profile == 4) {
        // First try the actual destination unchanged, then retry that connection
        // with successive strategies on reset/timeout/TLS failure. ByeDPI's own
        // destination cache records the working group, never a generic probe.
        for (int preset = 0; preset < 4; ++preset) {
            argv[argc++] = auto_option;
            argv[argc++] = triggers;
            if (preset == 0 || preset == 1) {
                argv[argc++] = split_option;
                argv[argc++] = split_first;
            }
            if (preset == 1 || preset == 2 || preset == 3) {
                argv[argc++] = disorder_option;
                argv[argc++] = preset == 1 ? disorder_later : disorder_first;
            }
            if (preset == 3) {
                argv[argc++] = split_option;
                argv[argc++] = split_later;
            }
        }
    } else switch (active_profile) {
        case 0:
            argv[argc++] = split_option;
            argv[argc++] = split_first;
            break;
        case 1:
            argv[argc++] = split_option;
            argv[argc++] = split_first;
            argv[argc++] = disorder_option;
            argv[argc++] = disorder_later;
            break;
        case 2:
            argv[argc++] = disorder_option;
            argv[argc++] = disorder_first;
            break;
        case 3:
            argv[argc++] = disorder_option;
            argv[argc++] = disorder_first;
            argv[argc++] = split_option;
            argv[argc++] = split_later;
            break;
        default:
            goto finished;
    }
    argv[argc] = NULL;

    optind = 1;
    if (parse_args(argc, argv) != 0) goto finished;
    // App-managed engines must never write destination hostnames or packet
    // details from ByeDPI's error-level diagnostics.
    params.debug = -2;
    if (init() < 0) goto finished;
    result = run(&params.laddr);
finished:
    clear_params(NULL, NULL);
    pthread_mutex_lock(&engine_mutex);
    engine_result = result;
    thread_finished = 1;
    if (state != ENGINE_STOPPING) state = ENGINE_EXITED;
    pthread_cond_broadcast(&engine_changed);
    pthread_mutex_unlock(&engine_mutex);
    return NULL;
}

static void deadline_after_seconds(struct timespec *deadline, int seconds) {
    clock_gettime(CLOCK_REALTIME, deadline);
    deadline->tv_sec += seconds;
}

int byedpi_engine_start(int profile, const char *protect, const char *iface) {
    if (profile < 0 || profile > 4) return 0;
    pthread_mutex_lock(&engine_mutex);
    int reap = state == ENGINE_EXITED && thread_finished;
    pthread_mutex_unlock(&engine_mutex);
    if (reap && !byedpi_engine_stop()) return 0;
    pthread_mutex_lock(&engine_mutex);
    if (state != ENGINE_IDLE) {
        pthread_mutex_unlock(&engine_mutex);
        return 0;
    }
    if ((protect && strlen(protect) >= sizeof(protect_path)) ||
        (iface && strlen(iface) >= sizeof(interface_name))) {
        pthread_mutex_unlock(&engine_mutex);
        return 0;
    }
    protect_path[0] = '\0';
    interface_name[0] = '\0';
    if (protect) memcpy(protect_path, protect, strlen(protect) + 1);
    if (iface) memcpy(interface_name, iface, strlen(iface) + 1);
    active_profile = profile;
    local_port = 0;
    thread_finished = 0;
    engine_result = -1;
    engine_stop_requested = 0;
    state = ENGINE_STARTING;
    if (pthread_create(&engine_thread, NULL, run_engine, NULL) != 0) {
        state = ENGINE_IDLE;
        pthread_mutex_unlock(&engine_mutex);
        return 0;
    }
    struct timespec deadline;
    deadline_after_seconds(&deadline, 5);
    while (!local_port && !thread_finished) {
        if (pthread_cond_timedwait(&engine_changed, &engine_mutex, &deadline) == ETIMEDOUT) break;
    }
    int port = local_port;
    pthread_mutex_unlock(&engine_mutex);
    if (!port) {
        byedpi_engine_stop();
        return 0;
    }
    return port;
}

int byedpi_engine_stop(void) {
    pthread_mutex_lock(&engine_mutex);
    if (state == ENGINE_IDLE) {
        pthread_mutex_unlock(&engine_mutex);
        return 1;
    }
    state = ENGINE_STOPPING;
    engine_stop_requested = 1;
    params.engine_stop_requested = 1;
    int port = local_port;
    int finished = thread_finished;
    pthread_mutex_unlock(&engine_mutex);

    if (port > 0 && !finished) {
        int fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd >= 0) {
            struct sockaddr_in address = {0};
            address.sin_family = AF_INET;
            address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
            address.sin_port = htons((unsigned short)port);
            (void)connect(fd, (struct sockaddr *)&address, sizeof(address));
            close(fd);
        }
    }
    pthread_join(engine_thread, NULL);
    pthread_mutex_lock(&engine_mutex);
    state = ENGINE_IDLE;
    local_port = 0;
    active_profile = -1;
    protect_path[0] = '\0';
    interface_name[0] = '\0';
    pthread_cond_broadcast(&engine_changed);
    pthread_mutex_unlock(&engine_mutex);
    return 1;
}

int byedpi_engine_is_running(void) {
    pthread_mutex_lock(&engine_mutex);
    int running = state == ENGINE_RUNNING && !thread_finished;
    pthread_mutex_unlock(&engine_mutex);
    return running;
}

int byedpi_engine_profile(void) {
    pthread_mutex_lock(&engine_mutex);
    int profile = state == ENGINE_IDLE ? -1 : active_profile;
    pthread_mutex_unlock(&engine_mutex);
    return profile;
}
