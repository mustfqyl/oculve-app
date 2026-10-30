#ifndef BYEDPI_ENGINE_H
#define BYEDPI_ENGINE_H

#ifdef __cplusplus
extern "C" {
#endif

/* Largest number of groups the engine reports statistics for. */
#define BYEDPI_ENGINE_GROUP_LIMIT 8
/* Counter ceiling so a long-lived session cannot overflow the counters. */
#define BYEDPI_ENGINE_STAT_LIMIT 1000000

/* Starts one loopback-only listener. Profiles 0..3 pin a preset; profiles 5
 * and 6 pin TLS record split (5: --tlsrec 1+s; 6: plus --split 1+s). Profile 4
 * selects native per-destination automatic fallback on torst/ssl_err/conn.
 * protect_path is used by Android's VpnService socket broker; interface_name
 * pins sockets to the underlay on platforms that support interface binding.
 * Returns the dynamically allocated SOCKS port, or 0 on failure. */
int byedpi_engine_start(int profile, const char *protect_path,
                        const char *interface_name);

/* Same as byedpi_engine_start, but for profile 4 it rotates the automatic
 * group chain so `first_group` (0..4) is tried first and the remaining groups
 * follow in their built-in order. -1 or an out-of-range value keeps the
 * default order; other profiles ignore it. Kept separate so existing callers
 * (Android JNI, older app builds) keep linking against the 3-argument form. */
int byedpi_engine_start_grouped(int profile, int first_group,
                                const char *protect_path,
                                const char *interface_name);

/* Copies the engine's per-group counters into ok_counts/fail_counts, which
 * must hold `capacity` ints each, and returns how many entries were written.
 * Automatic (profile 4) runs report the five presets in their stable preset
 * order, independent of the rotation requested at start; a pinned profile
 * reports its single group. Returns 0 while no engine runs, and 0 when either
 * pointer is NULL or capacity is not positive. Only group ids and counters
 * are exposed: never a host, address or packet. */
int byedpi_engine_group_stats(int *ok_counts, int *fail_counts, int capacity);

/* How often the automatic chain ran out of untried groups since the engine
 * last started. 0 when no engine runs. */
int byedpi_engine_exhausted(void);

int byedpi_engine_stop(void);
int byedpi_engine_is_running(void);
int byedpi_engine_profile(void);

#ifdef __cplusplus
}
#endif

#endif
