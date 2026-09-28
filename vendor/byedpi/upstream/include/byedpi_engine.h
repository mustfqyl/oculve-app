#ifndef BYEDPI_ENGINE_H
#define BYEDPI_ENGINE_H

#ifdef __cplusplus
extern "C" {
#endif

/* Starts one loopback-only listener using an internal strategy preset.
 * protect_path is used by Android's VpnService socket broker; interface_name
 * pins sockets to the underlay on platforms that support interface binding.
 * Returns the dynamically allocated SOCKS port, or 0 on failure. */
int byedpi_engine_start(int profile, const char *protect_path,
                        const char *interface_name);
int byedpi_engine_stop(void);
int byedpi_engine_is_running(void);
int byedpi_engine_profile(void);

#ifdef __cplusplus
}
#endif

#endif
