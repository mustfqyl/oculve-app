#pragma once
#include <cstdint>
#include <string>

namespace flutter_vless {
// Performs a short certificate-checked HTTPS 204 probe through the managed
// Xray SOCKS inbound. The temporary HTTP CONNECT bridge only accepts the two
// fixed probe hosts and is bound to loopback for the duration of the request.
bool DpiConnectivityReady(uint16_t xray_socks_port, const std::string& username,
                         const std::string& password);
}  // namespace flutter_vless
